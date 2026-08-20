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

import CoreTest
import Metadata
import TestExtensions

@testable import PassboltSessionData

// swift-format-ignore: AlwaysUseLowerCamelCase
final class SessionDataRefreshTests: FeaturesTestCase {

  override func commonPrepare() async throws {
    try await super.commonPrepare()
    register(
      { $0.usePassboltSessionData() },
      for: SessionData.self
    )
    set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_default
      )
    )
    patch(
      \UsersFetchNetworkOperation.execute,
      with: always([])
    )
    patch(
      \UsersStoreDatabaseOperation.execute,
      with: always(Void())
    )
    patch(
      \UserGroupsFetchNetworkOperation.execute,
      with: always([])
    )
    patch(
      \UserGroupsStoreDatabaseOperation.execute,
      with: always(Void())
    )
    patch(
      \OSTime.timestamp,
      with: always(0)
    )
    patch(
      \MetadataSettingsService.fetchKeysSettings,
      with: always(())
    )
    patch(
      \MetadataSettingsService.fetchTypesSettings,
      with: always(())
    )
    patch(
      \MetadataSessionKeysFetchNetworkOperation.execute,
      with: always([])
    )
    patch(
      \MetadataKeysService.cleanupDecryptionCache,
      with: always(Void())
    )
    patch(
      \ResourceUpdater.updateResources,
      with: { _, _ in }
    )
    patch(
      \Session.execute,
      with: { .init(operation: $0) }
    )
  }

  func test_sessionDataRefresh_shouldNotFetchMetadataKeys_ifFeatureIsDisabled() async throws {
    set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_default.with { $0.metadata = .init(enabled: false) }
      )
    )

    patch(
      \ResourceTypesFetchNetworkOperation.execute,
      with: always([])
    )

    patch(
      \ResourceTypesStoreDatabaseOperation.execute,
      with: always(Void())
    )

    patch(
      \MetadataKeysService.initialize,
      with: always(
        {
          XCTFail("Should not be initialized")
        }()
      )
    )

    let feature: SessionData = try self.testedInstance()
    try await feature.refreshIfNeeded()
  }

  func test_updateResource_delegatesToResourceUpdater_andBumpsLastUpdate() async throws {
    let updaterCalled: XCTestExpectation = .init(description: "ResourceUpdater.updateResource should be called.")
    let timestampRequested: XCTestExpectation = .init(description: "Timestamp should be requested for lastUpdate bump.")
    timestampRequested.assertForOverFulfill = false
    patch(
      \ResourceUpdater.updateResource,
      with: { _ in
        updaterCalled.fulfill()
      }
    )
    patch(
      \OSTime.timestamp,
      with: {
        timestampRequested.fulfill()
        return 42
      }
    )

    let feature: SessionData = try self.testedInstance()
    try await feature.updateResource(.mock_1)

    await fulfillment(of: [updaterCalled, timestampRequested], timeout: 1)
  }

  func test_updateResource_propagatesUpdaterFailure() async throws {
    patch(
      \ResourceUpdater.updateResource,
      with: { _ in
        throw MockIssue.error()
      }
    )

    let feature: SessionData = try self.testedInstance()
    do {
      try await feature.updateResource(.mock_1)
      XCTFail("Expected SessionData.updateResource to propagate updater failure.")
    }
    catch {
      // expected
    }
  }

  func test_sessionDataRefresh_shouldFetchMetadataKeys_ifFeatureIsEnabled() async throws {
    set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_default.with(metadataEnabled: true)
      )
    )
    patch(
      \ResourceTypesFetchNetworkOperation.execute,
      with: always([])
    )

    patch(
      \ResourceTypesStoreDatabaseOperation.execute,
      with: always(Void())
    )

    let fetchKeysExpectation: XCTestExpectation = .init(description: "Should fetch metadata keys.")
    let sendSessionKeysExpectation: XCTestExpectation = .init(description: "Should send session keys.")
    patch(
      \MetadataKeysService.initialize,
      with: always({ fetchKeysExpectation.fulfill() }())
    )
    patch(
      \MetadataKeysService.sendSessionKeys,
      with: always({ sendSessionKeysExpectation.fulfill() }())
    )

    let feature: SessionData = try self.testedInstance()
    try await feature.refreshIfNeeded()
    await fulfillment(of: [fetchKeysExpectation, sendSessionKeysExpectation], timeout: 1)
  }

  func test_sessionDataRefresh_returnsToIdleAfterCompletion() async throws {
    set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_default.with { $0.metadata = .init(enabled: false) }
      )
    )
    patch(
      \ResourceTypesFetchNetworkOperation.execute,
      with: always([])
    )
    patch(
      \ResourceTypesStoreDatabaseOperation.execute,
      with: always(Void())
    )

    let feature: SessionData = try self.testedInstance()
    try await feature.refreshIfNeeded()

    try await verifyIf(
      try await feature.refreshProgress.value,
      eventuallyEquals: Double?.none
    )
  }

  // MARK: - Equal-step progress model (Android-aligned)

  func test_refreshStepFractions_areEqualWeight_andReachFull() {
    let total: Double = Double(RefreshStep.allCases.count)

    // Each completed step pins the bar at (index + 1) / total; steps are equal-weight.
    for step: RefreshStep in RefreshStep.allCases {
      XCTAssertEqual(
        step.fraction(1),
        Double(step.rawValue + 1) / total,
        accuracy: 0.0001,
        "Completed step \(step) should fill up to (index + 1) / total"
      )
    }

    // A paginated step fills its own equal-weight slice as pages are processed.
    XCTAssertEqual(
      RefreshStep.resources.fraction(0.5),
      (Double(RefreshStep.resources.rawValue) + 0.5) / total,
      accuracy: 0.0001,
      "A half-done paginated step fills half of its slice"
    )

    // Folders is paginated too, and reports `pagesDone / totalPages` while its pages are fetched.
    XCTAssertEqual(
      RefreshStep.folders.fraction(1.0 / 3.0),
      (Double(RefreshStep.folders.rawValue) + 1.0 / 3.0) / total,
      accuracy: 0.0001,
      "One of three folder pages fills a third of the folders slice"
    )

    // The final step reaching 100% pins the whole bar to 1.0.
    XCTAssertEqual(RefreshStep.sessionKeys, RefreshStep.allCases.last, "sessionKeys is the final step")
    XCTAssertEqual(
      RefreshStep.sessionKeys.fraction(1),
      1.0,
      accuracy: 0.0001,
      "Completing the last step reaches 100%"
    )
  }

  func test_refreshUsersAndGroups_storesBothUsersAndUserGroups() async throws {
    let usersStored: XCTestExpectation = .init(description: "Users should be stored.")
    // The refresh performed when the feature loads writes the same stores.
    usersStored.assertForOverFulfill = false
    let groupsStored: XCTestExpectation = .init(description: "User groups should be stored.")
    groupsStored.assertForOverFulfill = false
    patch(
      \UsersStoreDatabaseOperation.execute,
      with: always({ usersStored.fulfill() }())
    )
    patch(
      \UserGroupsStoreDatabaseOperation.execute,
      with: always({ groupsStored.fulfill() }())
    )

    let feature: SessionData = try self.testedInstance()
    try await feature.refreshUsersAndGroups()

    await fulfillment(of: [usersStored, groupsStored], timeout: 1)
  }

  func test_refreshUsersAndGroups_propagatesFailure() async throws {
    patch(
      \UsersFetchNetworkOperation.execute,
      with: alwaysThrow(MockIssue.error())
    )

    let feature: SessionData = try self.testedInstance()
    await verifyIf(
      try await feature.refreshUsersAndGroups(),
      throws: MockIssue.self,
      "A failed partial refresh must be reported, not swallowed"
    )
  }

  // MARK: - Paginated folders fetch

  func test_refreshIfNeeded_folders_storesMergedSetFromEveryPage() async throws {
    self.prepareFoldersRefresh()
    let folders: Array<ResourceFolderDTO> = (0 ..< 5)
      .map { (index: Int) -> ResourceFolderDTO in .mock(named: "folder-\(index)") }
    let requestedPages: CriticalState<Array<Int>> = .init(.init())
    // Page 1 holds 2 of 5, so the observed page size is 2 and three pages are expected.
    self.patchFoldersFetch(
      pages: [Array(folders[0 ..< 2]), Array(folders[2 ..< 4]), Array(folders[4 ..< 5])],
      count: folders.count,
      requestedPages: requestedPages
    )
    let storedFolders: CriticalState<Array<ResourceFolderDTO>?> = .init(.none)
    self.patchFoldersStore(capturingInto: storedFolders)

    let feature: SessionData = try self.testedInstance()
    try await feature.refreshIfNeeded()

    let stored: Array<ResourceFolderDTO> = try XCTUnwrap(storedFolders.get(), "Folders must be stored")
    XCTAssertEqual(stored, folders, "The store must receive every page, merged in page order")
    XCTAssertEqual(
      Set(requestedPages.get()),
      [1, 2, 3],
      "Every page implied by the total count must be requested, and no page past the end"
    )
  }

  func test_refreshIfNeeded_folders_issuesSingleRequest_whenFirstPageHoldsEverything() async throws {
    self.prepareFoldersRefresh()
    let folders: Array<ResourceFolderDTO> = (0 ..< 5)
      .map { (index: Int) -> ResourceFolderDTO in .mock(named: "folder-\(index)") }
    let requestedPages: CriticalState<Array<Int>> = .init(.init())
    // `limit: 0` is what a server ignoring `limit` reports (`"limit": null`).
    self.patchFoldersFetch(
      pages: [folders],
      count: folders.count,
      limit: 0,
      requestedPages: requestedPages
    )
    let storedFolders: CriticalState<Array<ResourceFolderDTO>?> = .init(.none)
    self.patchFoldersStore(capturingInto: storedFolders)

    let feature: SessionData = try self.testedInstance()
    try await feature.refreshIfNeeded()

    let stored: Array<ResourceFolderDTO> = try XCTUnwrap(storedFolders.get(), "Folders must be stored")
    XCTAssertEqual(stored, folders, "The complete first page must be stored as is")
    XCTAssertEqual(
      Set(requestedPages.get()),
      [1],
      "A complete first page must not trigger a request for any further page"
    )
  }

  func test_refreshIfNeeded_folders_storesEmptySet_whenThereAreNoFolders() async throws {
    self.prepareFoldersRefresh()
    let requestedPages: CriticalState<Array<Int>> = .init(.init())
    self.patchFoldersFetch(
      pages: [.init()],
      count: 0,
      requestedPages: requestedPages
    )
    let storedFolders: CriticalState<Array<ResourceFolderDTO>?> = .init(.none)
    self.patchFoldersStore(capturingInto: storedFolders)

    let feature: SessionData = try self.testedInstance()
    try await feature.refreshIfNeeded()

    let stored: Array<ResourceFolderDTO> = try XCTUnwrap(storedFolders.get(), "Folders must be stored")
    XCTAssertTrue(stored.isEmpty, "An account with no folders must store an empty set")
    XCTAssertEqual(Set(requestedPages.get()), [1], "An empty result must not trigger a second page")
  }

  func test_refreshIfNeeded_folders_abortsWithoutStoring_whenAPageFails() async throws {
    self.prepareFoldersRefresh()
    let folders: Array<ResourceFolderDTO> = (0 ..< 5)
      .map { (index: Int) -> ResourceFolderDTO in .mock(named: "folder-\(index)") }
    let requestedPages: CriticalState<Array<Int>> = .init(.init())
    // Only page 1 is answered; every later page fails the way a `page` past the end does.
    self.patchFoldersFetch(
      pages: [Array(folders[0 ..< 2])],
      count: folders.count,
      requestedPages: requestedPages
    )
    let storeInvoked: CriticalState<Bool> = .init(false)
    patch(
      \ResourceFoldersStoreDatabaseOperation.execute,
      with: { (_: Array<ResourceFolderDTO>) in
        storeInvoked.access { (invoked: inout Bool) in invoked = true }
      }
    )

    let feature: SessionData = try self.testedInstance()
    await verifyIf(
      try await feature.refreshIfNeeded(),
      throws: MockIssue.self,
      "A failed page must abort the refresh, not yield a partial set"
    )

    XCTAssertFalse(
      storeInvoked.get(),
      "A partial set must never reach the store - it deletes every folder absent from its input"
    )
  }

  func test_refreshIfNeeded_folders_abortsWithoutStoring_whenMergedSetIsShort() async throws {
    self.prepareFoldersRefresh()
    let folders: Array<ResourceFolderDTO> = (0 ..< 2)
      .map { (index: Int) -> ResourceFolderDTO in .mock(named: "folder-\(index)") }
    let requestedPages: CriticalState<Array<Int>> = .init(.init())
    // The server reports 5 folders but the later pages come back empty, so the merged set is short.
    self.patchFoldersFetch(
      pages: [folders, .init(), .init()],
      count: 5,
      requestedPages: requestedPages
    )
    let storeInvoked: CriticalState<Bool> = .init(false)
    patch(
      \ResourceFoldersStoreDatabaseOperation.execute,
      with: { (_: Array<ResourceFolderDTO>) in
        storeInvoked.access { (invoked: inout Bool) in invoked = true }
      }
    )

    let feature: SessionData = try self.testedInstance()
    await verifyIf(
      try await feature.refreshIfNeeded(),
      throws: InternalInconsistency.self,
      "Fewer folders than the server reported must fail the refresh rather than delete the difference"
    )

    XCTAssertFalse(storeInvoked.get(), "A provably short set must never reach the store")
  }

  func test_refreshIfNeeded_folders_deduplicatesFoldersRepeatedAcrossPages() async throws {
    self.prepareFoldersRefresh()
    let folders: Array<ResourceFolderDTO> = (0 ..< 3)
      .map { (index: Int) -> ResourceFolderDTO in .mock(named: "folder-\(index)") }
    let requestedPages: CriticalState<Array<Int>> = .init(.init())
    // A folder created or deleted mid-fetch can shift rows across a page boundary and repeat one.
    self.patchFoldersFetch(
      pages: [[folders[0], folders[1]], [folders[1], folders[2]]],
      count: folders.count,
      requestedPages: requestedPages
    )
    let storedFolders: CriticalState<Array<ResourceFolderDTO>?> = .init(.none)
    self.patchFoldersStore(capturingInto: storedFolders)

    let feature: SessionData = try self.testedInstance()
    try await feature.refreshIfNeeded()

    let stored: Array<ResourceFolderDTO> = try XCTUnwrap(storedFolders.get(), "Folders must be stored")
    XCTAssertEqual(stored, folders, "A folder repeated across pages must be stored once, in page order")
    XCTAssertEqual(
      Set(stored.map(\.id)).count,
      stored.count,
      "The store must never receive a duplicate id - topoSort would drop it silently"
    )
  }

  func test_refreshIfNeeded_folders_skipsFetch_whenFeatureIsDisabled() async throws {
    // `.mock_default` keeps folders disabled.
    set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_default.with { $0.metadata = .init(enabled: false) }
      )
    )
    patch(
      \ResourceTypesFetchNetworkOperation.execute,
      with: always([])
    )
    patch(
      \ResourceTypesStoreDatabaseOperation.execute,
      with: always(Void())
    )
    patch(
      \ResourceFoldersFetchNetworkOperation.execute,
      with: { (_: PaginationData) -> PaginatedResponse<Array<ResourceFolderDTO>> in
        XCTFail("Folders must not be fetched while the feature is disabled")
        return .init(
          items: .init(),
          pagination: .init(
            page: 1,
            limit: 0,
            count: 0
          )
        )
      }
    )
    patch(
      \ResourceFoldersStoreDatabaseOperation.execute,
      with: { (_: Array<ResourceFolderDTO>) in
        XCTFail("Folders must not be stored while the feature is disabled")
      }
    )

    let feature: SessionData = try self.testedInstance()
    try await feature.refreshIfNeeded()
  }

  /// Regression guard for the mid-fetch skip: with the page range frozen at what page 1 implied, the
  /// folder pushed onto a later page is never fetched and the store deletes it with its subtree.
  func test_refreshIfNeeded_folders_fetchesAdditionalPage_whenTotalGrowsMidFetch() async throws {
    self.prepareFoldersRefresh()
    let folders: Array<ResourceFolderDTO> = (0 ..< 5)
      .map { (index: Int) -> ResourceFolderDTO in .mock(named: "folder-\(index)") }
    let requestedPages: CriticalState<Array<Int>> = .init(.init())
    // Page 1 sees 4 folders; by page 2 a fifth has become visible, so a third page is implied.
    self.patchFoldersFetch(
      pages: [Array(folders[0 ..< 2]), Array(folders[2 ..< 4]), Array(folders[4 ..< 5])],
      counts: [4, 5, 5],
      requestedPages: requestedPages
    )
    let storedFolders: CriticalState<Array<ResourceFolderDTO>?> = .init(.none)
    self.patchFoldersStore(capturingInto: storedFolders)

    let feature: SessionData = try self.testedInstance()
    try await feature.refreshIfNeeded()

    let stored: Array<ResourceFolderDTO> = try XCTUnwrap(storedFolders.get(), "Folders must be stored")
    XCTAssertEqual(stored, folders, "A total revised upward must extend the page range, not drop the tail")
    XCTAssertEqual(
      Set(requestedPages.get()),
      [1, 2, 3],
      "The page implied by the revised total must be requested - else the store deletes its folders"
    )
  }

  /// A folder shared with this user mid-fetch sorts by its own (older) `created`, so it inserts
  /// mid-sequence and pushes a row across a page boundary: the merged set comes back one short of the
  /// total the later pages report. Storing that deletes the pushed-out folder and its subtree, so the
  /// fetch re-runs instead - by the second pass the server is settled and the whole set arrives.
  func test_refreshIfNeeded_folders_retriesFetch_whenAPageBoundaryShiftedMidFetch() async throws {
    self.prepareFoldersRefresh()
    let folders: Array<ResourceFolderDTO> = (0 ..< 6)
      .map { (index: Int) -> ResourceFolderDTO in
        .mock(named: "folder-\(index)")
      }
    let requestedPages: CriticalState<Array<Int>> = .init(.init())
    // Keyed off how many times page 1 has been requested: the first pass sees the shifted world (a sixth
    // folder counted but pushed past the last page), every later one the settled six.
    let startedPasses: CriticalState<Int> = .init(0)
    patch(
      \ResourceFoldersFetchNetworkOperation.execute,
      with: { (input: PaginationData) -> PaginatedResponse<Array<ResourceFolderDTO>> in
        requestedPages.access { (requested: inout Array<Int>) in
          requested.append(input.page)
        }
        let pass: Int
        if input.page == 1 {
          pass = startedPasses.access { (count: inout Int) -> Int in
            count += 1
            return count
          }
        }
        else {
          pass = startedPasses.get()
        }
        // Pass 1: page 1 still reports the pre-share total, the later pages the post-share one, and the
        // sixth folder is never returned. Pass 2: settled, so every page is full.
        let pages: Array<Array<ResourceFolderDTO>> =
          pass > 1
          ? [Array(folders[0 ..< 2]), Array(folders[2 ..< 4]), Array(folders[4 ..< 6])]
          : [Array(folders[0 ..< 2]), Array(folders[2 ..< 4]), Array(folders[4 ..< 5])]
        let counts: Array<Int> = pass > 1 ? [6, 6, 6] : [4, 6, 6]
        guard input.page >= 1, input.page <= pages.count
        else { throw MockIssue.error() }
        return .init(
          items: pages[input.page - 1],
          pagination: .init(
            page: input.page,
            limit: 2,
            count: counts[input.page - 1]
          )
        )
      }
    )
    let storedFolders: CriticalState<Array<ResourceFolderDTO>?> = .init(.none)
    self.patchFoldersStore(capturingInto: storedFolders)

    let feature: SessionData = try self.testedInstance()
    try await feature.refreshIfNeeded()

    let stored: Array<ResourceFolderDTO> = try XCTUnwrap(storedFolders.get(), "Folders must be stored")
    XCTAssertEqual(stored, folders, "The settled pass must be stored whole - a short set deletes folders")
    XCTAssertGreaterThanOrEqual(
      requestedPages.get().filter { (page: Int) -> Bool in page == 1 }.count,
      2,
      "A set short of the latest reported total must be re-fetched, not stored"
    )
    XCTAssertEqual(
      Set(requestedPages.get()),
      [1, 2, 3],
      "Every page implied by the total must be requested, and no page past the end"
    )
  }

  /// Two short passes in a row must still resolve. A single mid-fetch deletion is enough to spend a pass
  /// (the largest reported total is the yardstick, so the harmless shape costs one too), which makes a
  /// one-retry budget fail a refresh the third pass would have completed - and `refreshFolders` is awaited
  /// before `refreshResources`, so that stops resources syncing as well.
  ///
  /// Driven against `ResourceFoldersFetch` directly rather than through `SessionData`: each
  /// `refreshIfNeeded` gets its own retry budget, and the refresh performed when the feature loads races
  /// the explicit one, so a swallowed load-time failure followed by a fresh settled pass would let this
  /// pass at any budget.
  func test_foldersFetch_retriesUntilTheBudgetIsSpent_whenPassesComeBackShort() async throws {
    let folders: Array<ResourceFolderDTO> = (0 ..< 4)
      .map { (index: Int) -> ResourceFolderDTO in .mock(named: "folder-\(index)") }
    let serverPageSize: Int = 2
    // Counted off page 1, which is where every pass starts.
    let startedPasses: CriticalState<Int> = .init(0)
    let foldersFetch: ResourceFoldersFetch = .init(
      configuration: .application,
      fetchPage: { (input: PaginationData) async throws -> ResourceFoldersFetchNetworkOperationResult in
        let pass: Int
        if input.page == 1 {
          pass = startedPasses.access { (count: inout Int) -> Int in
            count += 1
            return count
          }
        }
        else {
          pass = startedPasses.get()
        }
        // Passes 1 and 2 lose the last row to a mid-fetch shift while still reporting the full total;
        // pass 3 is settled, so every page is there.
        let available: Array<ResourceFolderDTO> = pass > 2 ? folders : Array(folders[0 ..< 3])
        let offset: Int = (input.page - 1) * serverPageSize
        guard offset < available.count
        else { throw MockIssue.error() }  // as a `page` past the end does
        return .init(
          items: Array(available[offset ..< min(offset + serverPageSize, available.count)]),
          pagination: .init(
            page: input.page,
            limit: serverPageSize,
            count: folders.count
          )
        )
      },
      reportProgress: { (_: Double) in }
    )

    let fetched: Array<ResourceFolderDTO> = try await foldersFetch.execute()

    XCTAssertEqual(fetched, folders, "The settled pass must be returned whole - a short set deletes folders")
    XCTAssertEqual(
      startedPasses.get(),
      3,
      "A second consecutive short pass must be retried, not failed - one budgeted retry is not enough"
    )
  }

  /// A server may clamp `limit` to a smaller maximum of its own without echoing it (`"limit": null`).
  /// Read as one short page, the whole set trips the completeness check on every refresh - and since
  /// `refreshFolders` is awaited before `refreshResources`, resources would stop syncing with it.
  func test_refreshIfNeeded_folders_pagesByReturnedSize_whenServerClampsLimitWithoutReportingIt() async throws {
    self.prepareFoldersRefresh()
    let folders: Array<ResourceFolderDTO> = (0 ..< 5)
      .map { (index: Int) -> ResourceFolderDTO in
        .mock(named: "folder-\(index)")
      }
    let requestedPages: CriticalState<Array<Int>> = .init(.init())
    // Whatever the configured page size is, this server answers with at most two rows and reports no
    // limit of its own, so the only stride available is the size of the page it returned.
    let serverPageSize: Int = 2
    patch(
      \ResourceFoldersFetchNetworkOperation.execute,
      with: { (input: PaginationData) -> PaginatedResponse<Array<ResourceFolderDTO>> in
        requestedPages.access { (requested: inout Array<Int>) in
          requested.append(input.page)
        }
        // Offsets by the `limit` it was asked for while clamping the rows it returns - the harsher of the
        // two clamping servers, and the one that only lines up when the later pages request the stride
        // page 1 came back with instead of the size page 1 was asked for.
        let offset: Int = (input.page - 1) * input.limit
        guard offset < folders.count
        else { throw MockIssue.error() }  // as a `page` past the end does
        return .init(
          items: Array(folders[offset ..< min(offset + serverPageSize, folders.count)]),
          pagination: .init(
            page: input.page,
            limit: 0,
            count: folders.count
          )
        )
      }
    )
    let storedFolders: CriticalState<Array<ResourceFolderDTO>?> = .init(.none)
    self.patchFoldersStore(capturingInto: storedFolders)

    let feature: SessionData = try self.testedInstance()
    try await feature.refreshIfNeeded()

    let stored: Array<ResourceFolderDTO> = try XCTUnwrap(storedFolders.get(), "Folders must be stored")
    XCTAssertEqual(stored, folders, "A clamped limit must still be paged - every folder has to be stored")
    XCTAssertEqual(
      Set(requestedPages.get()),
      [1, 2, 3],
      "The returned page size is the stride when the server reports none"
    )
  }

  /// The same clamping server, but echoing the `limit` it was asked for instead of `null`. A first page
  /// short of both the echoed limit and the total cannot be the last page, so the echo is the value that
  /// has to be distrusted - taking it as the stride puts every later page on the wrong offset, and unlike
  /// a mid-fetch shift no retry recovers from that: the refresh fails on every pass, and since
  /// `refreshFolders` is awaited before `refreshResources`, resources stop syncing with it.
  func test_refreshIfNeeded_folders_pagesByReturnedSize_whenServerClampsLimitButEchoesTheRequestedOne()
    async throws
  {
    self.prepareFoldersRefresh()
    let folders: Array<ResourceFolderDTO> = (0 ..< 5)
      .map { (index: Int) -> ResourceFolderDTO in .mock(named: "folder-\(index)") }
    let requestedPages: CriticalState<Array<Int>> = .init(.init())
    // At most two rows per page, while the requested `limit` is echoed back untouched.
    let serverPageSize: Int = 2
    patch(
      \ResourceFoldersFetchNetworkOperation.execute,
      with: { (input: PaginationData) -> PaginatedResponse<Array<ResourceFolderDTO>> in
        requestedPages.access { (requested: inout Array<Int>) in
          requested.append(input.page)
        }
        // Offsets by the `limit` it was asked for while clamping the rows it returns - the harsher of the
        // two clamping servers, and the one that only lines up when the later pages request the stride
        // page 1 came back with instead of the size page 1 was asked for.
        let offset: Int = (input.page - 1) * input.limit
        guard offset < folders.count
        else { throw MockIssue.error() }  // as a `page` past the end does
        return .init(
          items: Array(folders[offset ..< min(offset + serverPageSize, folders.count)]),
          pagination: .init(
            page: input.page,
            limit: input.limit,
            count: folders.count
          )
        )
      }
    )
    let storedFolders: CriticalState<Array<ResourceFolderDTO>?> = .init(.none)
    self.patchFoldersStore(capturingInto: storedFolders)

    let feature: SessionData = try self.testedInstance()
    try await feature.refreshIfNeeded()

    let stored: Array<ResourceFolderDTO> = try XCTUnwrap(storedFolders.get(), "Folders must be stored")
    XCTAssertEqual(stored, folders, "A body shorter than the echoed limit must still be paged in full")
    XCTAssertEqual(
      Set(requestedPages.get()),
      [1, 2, 3],
      "A first page short of both the echoed limit and the total must be paged by the rows it returned"
    )
  }

  /// A server may report a `limit` narrower than the page it just sent (`limit: 1` alongside a full page).
  /// The rows in hand prove the stride is at least that wide, so they win over the block - reading the
  /// echo as the stride puts every later page on a fraction of the right offset, and no pass recovers.
  func test_refreshIfNeeded_folders_pagesByReturnedSize_whenServerUnderreportsTheLimit() async throws {
    self.prepareFoldersRefresh()
    let folders: Array<ResourceFolderDTO> = ResourceFolderDTO.mocks(count: 5)
    let requestedPages: CriticalState<Array<Int>> = .init(.init())
    // Two rows per page while reporting `limit: 1`, offsetting by the `limit` it was asked for.
    let serverPageSize: Int = 2
    patch(
      \ResourceFoldersFetchNetworkOperation.execute,
      with: { (input: PaginationData) -> PaginatedResponse<Array<ResourceFolderDTO>> in
        requestedPages.access { (requested: inout Array<Int>) in
          requested.append(input.page)
        }
        let offset: Int = (input.page - 1) * input.limit
        guard offset < folders.count
        else { throw MockIssue.error() }  // as a `page` past the end does
        return .init(
          items: Array(folders[offset ..< min(offset + serverPageSize, folders.count)]),
          pagination: .init(
            page: input.page,
            limit: 1,
            count: folders.count
          )
        )
      }
    )
    let storedFolders: CriticalState<Array<ResourceFolderDTO>?> = .init(.none)
    self.patchFoldersStore(capturingInto: storedFolders)

    let feature: SessionData = try self.testedInstance()
    try await feature.refreshIfNeeded()

    let stored: Array<ResourceFolderDTO> = try XCTUnwrap(storedFolders.get(), "Folders must be stored")
    XCTAssertEqual(stored, folders, "A limit narrower than the page sent must still page the whole set")
    // The requested pages are what catch a stride taken from the block: a stride of 1 walks pages 1...5 at
    // single-row offsets, which dedups back to the same folders and hides the mistake from the merged set.
    XCTAssertEqual(
      Set(requestedPages.get()),
      [1, 2, 3],
      "The rows page 1 delivered are the stride, not the narrower limit the server reported"
    )
  }

  /// A first page that comes back empty while reporting a non-zero total must not be paged over: with the
  /// stride taken from the row count instead of the reported limit, that implies one request per folder.
  func test_refreshIfNeeded_folders_doesNotFanOut_whenFirstPageIsEmptyWithNonZeroTotal() async throws {
    self.prepareFoldersRefresh()
    let requestedPages: CriticalState<Array<Int>> = .init(.init())
    // `limit: 0` is what a server reporting `"limit": null` sends - no stride to page by.
    self.patchFoldersFetch(
      pages: [.init()],
      count: 5,
      limit: 0,
      requestedPages: requestedPages
    )
    let storeInvoked: CriticalState<Bool> = .init(false)
    patch(
      \ResourceFoldersStoreDatabaseOperation.execute,
      with: { (_: Array<ResourceFolderDTO>) in
        storeInvoked.access { (invoked: inout Bool) in invoked = true }
      }
    )

    let feature: SessionData = try self.testedInstance()
    await verifyIf(
      try await feature.refreshIfNeeded(),
      throws: InternalInconsistency.self,
      "A body shorter than the reported total with no stride to page by must fail the refresh"
    )

    // A set, not the raw array: the refresh performed when the feature loads may race the explicit one,
    // so page 1 can legitimately be requested by both.
    XCTAssertEqual(
      Set(requestedPages.get()),
      [1],
      "An empty first page must not be turned into one request per reported folder"
    )
    XCTAssertFalse(storeInvoked.get(), "An empty set must not replace the stored folders")
  }

  /// A total that keeps growing must not extend the range forever - and the truncated result it leaves
  /// must not be stored: pages the server implied were never requested, so the store would delete the
  /// folders they hold.
  func test_refreshIfNeeded_folders_abortsWithoutStoring_whenRangeIsTruncatedAtTheWaveCap() async throws {
    self.prepareFoldersRefresh()
    let folders: Array<ResourceFolderDTO> = (0 ..< 8)
      .map { (index: Int) -> ResourceFolderDTO in .mock(named: "folder-\(index)") }
    let requestedPages: CriticalState<Array<Int>> = .init(.init())
    // Each page reports a larger total than the last, so every wave implies one more page.
    self.patchFoldersFetch(
      pages: [
        Array(folders[0 ..< 2]),
        Array(folders[2 ..< 4]),
        Array(folders[4 ..< 6]),
        Array(folders[6 ..< 8]),
      ],
      counts: [4, 6, 8, 10],
      requestedPages: requestedPages
    )
    let storeInvoked: CriticalState<Bool> = .init(false)
    patch(
      \ResourceFoldersStoreDatabaseOperation.execute,
      with: { (_: Array<ResourceFolderDTO>) in
        storeInvoked.access { (invoked: inout Bool) in invoked = true }
      }
    )

    let feature: SessionData = try self.testedInstance()
    await verifyIf(
      try await feature.refreshIfNeeded(),
      throws: InternalInconsistency.self,
      "A range truncated at the wave cap is provably incomplete and must fail the refresh"
    )

    // One initial range plus `ResourceFoldersFetch.maximumPageDiscoveryWaves` extensions, then it stops.
    XCTAssertEqual(
      Set(requestedPages.get()),
      [1, 2, 3, 4],
      "The range must stop extending at the wave cap"
    )
    XCTAssertFalse(
      storeInvoked.get(),
      "A set missing the pages the latest total implies must never reach the store"
    )
  }

  /// A server may apply `limit` without echoing it (`"limit": null`), leaving no reported stride. A page
  /// filled to exactly the requested size must then be paged by that size - read as one short page, the
  /// whole set trips the completeness check on every refresh, and since `refreshFolders` is awaited before
  /// `refreshResources`, resources stop syncing too.
  func test_refreshIfNeeded_folders_pagesByRequestedSize_whenServerAppliesLimitWithoutReportingIt() async throws {
    self.prepareFoldersRefresh()
    let requestedPages: CriticalState<Array<Int>> = .init(.init())
    // Pages are synthesized from the requested `limit`, so the expectations below hold whichever
    // `ResourceFoldersFetchConfiguration` tier the test bundle resolves to.
    let reportedTotal: CriticalState<Int> = .init(0)
    patch(
      \ResourceFoldersFetchNetworkOperation.execute,
      with: { (input: PaginationData) -> PaginatedResponse<Array<ResourceFolderDTO>> in
        requestedPages.access { (requested: inout Array<Int>) in
          requested.append(input.page)
        }
        // Two full pages plus a partial third.
        let total: Int = 2 * input.limit + 1
        reportedTotal.access { (value: inout Int) in value = total }
        let offset: Int = (input.page - 1) * input.limit
        guard offset < total
        else { throw MockIssue.error() }  // as a `page` past the end does
        let rowCount: Int = min(input.limit, total - offset)
        return .init(
          items: (0 ..< rowCount)
            .map { (index: Int) -> ResourceFolderDTO in
              .mock(named: "folder-\(offset + index)")
            },
          // `limit: 0` is what a server reporting `"limit": null` sends - even though it applied ours.
          pagination: .init(
            page: input.page,
            limit: 0,
            count: total
          )
        )
      }
    )
    let storedFolders: CriticalState<Array<ResourceFolderDTO>?> = .init(.none)
    self.patchFoldersStore(capturingInto: storedFolders)

    let feature: SessionData = try self.testedInstance()
    try await feature.refreshIfNeeded()

    let stored: Array<ResourceFolderDTO> = try XCTUnwrap(storedFolders.get(), "Folders must be stored")
    XCTAssertEqual(
      stored.count,
      reportedTotal.get(),
      "A silently applied limit must still be paged - every reported folder has to reach the store"
    )
    XCTAssertEqual(
      Set(stored.map(\.id)).count,
      stored.count,
      "The merged set must hold no duplicate ids"
    )
    XCTAssertEqual(
      Set(requestedPages.get()),
      [1, 2, 3],
      "A page filled to the requested limit must be paged by that limit, not read as the whole set"
    )
  }

  // MARK: - Page stride derivation

  /// `effectivePageSize` decides how many pages the fetch walks, from three numbers the server controls:
  /// the rows it sent, the `limit` it reported, the `count` it reported. Driven directly - the case where
  /// a page arrives wider than the limit it was asked for cannot be reached through `SessionData` without
  /// synthesizing thousands of folders.
  func test_effectivePageSize_derivesStrideFromWhatTheServerActuallySent() {
    let requested: Int = 4

    XCTAssertEqual(
      ResourceFoldersFetch.effectivePageSize(
        of: ResourceFolderDTO.mocks(count: 4).asPaginatedResponse(limit: 4, count: 10),
        requested: requested
      ),
      4,
      "An honest echo on a page filled to it is the stride"
    )
    XCTAssertEqual(
      ResourceFoldersFetch.effectivePageSize(
        of: ResourceFolderDTO.mocks(count: 3).asPaginatedResponse(limit: 4, count: 3),
        requested: requested
      ),
      4,
      "A body short of the limit but holding the whole total is the last page - the echo stands"
    )
    XCTAssertEqual(
      ResourceFoldersFetch.effectivePageSize(
        of: ResourceFolderDTO.mocks(count: 2).asPaginatedResponse(limit: 4, count: 10),
        requested: requested
      ),
      2,
      "A body shorter than both the limit and the total is a clamping server - its rows are the stride"
    )
    XCTAssertEqual(
      ResourceFoldersFetch.effectivePageSize(
        of: ResourceFolderDTO.mocks(count: 4).asPaginatedResponse(limit: 1, count: 10),
        requested: requested
      ),
      4,
      "A limit narrower than the page just sent loses to the rows in hand"
    )
    XCTAssertEqual(
      ResourceFoldersFetch.effectivePageSize(
        of: ResourceFolderDTO.mocks(count: 4).asPaginatedResponse(limit: 0, count: 10),
        requested: requested
      ),
      4,
      "A silently applied limit (`\"limit\": null`) looks like a page filled to the requested size"
    )
    XCTAssertEqual(
      ResourceFoldersFetch.effectivePageSize(
        of: ResourceFolderDTO.mocks(count: 2).asPaginatedResponse(limit: 0, count: 10),
        requested: requested
      ),
      2,
      "A short page with no limit reported is that same clamping server"
    )
    XCTAssertEqual(
      ResourceFoldersFetch.effectivePageSize(
        of: ResourceFolderDTO.mocks(count: 6).asPaginatedResponse(limit: 0, count: 10),
        requested: requested
      ),
      6,
      "A server paging wider than it was asked pages by what it sent, not by what was asked"
    )
    XCTAssertEqual(
      ResourceFoldersFetch.effectivePageSize(
        of: Array<ResourceFolderDTO>().asPaginatedResponse(limit: 0, count: 5),
        requested: requested
      ),
      0,
      "An empty body implies no stride at all"
    )
  }

  // MARK: - Folders helpers

  /// Enables the folders feature (`.mock_default` has it off) and stubs the rest of the refresh, so each
  /// folders test only has to describe the pages the server returns.
  private func prepareFoldersRefresh() {
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
      \ResourceTypesFetchNetworkOperation.execute,
      with: always([])
    )
    patch(
      \ResourceTypesStoreDatabaseOperation.execute,
      with: always(Void())
    )
  }

  /// Answers the folders fetch from `pages` (1-indexed) and records every requested page number.
  /// A page past the end throws, as the server's 404 does. Every page reports the same total.
  private func patchFoldersFetch(
    pages: Array<Array<ResourceFolderDTO>>,
    count: Int,
    limit: Int = 2,
    requestedPages: CriticalState<Array<Int>>
  ) {
    self.patchFoldersFetch(
      pages: pages,
      counts: Array(repeating: count, count: max(pages.count, 1)),
      limit: limit,
      requestedPages: requestedPages
    )
  }

  /// Per-page-total variant: `counts[n]` is the total page `n + 1` reports, so a total revised upward
  /// mid-fetch - a folder created, or an existing one shared with this user - can be simulated.
  private func patchFoldersFetch(
    pages: Array<Array<ResourceFolderDTO>>,
    counts: Array<Int>,
    limit: Int = 2,
    requestedPages: CriticalState<Array<Int>>
  ) {
    patch(
      \ResourceFoldersFetchNetworkOperation.execute,
      with: { (input: PaginationData) -> PaginatedResponse<Array<ResourceFolderDTO>> in
        requestedPages.access { (requested: inout Array<Int>) in
          requested.append(input.page)
        }
        guard input.page >= 1, input.page <= pages.count, !counts.isEmpty
        else { throw MockIssue.error() }
        return .init(
          items: pages[input.page - 1],
          pagination: .init(
            page: input.page,
            limit: limit,
            count: counts[min(input.page, counts.count) - 1]
          )
        )
      }
    )
  }

  /// Captures the last set handed to the folders store - the refresh performed when the feature loads
  /// writes the same store.
  private func patchFoldersStore(
    capturingInto storedFolders: CriticalState<Array<ResourceFolderDTO>?>
  ) {
    patch(
      \ResourceFoldersStoreDatabaseOperation.execute,
      with: { (input: Array<ResourceFolderDTO>) in
        storedFolders.access { (stored: inout Array<ResourceFolderDTO>?) in
          stored = input
        }
      }
    )
  }
}
