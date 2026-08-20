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
import Crypto
import Database
import Features
import Metadata
import OSFeatures
import PassboltAccounts
import PassboltDatabaseOperations
import PassboltNetworkOperations
import PassboltResources
import PassboltUsers
import TestExtensions
import XCTest

import struct Foundation.Data
import struct Foundation.URL

@testable import PassboltMetadata
@testable import PassboltSession
@testable import PassboltSessionData

/// END-TO-END integration benchmarks with REAL decryption (see `Tools/benchmark`):
/// `test_benchmark_updateResources_*` measures `ResourceUpdater.updateResources`;
/// `test_fullRefreshTiming_*` times the full `SessionData.refreshIfNeeded()`.
// swift-format-ignore: AlwaysUseLowerCamelCase
final class SessionDataRefreshIntegrationBenchmarkTests: XCTestCase {

  /// Non-resource fixture file (relative to Fixtures/) per request path, for `size`.
  /// `/resources.json` is paginated and handled separately (see `loadResourcePages`).
  private static func routes(size: String) -> Dictionary<String, String> {
    [
      "/users.json": "Benchmark/\(size)/users.json",
      "/groups.json": "Benchmark/\(size)/groups.json",
      "/folders.json": "Benchmark/\(size)/folders.json",
      "/resource-types.json": "Benchmark/\(size)/resource-types.json",
      "/metadata/keys.json": "Benchmark/\(size)/metadata-keys.json",
      "/metadata/session-keys.json": "Benchmark/\(size)/metadata-session-keys.json",
      "/metadata/keys/settings.json": "Benchmark/\(size)/metadata-keys-settings.json",
      "/metadata/types/settings.json": "Benchmark/\(size)/metadata-types-settings.json",
    ]
  }

  func test_benchmark_updateResources_withRealDecryption_small() async throws {
    executionTimeAllowance = 60 * 10  // 10 minutes; plan max must allow this
    try await self.runBenchmark(size: "small")
  }

  func test_benchmark_updateResources_withRealDecryption_medium() async throws {
    // medium fixtures are not committed (kept locally / regenerated) — skip if absent.
    try XCTSkipUnless(
      NetworkResponseFixture.exists("Benchmark/medium/users.json"),
      "Medium fixtures absent (kept locally — see Fixtures README)."
    )
    executionTimeAllowance = 60 * 10  // 10 minutes
    try await self.runBenchmark(size: "medium")
  }

  func test_benchmark_updateResources_withRealDecryption_large() async throws {
    // large fixtures are not committed (kept locally / regenerated) — skip if absent.
    try XCTSkipUnless(
      NetworkResponseFixture.exists("Benchmark/large/users.json"),
      "Large fixtures absent."
    )
    executionTimeAllowance = 2600  // ~43 minutes
    try await self.runBenchmark(size: "large", iterations: 3)
  }

  /// Real fetch (paginated) → PGP-decrypt → store for the given dataset.
  private func runBenchmark(size: String, iterations: Int = 20) async throws {
    let key: AdaKeyMaterial = try Self.loadKeyMaterial()
    let session: FeaturesContainer = try await Self.makeSession(key: key, size: size)
    // Unmeasured setup: populate the DB prefix + initialize metadata keys.
    let prepared: Prepared = try await Self.prepare(session: session)

    self.measureAsync(iterations: iterations) {
      // Clear stored resources so every iteration decrypts in full.
      try await prepared.resetState.execute(.init(state: .waitingForUpdate))
      try await prepared.resetRemove.execute(.waitingForUpdate)
      try await prepared.updater.updateResources(
        // Mirror the production app config (see SessionData+Passbolt `.application`).
        .init(maximumChunkSize: 5_000, maximumConcurrentTasks: 5, maximumConcurrentDecryptions: 4)
      ) { _ in }
    }
  }

  // MARK: - Full-refresh timing (machine-local XCTest attachment, not committed)

  func test_fullRefreshTiming_small() async throws {
    executionTimeAllowance = 60 * 10  // 10 minutes
    try await self.runFullRefreshTiming(size: "small")
  }

  func test_fullRefreshTiming_medium() async throws {
    try XCTSkipUnless(
      NetworkResponseFixture.exists("Benchmark/medium/users.json"),
      "Medium fixtures absent (kept locally — see Fixtures README)."
    )
    executionTimeAllowance = 60 * 10  // 10 minutes
    try await self.runFullRefreshTiming(size: "medium", iterations: 3)
  }

  func test_fullRefreshTiming_large() async throws {
    try XCTSkipUnless(
      NetworkResponseFixture.exists("Benchmark/large/users.json"),
      "Large fixtures absent (kept locally — see Fixtures README)."
    )
    executionTimeAllowance = 2400  // 40 minutes (== plan max); the large dataset is slow
    try await self.runFullRefreshTiming(size: "large", iterations: 3)
  }

