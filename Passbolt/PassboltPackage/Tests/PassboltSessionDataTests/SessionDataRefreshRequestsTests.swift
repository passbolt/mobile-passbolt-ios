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
import class Foundation.JSONSerialization
import struct Foundation.URL
import struct Foundation.URLQueryItem

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
  ///
  /// For folders this doubles as the degrade-to-one-request guard: the fixture reports
  /// `"limit": null` with the whole set in its body, as a server ignoring `limit` would.
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

  /// The folders fetch must put the whole pagination contract on the wire, including the stable
  /// `Folders.created asc` ordering that offset paging depends on.
  func test_refreshIfNeeded_folders_sendsPaginationQueryItems() async throws {
    let folderRequests: CriticalState<Array<Dictionary<String, String>>> = .init(.init())
    self.installFixtureExecutor(
      size: "small",
      endpoints: ["users", "groups", "folders"],
      onHTTPRequest: { (request: HTTPRequest) in
        guard request.urlComponents.path.hasSuffix("/folders.json")
        else { return }
        var queryItems: Dictionary<String, String> = .init()
        for item: URLQueryItem in request.urlComponents.queryItems ?? Array<URLQueryItem>() {
          queryItems[item.name] = item.value
        }
        folderRequests.access { (requests: inout Array<Dictionary<String, String>>) in
          requests.append(queryItems)
        }
      }
    )
    registerFetchOperations()

    let feature: SessionData = try self.testedInstance()
    // Warm-up drains the load-time refresh, which usually leaves the explicit refresh below alone on the
    // wire - the assertions do not rely on that, since the two can still race.
    try await feature.refreshIfNeeded()
    folderRequests.access { (requests: inout Array<Dictionary<String, String>>) in requests.removeAll() }
    try await feature.refreshIfNeeded()

    let requests: Array<Dictionary<String, String>> = folderRequests.get()
    let firstRequest: Dictionary<String, String> = try XCTUnwrap(requests.first, "Folders must be fetched")
    XCTAssertEqual(firstRequest["page"], "1", "The first page must be requested explicitly")
    XCTAssertEqual(
      firstRequest["sort"],
      "Folders.created",
      "Offset paging needs the immutable sort key - a mutable one silently skips folders"
    )
    XCTAssertEqual(firstRequest["direction"], "asc", "Ordering must be ascending to keep earlier pages stable")
    let limit: Int = try XCTUnwrap(
      firstRequest["limit"].flatMap { (value: String) -> Int? in Int(value) },
      "An explicit limit must be sent"
    )
    XCTAssertGreaterThan(limit, 0, "The limit must be a usable page size")
    // Asserting the requested pages rather than their number: a load-time refresh racing the explicit one
    // can repeat page 1, but no refresh may ever reach past it here.
    XCTAssertEqual(
      Set(requests.compactMap { (request: Dictionary<String, String>) -> String? in request["page"] }),
      ["1"],
      "A first page already holding the whole set must not trigger a request for any further page"
    )
  }

  /// A server predating folders pagination answers with no `header.pagination` block at all. The decoder
  /// must degrade to the previous behaviour - one request for the whole body - rather than turning a
  /// working refresh into a hard failure the way `.paginatedResponse` does for resources.
  func test_refreshIfNeeded_folders_succeedsWithOneRequest_whenResponseCarriesNoPaginationBlock() async throws {
    let unpaginated: (payload: Array<UInt8>, folderCount: Int) =
      try Self.withoutPaginationBlock(self.loadFolderPayload(size: "small"))
    let folderPages: CriticalState<Array<String>> = .init(.init())
    self.installFixtureExecutor(
      size: "small",
      endpoints: ["users", "groups", "folders"],
      onHTTPRequest: { (request: HTTPRequest) in
        guard request.urlComponents.path.hasSuffix("/folders.json")
        else { return }
        folderPages.access { (pages: inout Array<String>) in
          pages.append(
            request.urlComponents.queryItems?
              .first { (item: URLQueryItem) -> Bool in item.name == "page" }?
              .value ?? "none"
          )
        }
      },
      payloadOverrides: ["/folders.json": unpaginated.payload]
    )
    registerFetchOperations()

    let storedCount: CriticalState<Int?> = .init(.none)
    patch(
      \ResourceFoldersStoreDatabaseOperation.execute,
      with: { (input: Array<ResourceFolderDTO>) in
        storedCount.access { (count: inout Int?) in count = input.count }
      }
    )

    let feature: SessionData = try self.testedInstance()
    try await feature.refreshIfNeeded()

    let stored: Int = try XCTUnwrap(storedCount.get(), "Folders must be stored")
    XCTAssertEqual(
      stored,
      unpaginated.folderCount,
      "A response without pagination metadata must store its whole body, not fail the refresh"
    )
    // A set, not the raw array: the refresh performed when the feature loads may race the explicit one.
    XCTAssertEqual(
      Set(folderPages.get()),
      ["1"],
      "With no pagination metadata to page by, only the first page may be requested"
    )
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
  /// `onRequest` is invoked with that path for assertions/counting. `payloadOverrides` replaces a
  /// fixture's bytes for the given path suffix, so a test can answer with a hand-shaped response.
  private func installFixtureExecutor(
    size: String,
    endpoints: Array<String>,
    onRequest: @escaping @Sendable (String) -> Void = { _ in },
    onHTTPRequest: @escaping @Sendable (HTTPRequest) -> Void = { _ in },
    payloadOverrides: Dictionary<String, Array<UInt8>> = .init()
  ) {
    // Merged rather than assigned into: the `@Sendable` closure below captures this, and Swift 6 rejects
    // capturing a mutable local there.
    let payloads: Dictionary<String, Array<UInt8>> = self.loadPayloads(size: size, endpoints: endpoints)
      .merging(payloadOverrides) { (_: Array<UInt8>, override: Array<UInt8>) -> Array<UInt8> in override }
    let fallbackURL: URL = URL(string: "https://passbolt.local") ?? URL(fileURLWithPath: "/")

    patch(
      \SessionNetworkRequestExecutor.execute,
      with: { mutation in
        let request: HTTPRequest = mutation.instantiate()
        let path: String = request.urlComponents.path
        onRequest(path)
        onHTTPRequest(request)
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

  /// The folders fixture's raw bytes, for tests that reshape the response before installing it.
  private func loadFolderPayload(
    size: String
  ) throws -> Array<UInt8> {
    Array(try NetworkResponseFixture.data("Benchmark/\(size)/folders.json"))
  }

  /// Strips `header.pagination`, as a server predating folders pagination answers, and reports how many
  /// folders the untouched body holds.
  private static func withoutPaginationBlock(
    _ bytes: Array<UInt8>
  ) throws -> (payload: Array<UInt8>, folderCount: Int) {
    let decoded: Any = try JSONSerialization.jsonObject(with: Data(bytes))
    guard
      var json: Dictionary<String, Any> = decoded as? Dictionary<String, Any>,
      var header: Dictionary<String, Any> = json["header"] as? Dictionary<String, Any>,
      let body: Array<Any> = json["body"] as? Array<Any>
    else {
      throw MockIssue.error()
    }
    header.removeValue(forKey: "pagination")
    json["header"] = header
    let payload: Data = try JSONSerialization.data(withJSONObject: json)
    return (payload: Array(payload), folderCount: body.count)
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
