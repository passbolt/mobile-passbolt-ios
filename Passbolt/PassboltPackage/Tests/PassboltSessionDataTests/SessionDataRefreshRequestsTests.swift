//
// Passbolt - Open source password manager for teams
// Copyright (c) 2021 Passbolt SA
//
// This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General
// Public License (AGPL) as published by the Free Software Foundation version 3.
//
// The name "Passbolt" is a registered trademark of Passbolt SA, and Passbolt SA hereby declines to grant a trademark
// license to "Passbolt" pursuant to the GNU Affero General Public License version 3 Section 7(e), without a separate
// agreement with Passbolt SA.
//
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied
// warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License along with this program. If not,
// see GNU Affero General Public License v3 (http://www.gnu.org/licenses/agpl-3.0.html).
//
// @copyright     Copyright (c) Passbolt SA (https://www.passbolt.com)
// @license       https://opensource.org/licenses/AGPL-3.0 AGPL License
// @link          https://www.passbolt.com Passbolt (tm)
// @since         v1.0
//

import Aegithalos
import CoreTest
import Metadata
import TestExtensions

import struct Foundation.Data
import struct Foundation.URL

@testable import PassboltNetworkOperations
@testable import PassboltSessionData

/// Functional guard for `SessionData.refreshIfNeeded` request behaviour — NOT a
/// benchmark. The end-to-end performance benchmark (real `ResourceUpdater` + PGP
/// decryption + DB store) lives in `SessionDataRefreshIntegrationBenchmarkTests`.
///
/// Here the real fetch operations run against a fixture-backed
/// `SessionNetworkRequestExecutor` (with `ResourceUpdater` / metadata mocked out),
/// purely to assert each data-source endpoint is requested the expected number of
/// times per refresh — catching duplicate-fetch regressions.
// swift-format-ignore: AlwaysUseLowerCamelCase
final class SessionDataRefreshRequestsTests: FeaturesTestCase {

  override func commonPrepare() async throws {
    try await super.commonPrepare()
    register(
      { $0.usePassboltSessionData() },
      for: SessionData.self
    )
    // Folders enabled so the refresh exercises the folders fetch. Metadata disabled
    // and ResourceUpdater mocked: this is a request-behaviour check, not a benchmark.
    set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_default.with {
          $0.folders = .init(enabled: true)
          $0.metadata = .init(enabled: false)
        }
      )
    )

    patch(
      \UsersStoreDatabaseOperation.execute,
      with: always(Void())
    )
    patch(
      \UserGroupsStoreDatabaseOperation.execute,
      with: always(Void())
    )
    patch(
      \ResourceFoldersStoreDatabaseOperation.execute,
      with: always(Void())
    )
    patch(
      \OSTime.timestamp,
      with: always(0)
    )
    patch(
      \ResourceUpdater.updateResources,
      with: { _, _ in }
    )
    patch(
      \Session.execute,
      with: { .init(operation: $0) }
    )
    // Resolvable but unused while metadata is disabled.
    usePlaceholder(for: MetadataKeysService.self)
    usePlaceholder(for: MetadataSettingsService.self)
  }

  /// Each endpoint must be requested at most twice (the load-time refresh may race
  /// the explicit one), never more. This catches duplicate-fetch regressions in the
  /// refresh orchestration.
  func test_refreshIfNeeded_requestsEachEndpointAtMostTwice() async throws {
    let counts: CriticalState<Dictionary<String, Int>> = .init(.init())
    self.installFixtureExecutor(
      size: "small",
      endpoints: ["users", "groups", "folders"],
      onRequest: { path in
        counts.access { tally in
          tally[path, default: 0] += 1
        }
      }
    )
    // Real operations issue the requests intercepted above.
    registerFetchOperations()

    let feature: SessionData = try self.testedInstance()
    // Warm-up drains the load-time refresh; a pending one can only coalesce, not re-fetch.
    try await feature.refreshIfNeeded()
    counts.access { tally in tally.removeAll() }
    try await feature.refreshIfNeeded()

    let tally: Dictionary<String, Int> = counts.get()
    for endpoint: String in ["/users.json", "/groups.json", "/folders.json"] {
      let hits: Int = tally[endpoint] ?? 0
      XCTAssertEqual(hits, 1, "Expected \(endpoint) to be requested exactly once per explicit refresh.")
    }
  }

  // MARK: - Helpers

  /// Registers the real session-based fetch operations whose requests are
  /// intercepted by the patched `SessionNetworkRequestExecutor`.
  private func registerFetchOperations() {
    register(
      { $0.usePassboltUsersFetchNetworkOperation() },
      for: UsersFetchNetworkOperation.self
    )
    register(
      { $0.usePassboltUserGroupsFetchNetworkOperation() },
      for: UserGroupsFetchNetworkOperation.self
    )
    register(
      { $0.usePassboltResourceFoldersFetchNetworkOperation() },
      for: ResourceFoldersFetchNetworkOperation.self
    )
  }

  /// Maps a fixture file name to the request path suffix it answers.
  private static let fixtureEndpoints: Dictionary<String, String> = [
    "users": "/users.json",
    "groups": "/groups.json",
    "folders": "/folders.json",
  ]

  /// Patches `SessionNetworkRequestExecutor` to answer requests for the given
  /// `endpoints` with the matching fixture's raw bytes, routed by path suffix.
  /// `onRequest` is invoked with that path for assertions/counting.
  private func installFixtureExecutor(
    size: String,
    endpoints: Array<String>,
    onRequest: @escaping @Sendable (String) -> Void = { _ in }
  ) {
    let payloads: Dictionary<String, Array<UInt8>> = self.loadPayloads(size: size, endpoints: endpoints)
    let fallbackURL: URL = URL(string: "https://passbolt.local") ?? URL(fileURLWithPath: "/")

    patch(
      \SessionNetworkRequestExecutor.execute,
      with: { mutation in
        let request: HTTPRequest = mutation.instantiate()
        let path: String = request.urlComponents.path
        onRequest(path)
        let endpoint: String? = payloads.keys.first(where: path.hasSuffix)
        let bytes: Array<UInt8> = endpoint.flatMap { payloads[$0] } ?? []
        return HTTPResponse(
          url: request.urlComponents.url ?? fallbackURL,
          statusCode: 200,
          headers: .empty,
          body: Data(bytes)
        )
      }
    )
  }

  /// Loads the requested fixtures once, keyed by the request path they answer.
  private func loadPayloads(
    size: String,
    endpoints: Array<String>
  ) -> Dictionary<String, Array<UInt8>> {
    var payloads: Dictionary<String, Array<UInt8>> = .init()
    for name: String in endpoints {
      guard let path: String = Self.fixtureEndpoints[name]
      else {
        XCTFail("Unknown fixture endpoint: \(name)")
        continue
      }
      guard let data: Data = try? NetworkResponseFixture.data("Benchmark/\(size)/\(name).json")
      else {
        XCTFail("Missing fixture: Benchmark/\(size)/\(name).json")
        continue
      }
      payloads[path] = Array(data)
    }
    return payloads
  }
}