  /// Times the ENTIRE `SessionData.refreshIfNeeded()` (users + groups + folders + metadata keys +
  /// resources fetch/decrypt/store) end to end, on a fresh cold session per iteration, and records the
  /// per-iteration durations as an XCTest attachment. The attachment lives only in the `.xcresult`
  /// (machine-local, never committed).
  private func runFullRefreshTiming(size: String, iterations: Int = 5) async throws {
    let key: AdaKeyMaterial = try Self.loadKeyMaterial()
    let clock: ContinuousClock = .init()
    var samples: Array<Double> = .init()
    for _ in 0 ..< iterations {
      // Fresh session each iteration → a cold in-memory DB, so every sample measures a full refresh
      // (avoids the modification-date skip that would make reruns against one DB trivial).
      let sessionData: SessionData = try await Self.makeSessionData(key: key, size: size)
      let start: ContinuousClock.Instant = clock.now
      // Returns when the refresh task completes (isRefreshing true → false) — the full start→stop span.
      try await sessionData.refreshIfNeeded()
      samples.append(Self.seconds(start.duration(to: clock.now)))
    }

    guard let minimum: Double = samples.min(), let maximum: Double = samples.max()
    else { return XCTFail("No timing samples collected for size=\(size).") }
    let average: Double = samples.reduce(0, +) / Double(samples.count)
    let report: String =
      "size=\(size)\titerations=\(samples.count)\n"
      + "full_refresh_seconds=\(samples)\n"
      + "min=\(minimum)\tavg=\(average)\tmax=\(maximum)"
    let attachment: XCTAttachment = .init(string: report)
    attachment.name = "session-data-full-refresh-timing-\(size)"
    attachment.lifetime = .keepAlways  // persist into the .xcresult even when the test passes
    self.add(attachment)
  }

  // MARK: - Warm refresh (populate once, then re-refresh an already-populated DB)

  func test_benchmark_warmRefresh_small() async throws {
    executionTimeAllowance = 60 * 10  // 10 minutes
    try await self.runWarmRefreshBenchmark(size: "small")
  }

  func test_benchmark_warmRefresh_medium() async throws {
    try XCTSkipUnless(
      NetworkResponseFixture.exists("Benchmark/medium/users.json"),
      "Medium fixtures absent (kept locally — see Fixtures README)."
    )
    executionTimeAllowance = 60 * 10  // 10 minutes
    try await self.runWarmRefreshBenchmark(size: "medium")
  }

  func test_benchmark_warmRefresh_large() async throws {
    try XCTSkipUnless(
      NetworkResponseFixture.exists("Benchmark/large/users.json"),
      "Large fixtures absent."
    )
    executionTimeAllowance = 2600  // 40 minutes
    try await self.runWarmRefreshBenchmark(size: "large", iterations: 3)
  }

  /// Measures `SessionData.refreshIfNeeded()` against an ALREADY-POPULATED database — the warm path,
  /// where every resource's `modified` is unchanged so no decryption happens and the cost is the
  /// per-resource access/folder/favorite reconciliation plus the users/groups/folders store. This is
  /// the scenario the cold benchmarks above (fresh DB per iteration) cannot see.
  ///
  /// Drives only the public `refreshIfNeeded()` API, so it compiles and runs identically against the
  /// pre- and post-change builds (run it on a stashed baseline, then on the popped changes, and diff).
  private func runWarmRefreshBenchmark(size: String, iterations: Int = 20) async throws {
    let key: AdaKeyMaterial = try Self.loadKeyMaterial()
    let sessionData: SessionData = try await Self.makeSessionData(key: key, size: size)
    // Unmeasured warm-up: the first refresh fully populates the DB (decrypt + store everything). The
    // same in-memory connection is reused across measured iterations, so the rows persist.
    try await sessionData.refreshIfNeeded()

    self.measureAsync(iterations: iterations) {
      // Every measured refresh re-fetches the same fixtures: identical `modified` timestamps mean all
      // resources take the unchanged/reconcile path rather than being decrypted and fully re-stored.
      try await sessionData.refreshIfNeeded()
    }
  }

  /// Builds a fresh real session and resolves `SessionData`.
  @MainActor
  private static func makeSessionData(key: AdaKeyMaterial, size: String) throws -> SessionData {
    try Self.makeSession(key: key, size: size).instance()
  }

  /// Seconds (Double) from a `Duration`. Local helper so this test doesn't depend on temporary tooling.
  private static func seconds(_ duration: Duration) -> Double {
    Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
  }

