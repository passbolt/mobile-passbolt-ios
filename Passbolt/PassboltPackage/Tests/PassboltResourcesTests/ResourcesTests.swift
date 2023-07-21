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

import FeatureScopes
import SessionData
import TestExtensions
import XCTest

@testable import Accounts
@testable import PassboltResources

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
@available(iOS 16.0.0, *)
final class ResourcesControllerTests: FeaturesTestCase {

  let updatesSequence: Variable<Timestamp> = .init(initial: 0)

  override func commonPrepare() {
    super.commonPrepare()
    register(
      { $0.usePassboltResources() },
      for: ResourcesController.self
    )
    set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_1
      )
    )
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
    patch(
      \OSTime.timestamp,
      with: always(100)
    )
    patch(
      \SessionData.lastUpdate,
      with: self.updatesSequence
    )
    patch(
      \SessionData.refreshIfNeeded,
      with: always(Void())
    )
  }

  func test_filteredResourcesList_publishesResourcesFromDatabase() async throws {
    patch(
      \ResourcesListFetchDatabaseOperation.execute,
      with: always(.testResources)
    )

    let feature: ResourcesController = try testedInstance()

    let result: Array<ResourceListItemDSV>? =
      try await feature
      .filteredResourcesList(testFilter)

    XCTAssertEqual(result, .testResources)
  }

  func test_filteredResourcesList_usesFilterWhenAccessingDatabase() async throws {
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

    let feature: ResourcesController = try testedInstance()

    _ = try await feature.filteredResourcesList(testFilter)

    XCTAssertEqual(result, testDatabaseFilter)
  }

  func test_filteredResourcesList_throws_onDatabaseError() async throws {
    patch(
      \ResourcesListFetchDatabaseOperation.execute,
      with: alwaysThrow(MockIssue.error())
    )

    let feature: ResourcesController = try testedInstance()

    await XCTAssertError(
      matches: MockIssue.self
    ) {
      try await feature.filteredResourcesList(testFilter)
    }
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

    let feature: ResourcesController = try testedInstance()

    try await feature.delete(.mock_1)

    XCTAssertNotNil(result)
  }

  func test_delete_refreshesSessionData_whenDeleteSucceeded() async throws {
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

    let feature: ResourcesController = try testedInstance()

    try await feature.delete(.mock_1)

    XCTAssertNotNil(result)
  }

  func test_delete_fails_whenDeleteFails() async throws {
    patch(
      \ResourceDeleteNetworkOperation.execute,
      with: alwaysThrow(MockIssue.error())
    )

    let feature: ResourcesController = try testedInstance()

    do {
      try await feature.delete(.mock_1)
      XCTFail()
    }
    catch {
      // expected
    }
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
  url: "",
  excludedTypeSlugs: []
)
