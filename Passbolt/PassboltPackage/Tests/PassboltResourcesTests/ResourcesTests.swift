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

import SessionData
import TestExtensions
import XCTest

@testable import Accounts
@testable import PassboltResources

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class ResourcesTests: LoadableFeatureTestCase<Resources> {

  override class var testedImplementationRegister: (FeatureFactory) -> @MainActor () -> Void {
    FeatureFactory.usePassboltResources
  }

  var updatesSequence: UpdatesSequenceSource!

  override func prepare() throws {
    updatesSequence = .init()
    patch(
      \Session.currentAccount,
      with: always(.mock_ada)
    )
    patch(
      \ResourcesStoreDatabaseOperation.execute,
      with: always(Void())
    )
    patch(
      \ResourceTypesStoreDatabaseOperation.execute,
      with: always(Void())
    )
    patch(
      \ResourcesFetchNetworkOperation.execute,
      with: always([])
    )
    patch(
      \ResourceTypesFetchNetworkOperation.execute,
      with: always([])
    )
    use(ResourcesListFetchDatabaseOperation.placeholder)
    use(ResourceDeleteNetworkOperation.placeholder)
    use(ResourceSecretFetchNetworkOperation.placeholder)
    use(ResourceFolders.placeholder)
    use(ResourceTags.placeholder)
    use(UserGroups.placeholder)
    patch(
      environment: \.time.timestamp,
      with: always(100)
    )
    patch(
      \SessionData.updatesSequence,
      with: self.updatesSequence.updatesSequence
    )
    patch(
      \SessionData.refreshIfNeeded,
      with: always(Void())
    )
  }

  override func cleanup() throws {
    updatesSequence = .none
  }

  func test_loading_refreshesData() async throws {
    var result: Void?
    let uncheckedSendableResult: UncheckedSendable<Void?> = .init(
      get: { result },
      set: { result = $0 }
    )
    patch(
      \SessionData.refreshIfNeeded,
      with: { () async throws in
        uncheckedSendableResult.variable = Void()
      }
    )

    let _: Resources = try await testedInstance()

    // wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    XCTAssertNotNil(result)
  }

  func test_filteredResourcesListPublisher_publishesResourcesFromDatabase() async throws {
    patch(
      \ResourcesListFetchDatabaseOperation.execute,
      with: always(.testResources)
    )

    let feature: Resources = try await testedInstance()

    let filterSubject: CurrentValueSubject<ResourcesFilter, Never> = .init(testFilter)

    let result: Array<ResourceListItemDSV>? =
      try await feature
      .filteredResourcesListPublisher(filterSubject.eraseToAnyPublisher())
      .asAsyncValue()

    XCTAssertEqual(result, .testResources)
  }

  func test_filteredResourcesListPublisher_usesFilterWhenAccessingDatabase() async throws {
    var result: ResourcesDatabaseFilter?
    let uncheckedSendableResult: UncheckedSendable<ResourcesDatabaseFilter?> = .init(
      get: { result },
      set: { result = $0 }
    )
    patch(
      \ResourcesListFetchDatabaseOperation.execute,
      with: { (input) async throws in
        uncheckedSendableResult.variable = input
        return .testResources
      }
    )

    let feature: Resources = try await testedInstance()

    let filterSubject: CurrentValueSubject<ResourcesFilter, Never> = .init(testFilter)

    _ =
      try await feature
      .filteredResourcesListPublisher(filterSubject.eraseToAnyPublisher())
      .asAsyncValue()

    XCTAssertEqual(result, testDatabaseFilter)
  }

  func test_filteredResourcesListPublisher_updatesData_whenFilterChanges() async throws {
    var resources: Array<ResourceListItemDSV> = .testResources
    patch(
      \ResourcesListFetchDatabaseOperation.execute,
      with: always(resources)
    )

    let feature: Resources = try await testedInstance()

    let filterSubject: CurrentValueSubject<ResourcesFilter, Never> = .init(testFilter)

    var result: Array<ResourceListItemDSV>? =
      try await feature
      .filteredResourcesListPublisher(filterSubject.eraseToAnyPublisher())
      .asAsyncValue()

    resources = .testResourcesAlternative

    filterSubject.send(.init(sorting: .nameAlphabetically))

    result =
      try await feature
      .filteredResourcesListPublisher(filterSubject.eraseToAnyPublisher())
      .asAsyncValue()

    XCTAssertEqual(result, .testResourcesAlternative)
  }

  func test_filteredResourcesListPublisher_publishesEmptyList_onDatabaseError() async throws {
    patch(
      \ResourcesListFetchDatabaseOperation.execute,
      with: alwaysThrow(MockIssue.error())
    )

    let feature: Resources = try await testedInstance()

    let filterSubject: CurrentValueSubject<ResourcesFilter, Never> = .init(testFilter)

    let result: Array<ResourceListItemDSV>? =
      try? await feature
      .filteredResourcesListPublisher(filterSubject.eraseToAnyPublisher())
      .asAsyncValue()

    XCTAssertEqual(result, [])
  }

  func test_delete_triggersRefreshIfNeeded_whenDeletion_succeeds() async throws {
    var result: Void?
    let uncheckedSendableResult: UncheckedSendable<Void?> = .init(
      get: { result },
      set: { result = $0 }
    )
    patch(
      \SessionData.refreshIfNeeded,
      with: { () async throws in
        uncheckedSendableResult.variable = Void()
      }
    )
    patch(
      \ResourceDeleteNetworkOperation.execute,
      with: always(Void())
    )

    let feature: Resources = try await testedInstance()

    try await feature
      .deleteResource(.init(rawValue: "test"))
      .asAsyncValue()

    XCTAssertNotNil(result)
  }
}

private let testFilter: ResourcesFilter = .init(
  sorting: .nameAlphabetically,
  text: "test"
)

private let testDatabaseFilter: ResourcesDatabaseFilter = .init(
  sorting: .nameAlphabetically,
  text: "test",
  name: "",
  url: ""
)