  /// Real `ResourceUpdater` plus the ops used to clear stored resources between
  /// measured iterations.
  private struct Prepared: Sendable {
    let updater: ResourceUpdater
    let resetState: ResourceUpdateStateDatabaseOperation
    let resetRemove: ResourceRemoveWithStateDatabaseOperation
  }

  /// Stores users/groups/folders and initializes metadata keys (all unmeasured),
  /// then returns the real `ResourceUpdater` and the resource-reset ops.
  @MainActor
  private static func prepare(session: FeaturesContainer) async throws -> Prepared {
    let usersFetch: UsersFetchNetworkOperation = try session.instance()
    let usersStore: UsersStoreDatabaseOperation = try session.instance()
    try await usersStore(usersFetch().compactMap(\.asFilteredDSO))

    let groupsFetch: UserGroupsFetchNetworkOperation = try session.instance()
    let groupsStore: UserGroupsStoreDatabaseOperation = try session.instance()
    try await groupsStore(groupsFetch())

    let foldersFetch: ResourceFoldersFetchNetworkOperation = try session.instance()
    let foldersStore: ResourceFoldersStoreDatabaseOperation = try session.instance()
    let foldersPagination: ResourceFoldersFetch = .init(
      configuration: .application,
      fetchPage: { (pagination: PaginationData) async throws -> ResourceFoldersFetchNetworkOperationResult in
        try await foldersFetch(pagination)
      },
      reportProgress: { (_: Double) in }
    )
    try await foldersStore(foldersPagination.execute())

    let metadataSettings: MetadataSettingsService = try session.instance()
    try await metadataSettings.fetchSettings()

    let metadata: MetadataKeysService = try session.instance()
    try await metadata.initialize()

    return Prepared(
      updater: try session.instance(),
      resetState: try session.instance(),
      resetRemove: try session.instance()
    )
  }

  // MARK: - Real container assembly

  @MainActor
  private static func makeSession(key: AdaKeyMaterial, size: String) throws -> FeaturesContainer {
    // In-memory database with the full schema; reused across measured iterations.
    let connection: SQLiteConnection = try SQLiteConnection.open(migrations: SQLiteMigration.allCases)
    let payloads: Dictionary<String, Array<UInt8>> = Self.loadPayloads(size: size)
    let resourcePages: Dictionary<Int, Array<UInt8>> = Self.loadResourcePages(size: size)
    let fallbackURL: URL = URL(string: "https://passbolt.local") ?? URL(fileURLWithPath: "/")
    // Impersonate the dump's ada: the userID must match a stored user so the
    // current account resolves to a real, decryptable identity.
    guard let adaUserID: User.ID = .init(uuidString: "f848277c-5398-58f8-a82a-72397af2d450")
    else { throw MockIssue.error() }
    let account: Account = .init(
      localID: .mock_ada,
      domain: .mock_passbolt,
      userID: adaUserID,
      fingerprint: "03F60E958F4CB29723ACDF761353B5B15D9B054F"
    )

    let root: FeaturesFactory<RootFeaturesScope> = .init { (registry: inout FeaturesRegistry) in
      // Full real stack needed by refreshIfNeeded().
      registry.useOSFeatures()
      registry.useCrypto()
      registry.usePassboltAccountsModule()
      registry.usePassboltDatabaseOperationsModule()
      registry.usePassboltNetworkOperationsModule()
      registry.usePassboltResourcesModule()
      registry.usePassboltSessionModule()
      registry.usePassboltSessionDataModule()
      registry.usePassboltUsersModule()
      registry.usePassboltMetadataModule()
      registry.useNFCFeatures()

      // Override seams (registered last → win). All four register in root scope.
      registry.use(
        .lazyLoaded(
          SessionDatabase.self,
          load: { _ in SessionDatabase(connection: { connection }) }
        )
      )
      registry.use(
        .lazyLoaded(
          SessionNetworkRequestExecutor.self,
          load: { _ in
            SessionNetworkRequestExecutor(execute: { mutation in
              let request: HTTPRequest = mutation.instantiate()
              let path: String = request.urlComponents.path
              let bytes: Array<UInt8>
              if path.hasSuffix("/resources.json") {
                // Paginated: route by the request's `page` query item.
                let pageValue: String? = request.urlComponents.queryItems?
                  .first(where: { $0.name == "page" })?
                  .value
                let page: Int = pageValue.flatMap(Int.init) ?? 1
                bytes = resourcePages[page] ?? resourcePages[1] ?? []
              }
              else {
                let route: String? = payloads.keys.first(where: path.hasSuffix)
                bytes = route.flatMap { payloads[$0] } ?? []
              }
              return HTTPResponse(
                url: request.urlComponents.url ?? fallbackURL,
                statusCode: 200,
                headers: .empty,
                body: Data(bytes)
              )
            })
          }
        )
      )
      registry.use(
        .lazyLoaded(
          AccountPrivateKeyStorage.self,
          load: { _ in AccountPrivateKeyStorage(loadAccountPrivateKey: { _ in key.privateKey }) }
        )
      )
      registry.use(
        .lazyLoaded(
          SessionStateEnsurance.self,
          load: { _ in
            SessionStateEnsurance(
              passphrase: { _ in key.passphrase },
              accessToken: { _ in throw MockIssue.error() }
            )
          }
        )
      )
      // The real `Session` gates on an authorized `SessionState` (empty here), so
      // `currentAccount()` throws `SessionMissing` during metadata decryption.
      // Override it: report ada as the current account and run operations directly.
      registry.use(
        .lazyLoaded(
          Session.self,
          load: { _ in
            Session(
              updates: Variable<Void>(initial: Void()).asAnyUpdatable(),
              pendingAuthorization: { .none },
              currentAccount: { account },
              authorize: { _ in },
              authorizeMFA: { _ in },
              close: { _ in },
              execute: { .init(operation: $0) },
              prewarmAuthorization: { _ in }
            )
          }
        )
      )
      // Real MetadataKeysService, but with the session-keys upload neutralized: `sendSessionKeys`
      // POSTs the locally-derived keys and decrypts the server's response — a round-trip static
      // fixtures can't satisfy. Everything else (decrypt/initialize/…) stays real. Registered in
      // SessionScope (where MetadataKeysService lives) after the module so it wins.
      registry.use(
        .lazyLoaded(
          MetadataKeysService.self,
          load: { (features: Features) throws -> MetadataKeysService in
            var service: MetadataKeysService = try MetadataKeysService.load(features: features)
            service.sendSessionKeys = {}
            return service
          }
        ),
        in: SessionScope.self
      )
    }

    // SessionScope.verified requires AccountScope in the chain, so branch it first.
    let accountScoped: FeaturesContainer = try root.branch(
      scope: AccountScope.self,
      context: account
    )
    return try accountScoped.branch(
      scope: SessionScope.self,
      context: .init(
        account: account,
        configuration: .mock_default.with {
          $0.folders = .init(enabled: true)
          $0.metadata = .init(enabled: true)
        }
      )
    )
  }

