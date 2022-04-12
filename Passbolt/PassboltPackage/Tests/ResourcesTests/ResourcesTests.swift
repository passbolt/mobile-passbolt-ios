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

import CommonModels
import Crypto
import Features
import NetworkClient
import TestExtensions
import XCTest

@testable import Accounts
@testable import Resources

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class ResourceTests: TestCase {

  var accountSession: AccountSession!
  var accountDatabase: AccountDatabase!
  var networkClient: NetworkClient!

  override func featuresActorSetUp() async throws {
    try await super.featuresActorSetUp()
    accountSession = .placeholder
    accountSession.statePublisher = always(
      Just(.authorized(validAccount))
        .eraseToAnyPublisher()
    )

    accountDatabase = .placeholder
    accountDatabase.fetchLastUpdate.execute = always(
      Date(timeIntervalSince1970: 0)
    )
    accountDatabase.saveLastUpdate.execute = always(
      Void()
    )
    accountDatabase.storeResourcesTypes.execute = always(
      Void()
    )
    accountDatabase.storeResources.execute = always(
      Void()
    )

    networkClient = .placeholder
    networkClient.resourcesTypesRequest.execute = always(
      .init(header: .mock(), body: [])
    )
    networkClient.resourcesRequest.execute = always(
      .init(header: .mock(), body: [])
    )

    try await FeaturesActor.execute {
      self.features.environment.time.timestamp = always(100)
    }
    await features.usePlaceholder(for: Folders.self)
    features.patch(\FeatureConfig.config, with: always(.none))
  }

  override func featuresActorTearDown() async throws {
    accountSession = nil
    accountDatabase = nil
    networkClient = nil
    try await super.featuresActorTearDown()
  }

  func test_refreshIfNeeded_refreshesData_whenDiffIsNotEmpty() async throws {
    XCTExpectFailure()
    XCTFail("Data diff is not implemented yet")
  }

  func test_refreshIfNeeded_fetchesResourceTypes() async throws {
    await features.use(accountSession)
    await features.use(accountDatabase)
    var result: Void?
    networkClient.resourcesTypesRequest.execute = { _ in
      result = Void()
      return .init(header: .mock(), body: [])
    }
    await features.use(networkClient)

    let feature: Resources = try await testInstance()

    try await feature
      .refreshIfNeeded()
      .asAsyncValue()

    XCTAssertNotNil(result)
  }

  func test_refreshIfNeeded_fails_whenResourceTypesFetchFails() async throws {
    await features.use(accountSession)
    await features.use(accountDatabase)
    networkClient.resourcesTypesRequest.execute = alwaysThrow(
      MockIssue.error()
    )
    await features.use(networkClient)

    let feature: Resources = try await testInstance()

    var result: Error?
    do {
      try await feature
        .refreshIfNeeded()
        .asAsyncValue()
    }
    catch {
      result = error
    }

    XCTAssertError(result, matches: MockIssue.self)
  }

  func test_refreshIfNeeded_savesResourceTypesToDatabase() async throws {
    await features.use(accountSession)
    var result: Void?
    accountDatabase.storeResourcesTypes.execute = { _ in
      result = Void()
      return Void()
    }
    await features.use(accountDatabase)
    await features.use(networkClient)

    let feature: Resources = try await testInstance()

    try await feature
      .refreshIfNeeded()
      .asAsyncValue()

    XCTAssertNotNil(result)
  }

  func test_refreshIfNeeded_fails_whenResourceTypesSaveFails() async throws {
    await features.use(accountSession)
    accountDatabase.storeResourcesTypes.execute = alwaysThrow(
      MockIssue.error()
    )
    await features.use(accountDatabase)
    await features.use(networkClient)

    let feature: Resources = try await testInstance()

    var result: Error?
    do {
      try await feature
        .refreshIfNeeded()
        .asAsyncValue()
    }
    catch {
      result = error
    }

    XCTAssertError(result, matches: MockIssue.self)
  }

  func test_refreshIfNeeded_fetchesResources() async throws {
    await features.use(accountSession)
    await features.use(accountDatabase)
    var result: Void?
    networkClient.resourcesRequest.execute = { _ in
      result = Void()
      return .init(header: .mock(), body: [])
    }
    await features.use(networkClient)

    let feature: Resources = try await testInstance()

    try await feature
      .refreshIfNeeded()
      .asAsyncValue()

    XCTAssertNotNil(result)
  }

  func test_refreshIfNeeded_fails_whenResourceFetchFails() async throws {
    await features.use(accountSession)
    await features.use(accountDatabase)
    networkClient.resourcesRequest.execute = alwaysThrow(
      MockIssue.error()
    )
    await features.use(networkClient)

    let feature: Resources = try await testInstance()

    var result: Error?
    do {
      try await feature
        .refreshIfNeeded()
        .asAsyncValue()
    }
    catch {
      result = error
    }

    XCTAssertError(result, matches: MockIssue.self)
  }

  func test_refreshIfNeeded_savesResourcesToDatabase() async throws {
    await features.use(accountSession)
    var result: Void?
    accountDatabase.storeResources.execute = { _ in
      result = Void()
      return Void()
    }
    await features.use(accountDatabase)
    await features.use(networkClient)

    let feature: Resources = try await testInstance()

    try await feature
      .refreshIfNeeded()
      .asAsyncValue()

    XCTAssertNotNil(result)
  }

  func test_refreshIfNeeded_fails_whenResourceSaveFails() async throws {
    await features.use(accountSession)
    accountDatabase.storeResourcesTypes.execute = alwaysThrow(
      MockIssue.error()
    )
    await features.use(accountDatabase)
    await features.use(networkClient)

    let feature: Resources = try await testInstance()

    var result: Error?
    do {
      try await feature
        .refreshIfNeeded()
        .asAsyncValue()
    }
    catch {
      result = error
    }

    XCTAssertError(result, matches: MockIssue.self)
  }

  func test_filteredResourcesListPublisher_publishesResourcesFromDatabase() async throws {
    await features.use(accountSession)
    accountDatabase.fetchListViewResources.execute = always(
      .testResources
    )
    await features.use(accountDatabase)
    await features.use(networkClient)

    let feature: Resources = try await testInstance()

    let filterSubject: CurrentValueSubject<ResourcesFilter, Never> = .init(testFilter)

    let result: Array<ListViewResource>? =
      try await feature
      .filteredResourcesListPublisher(filterSubject.eraseToAnyPublisher())
      .asAsyncValue()

    XCTAssertEqual(result, .testResources)
  }

  func test_filteredResourcesListPublisher_usesFilterWhenAccessingDatabase() async throws {
    await features.use(accountSession)
    var result: ResourcesFilter?
    accountDatabase.fetchListViewResources.execute = { filter in
      result = filter
      return .testResources
    }
    await features.use(accountDatabase)
    await features.use(networkClient)

    let feature: Resources = try await testInstance()

    let filterSubject: CurrentValueSubject<ResourcesFilter, Never> = .init(testFilter)

    _ =
      try await feature
      .filteredResourcesListPublisher(filterSubject.eraseToAnyPublisher())
      .asAsyncValue()

    XCTAssertEqual(result, testFilter)
  }

  func test_filteredResourcesListPublisher_updatesData_whenFilterChanges() async throws {
    await features.use(accountSession)
    var resources: Array<ListViewResource> = .testResources
    accountDatabase.fetchListViewResources.execute = always(
      resources
    )
    await features.use(accountDatabase)
    await features.use(networkClient)

    let feature: Resources = try await testInstance()

    let filterSubject: CurrentValueSubject<ResourcesFilter, Never> = .init(testFilter)

    var result: Array<ListViewResource>? =
      try? await feature
      .filteredResourcesListPublisher(filterSubject.eraseToAnyPublisher())
      .asAsyncValue()

    resources = .testResourcesAlternative

    filterSubject.send(.init(sorting: .nameAlphabetically))

    result =
      try? await feature
      .filteredResourcesListPublisher(filterSubject.eraseToAnyPublisher())
      .asAsyncValue()

    XCTAssertEqual(result, .testResourcesAlternative)
  }

  func test_filteredResourcesListPublisher_publishesResourcesAfterUpdate() async throws {
    await features.use(accountSession)
    var resources: Array<ListViewResource> = .testResources
    accountDatabase.fetchListViewResources.execute = always(
      resources
    )
    await features.use(accountDatabase)
    await features.use(networkClient)

    let feature: Resources = try await testInstance()

    let filterSubject: CurrentValueSubject<ResourcesFilter, Never> = .init(testFilter)

    var result: Array<ListViewResource>?
    feature
      .filteredResourcesListPublisher(filterSubject.eraseToAnyPublisher())
      .sink { resources in
        result = resources
      }
      .store(in: cancellables)

    resources = .testResourcesAlternative

    try await feature
      .refreshIfNeeded()
      .asAsyncValue()

    XCTAssertEqual(result, .testResourcesAlternative)
  }

  func test_filteredResourcesListPublisher_publishesEmptyList_onDatabaseError() async throws {
    await features.use(accountSession)
    accountDatabase.fetchListViewResources.execute = alwaysThrow(
      MockIssue.error()
    )
    await features.use(accountDatabase)
    await features.use(networkClient)

    let feature: Resources = try await testInstance()

    let filterSubject: CurrentValueSubject<ResourcesFilter, Never> = .init(testFilter)

    let result: Array<ListViewResource>? =
      try? await feature
      .filteredResourcesListPublisher(filterSubject.eraseToAnyPublisher())
      .asAsyncValue()

    XCTAssertEqual(result, [])
  }

  func test_delete_triggersRefreshIfNeeded_whenDeletion_succeeds() async throws {
    var result: Void?
    await features.use(accountSession)
    await features.use(accountDatabase)
    networkClient.deleteResourceRequest.execute = { _ in
      return Void()
    }
    networkClient.resourcesRequest.execute = { _ in
      result = Void()
      return .init(header: .mock(), body: .init())
    }
    await features.use(networkClient)

    let feature: Resources = try await testInstance()

    try await feature
      .deleteResource(.init(rawValue: "test"))
      .asAsyncValue()

    XCTAssertNotNil(result)
  }
}

private let validAccount: Account = .init(
  localID: .init(rawValue: UUID.test.uuidString),
  domain: "https://passbolt.dev",
  userID: "USER_ID",
  fingerprint: "FINGERPRINT"
)

private let testFilter: ResourcesFilter = .init(
  sorting: .nameAlphabetically,
  text: "test",
  name: "test",
  url: "test"
)
