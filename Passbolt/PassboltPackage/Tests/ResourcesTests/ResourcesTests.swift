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

import Commons
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

  override func setUp() {
    super.setUp()
    accountSession = .placeholder
    accountSession.statePublisher = always(
      Just(.authorized(validAccount))
        .eraseToAnyPublisher()
    )

    accountDatabase = .placeholder
    accountDatabase.fetchLastUpdate.execute = always(
      Just(Date(timeIntervalSince1970: 0))
        .setFailureType(to: TheErrorLegacy.self)
        .eraseToAnyPublisher()
    )
    accountDatabase.saveLastUpdate.execute = always(
      Just(Void())
        .setFailureType(to: TheErrorLegacy.self)
        .eraseToAnyPublisher()
    )
    accountDatabase.storeResourcesTypes.execute = always(
      Just(Void())
        .setFailureType(to: TheErrorLegacy.self)
        .eraseToAnyPublisher()
    )
    accountDatabase.storeResources.execute = always(
      Just(Void())
        .setFailureType(to: TheErrorLegacy.self)
        .eraseToAnyPublisher()
    )

    networkClient = .placeholder
    networkClient.resourcesTypesRequest.execute = always(
      Just(.init(header: .mock(), body: []))
        .eraseErrorType()
        .eraseToAnyPublisher()
    )
    networkClient.resourcesRequest.execute = always(
      Just(.init(header: .mock(), body: []))
        .eraseErrorType()
        .eraseToAnyPublisher()
    )

    features.environment.time.timestamp = always(100)
  }

  override func tearDown() {
    accountSession = nil
    accountDatabase = nil
    networkClient = nil
    super.tearDown()
  }

  func test_refreshIfNeeded_refreshesData_whenDiffIsNotEmpty() {
    XCTExpectFailure()
    XCTFail("Data diff is not implemented yet")
  }

  func test_refreshIfNeeded_fetchesResourceTypes() {
    features.use(accountSession)
    features.use(accountDatabase)
    var result: Void?
    networkClient.resourcesTypesRequest.execute = { _ in
      result = Void()
      return Just(.init(header: .mock(), body: []))
        .eraseErrorType()
        .eraseToAnyPublisher()
    }
    features.use(networkClient)

    let feature: Resources = testInstance()

    feature
      .refreshIfNeeded()
      .sinkDrop()
      .store(in: cancellables)

    XCTAssertNotNil(result)
  }

  func test_refreshIfNeeded_fails_whenResourceTypesFetchFails() {
    features.use(accountSession)
    features.use(accountDatabase)
    networkClient.resourcesTypesRequest.execute = always(
      Fail(error: MockIssue.error())
        .eraseToAnyPublisher()
    )
    features.use(networkClient)

    let feature: Resources = testInstance()

    var result: TheErrorLegacy?
    feature
      .refreshIfNeeded()
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in /* NOP */ }
      )
      .store(in: cancellables)

    XCTAssertError(result?.legacyBridge, matches: MockIssue.self)
  }

  func test_refreshIfNeeded_savesResourceTypesToDatabase() {
    features.use(accountSession)
    var result: Void?
    accountDatabase.storeResourcesTypes.execute = { _ in
      result = Void()
      return Just(Void())
        .setFailureType(to: TheErrorLegacy.self)
        .eraseToAnyPublisher()
    }
    features.use(accountDatabase)
    features.use(networkClient)

    let feature: Resources = testInstance()

    feature
      .refreshIfNeeded()
      .sinkDrop()
      .store(in: cancellables)

    XCTAssertNotNil(result)
  }

  func test_refreshIfNeeded_fails_whenResourceTypesSaveFails() {
    features.use(accountSession)
    accountDatabase.storeResourcesTypes.execute = always(
      Fail(error: .testError())
        .eraseToAnyPublisher()
    )
    features.use(accountDatabase)
    features.use(networkClient)

    let feature: Resources = testInstance()

    var result: TheErrorLegacy?
    feature
      .refreshIfNeeded()
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in /* NOP */ }
      )
      .store(in: cancellables)

    XCTAssertEqual(result?.identifier, .testError)
  }

  func test_refreshIfNeeded_fetchesResources() {
    features.use(accountSession)
    features.use(accountDatabase)
    var result: Void?
    networkClient.resourcesRequest.execute = { _ in
      result = Void()
      return Just(.init(header: .mock(), body: []))
        .eraseErrorType()
        .eraseToAnyPublisher()
    }
    features.use(networkClient)

    let feature: Resources = testInstance()

    feature
      .refreshIfNeeded()
      .sinkDrop()
      .store(in: cancellables)

    XCTAssertNotNil(result)
  }

  func test_refreshIfNeeded_fails_whenResourceFetchFails() {
    features.use(accountSession)
    features.use(accountDatabase)
    networkClient.resourcesRequest.execute = always(
      Fail(error: MockIssue.error())
        .eraseToAnyPublisher()
    )
    features.use(networkClient)

    let feature: Resources = testInstance()

    var result: TheErrorLegacy?
    feature
      .refreshIfNeeded()
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in /* NOP */ }
      )
      .store(in: cancellables)

    XCTAssertError(result?.legacyBridge, matches: MockIssue.self)
  }

  func test_refreshIfNeeded_savesResourcesToDatabase() {
    features.use(accountSession)
    var result: Void?
    accountDatabase.storeResources.execute = { _ in
      result = Void()
      return Just(Void())
        .setFailureType(to: TheErrorLegacy.self)
        .eraseToAnyPublisher()
    }
    features.use(accountDatabase)
    features.use(networkClient)

    let feature: Resources = testInstance()

    feature
      .refreshIfNeeded()
      .sinkDrop()
      .store(in: cancellables)

    XCTAssertNotNil(result)
  }

  func test_refreshIfNeeded_fails_whenResourceSaveFails() {
    features.use(accountSession)
    accountDatabase.storeResourcesTypes.execute = always(
      Fail(error: .testError())
        .eraseToAnyPublisher()
    )
    features.use(accountDatabase)
    features.use(networkClient)

    let feature: Resources = testInstance()

    var result: TheErrorLegacy?
    feature
      .refreshIfNeeded()
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in /* NOP */ }
      )
      .store(in: cancellables)

    XCTAssertEqual(result?.identifier, .testError)
  }

  func test_filteredResourcesListPublisher_publishesResourcesFromDatabase() {
    features.use(accountSession)
    accountDatabase.fetchListViewResources.execute = always(
      Just(testResources)
        .setFailureType(to: TheErrorLegacy.self)
        .eraseToAnyPublisher()
    )
    features.use(accountDatabase)
    features.use(networkClient)

    let feature: Resources = testInstance()

    let filterSubject: CurrentValueSubject<ResourcesFilter, Never> = .init(testFilter)

    var result: Array<ListViewResource>?
    feature
      .filteredResourcesListPublisher(filterSubject.eraseToAnyPublisher())
      .sink { resources in
        result = resources
      }
      .store(in: cancellables)

    XCTAssertEqual(result, testResources)
  }

  func test_filteredResourcesListPublisher_usesFilterWhenAccessingDatabase() {
    features.use(accountSession)
    var result: ResourcesFilter?
    accountDatabase.fetchListViewResources.execute = { filter in
      result = filter
      return Just(testResources)
        .setFailureType(to: TheErrorLegacy.self)
        .eraseToAnyPublisher()
    }
    features.use(accountDatabase)
    features.use(networkClient)

    let feature: Resources = testInstance()

    let filterSubject: CurrentValueSubject<ResourcesFilter, Never> = .init(testFilter)

    feature
      .filteredResourcesListPublisher(filterSubject.eraseToAnyPublisher())
      .sinkDrop()
      .store(in: cancellables)

    XCTAssertEqual(result, testFilter)
  }

  func test_filteredResourcesListPublisher_updatesData_whenFilterChanges() {
    features.use(accountSession)
    var resources: Array<ListViewResource> = testResources
    accountDatabase.fetchListViewResources.execute = always(
      Just(resources)
        .setFailureType(to: TheErrorLegacy.self)
        .eraseToAnyPublisher()
    )
    features.use(accountDatabase)
    features.use(networkClient)

    let feature: Resources = testInstance()

    let filterSubject: CurrentValueSubject<ResourcesFilter, Never> = .init(testFilter)

    var result: Array<ListViewResource>?
    feature
      .filteredResourcesListPublisher(filterSubject.eraseToAnyPublisher())
      .sink { resources in
        result = resources
      }
      .store(in: cancellables)

    resources = testResourcesAlternative

    filterSubject.send(.init())

    XCTAssertEqual(result, testResourcesAlternative)
  }

  func test_filteredResourcesListPublisher_publishesResourcesAfterUpdate() {
    features.use(accountSession)
    var resources: Array<ListViewResource> = testResources
    accountDatabase.fetchListViewResources.execute = always(
      Just(resources)
        .setFailureType(to: TheErrorLegacy.self)
        .eraseToAnyPublisher()
    )
    features.use(accountDatabase)
    features.use(networkClient)

    let feature: Resources = testInstance()

    let filterSubject: CurrentValueSubject<ResourcesFilter, Never> = .init(testFilter)

    var result: Array<ListViewResource>?
    feature
      .filteredResourcesListPublisher(filterSubject.eraseToAnyPublisher())
      .sink { resources in
        result = resources
      }
      .store(in: cancellables)

    resources = testResourcesAlternative

    feature
      .refreshIfNeeded()
      .sinkDrop()
      .store(in: cancellables)

    XCTAssertEqual(result, testResourcesAlternative)
  }

  func test_filteredResourcesListPublisher_publishesEmptyList_onDatabaseError() {
    features.use(accountSession)
    accountDatabase.fetchListViewResources.execute = always(
      Fail<Array<ListViewResource>, TheErrorLegacy>(error: .testError())
        .eraseToAnyPublisher()
    )
    features.use(accountDatabase)
    features.use(networkClient)

    let feature: Resources = testInstance()

    let filterSubject: CurrentValueSubject<ResourcesFilter, Never> = .init(testFilter)

    var result: Array<ListViewResource>?
    feature
      .filteredResourcesListPublisher(filterSubject.eraseToAnyPublisher())
      .sink { resources in
        result = resources
      }
      .store(in: cancellables)

    XCTAssertEqual(result, [])
  }
}

private let validAccount: Account = .init(
  localID: .init(rawValue: UUID.test.uuidString),
  domain: "https://passbolt.dev",
  userID: "USER_ID",
  fingerprint: "FINGERPRINT"
)

private let testFilter: ResourcesFilter = .init(
  text: "test",
  name: "test",
  url: "test"
)

private let testResources: Array<ListViewResource> = [
  .init(
    id: .init(rawValue: "test"),
    permission: .read,
    name: "test",
    url: "test",
    username: "test"
  )
]

private let testResourcesAlternative: Array<ListViewResource> = [
  .init(
    id: .init(rawValue: "test"),
    permission: .read,
    name: "test",
    url: "test",
    username: "test"
  ),
  .init(
    id: .init(rawValue: "testAlt"),
    permission: .write,
    name: "testAlt",
    url: "testAlt",
    username: "testAlt"
  ),
]