  // MARK: - Fixtures & key material

  private static func loadPayloads(size: String) -> Dictionary<String, Array<UInt8>> {
    var payloads: Dictionary<String, Array<UInt8>> = .init()
    for (path, fixture): (String, String) in Self.routes(size: size) {
      guard let data: Data = try? NetworkResponseFixture.data(fixture)
      else {
        XCTFail("Missing fixture: \(fixture)")
        continue
      }
      payloads[path] = Array(data)
    }
    return payloads
  }

  /// Loads the resources fixture pages keyed by page number: page 1 is
  /// `resources.json`, subsequent pages are `resources-<n>.json` (paginated dumps).
  private static func loadResourcePages(size: String) -> Dictionary<Int, Array<UInt8>> {
    var pages: Dictionary<Int, Array<UInt8>> = .init()
    guard let first: Data = try? NetworkResponseFixture.data("Benchmark/\(size)/resources.json")
    else {
      XCTFail("Missing fixture: Benchmark/\(size)/resources.json")
      return pages
    }
    pages[1] = Array(first)
    var page: Int = 2
    while NetworkResponseFixture.exists("Benchmark/\(size)/resources-\(page).json") {
      if let data: Data = try? NetworkResponseFixture.data("Benchmark/\(size)/resources-\(page).json") {
        pages[page] = Array(data)
      }
      page += 1
    }
    return pages
  }

  private struct AdaKeyMaterial: Sendable {
    let privateKey: ArmoredPGPPrivateKey
    let passphrase: Passphrase
  }

  /// Loads ada's private key + passphrase from the (uncommitted) keys fixtures,
  /// skipping the benchmark when they are absent.
  private static func loadKeyMaterial() throws -> AdaKeyMaterial {
    try XCTSkipUnless(
      NetworkResponseFixture.exists("keys/ada.private.asc")
        && NetworkResponseFixture.exists("keys/ada.passphrase"),
      "ada key material absent — add Fixtures/keys/ada.private.asc + ada.passphrase to run the real-decryption benchmark."
    )
    let keyText: String = String(decoding: try NetworkResponseFixture.data("keys/ada.private.asc"), as: UTF8.self)
    let passText: String = String(decoding: try NetworkResponseFixture.data("keys/ada.passphrase"), as: UTF8.self)
      .trimmingCharacters(in: .whitespacesAndNewlines)
    return AdaKeyMaterial(
      privateKey: ArmoredPGPPrivateKey(rawValue: keyText),
      passphrase: Passphrase(rawValue: passText)
    )
  }
}
