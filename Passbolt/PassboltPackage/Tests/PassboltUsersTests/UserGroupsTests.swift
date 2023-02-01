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

import Features
import SessionData
import TestExtensions

@testable import PassboltUsers

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class UserGroupsTests: LoadableFeatureTestCase<UserGroups> {

  override class var testedImplementationScope: any FeaturesScope.Type { SessionScope.self }

  override class func testedImplementationRegister(
    _ registry: inout FeaturesRegistry
  ) {
    registry.usePassboltUserGroups()
  }

  var updatesSequence: UpdatesSequenceSource!

  override func prepare() throws {
    self.set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_1
      )
    )
    self.updatesSequence = .init()
    patch(
      \SessionData.updatesSequence,
      with: updatesSequence.updatesSequence
    )
    use(Session.placeholder)
    use(ResourceUserGroupsListFetchDatabaseOperation.placeholder)
    use(UserGroupDetailsFetchDatabaseOperation.placeholder)
    use(UserGroupsListFetchDatabaseOperation.placeholder)
  }

  override func cleanup() throws {
    self.updatesSequence = .none
  }

  func test_filteredUserGroups_producesEmptyList_whenDatabaseFetchingFail() async throws {
    patch(
      \Session.currentAccount,
      with: always(.mock_ada)
    )
    patch(
      \ResourceUserGroupsListFetchDatabaseOperation.execute,
      with: alwaysThrow(MockIssue.error())
    )

    let filtersSequence: AsyncVariable<String> = .init(initial: "filter")

    let feature: UserGroups = try await self.testedInstance()

    let result: Array<ResourceUserGroupListItemDSV>? =
      await feature.filteredResourceUserGroupList(filtersSequence.asAnyAsyncSequence())
      .first()

    XCTAssertEqual(
      result,
      []
    )
  }

  func test_filteredUserGroups_producesNonEmptyList_whenDatabaseFetchingSucceeds() async throws {
    patch(
      \Session.currentAccount,
      with: always(.mock_ada)
    )
    let expectedResult: Array<ResourceUserGroupListItemDSV> = [
      .init(
        id: .mock_1,
        name: "mock_1",
        contentCount: 1
      )
    ]
    patch(
      \ResourceUserGroupsListFetchDatabaseOperation.execute,
      with: always(expectedResult)
    )

    let filtersSequence: AsyncVariable<String> = .init(initial: "filter")

    let feature: UserGroups = try await self.testedInstance()

    let result: Array<ResourceUserGroupListItemDSV>? =
      await feature.filteredResourceUserGroupList(filtersSequence.asAnyAsyncSequence())
      .first()

    XCTAssertEqual(
      result,
      expectedResult
    )
  }

  func test_filteredUserGroups_producesUpdatedList_whenFiltersChange() async throws {
    patch(
      \Session.currentAccount,
      with: always(.mock_ada)
    )
    var expectedResult: Array<ResourceUserGroupListItemDSV> = []
    let filtersSequence: AsyncVariable<String> = .init(initial: "filter")

    let nextResult: () -> Array<ResourceUserGroupListItemDSV> = {
      defer {
        if expectedResult.isEmpty {
          expectedResult.append(
            .init(
              id: "id",
              name: "name",
              contentCount: 0
            )
          )
        }
        else { /* NOP */
        }
      }
      return expectedResult
    }
    patch(
      \ResourceUserGroupsListFetchDatabaseOperation.execute,
      with: always(nextResult())
    )

    let feature: UserGroups = try await self.testedInstance()

    _ = await feature.filteredResourceUserGroupList(filtersSequence.asAnyAsyncSequence())
      .first()

    filtersSequence.send("changed")

    let result: Array<ResourceUserGroupListItemDSV>? =
      await feature.filteredResourceUserGroupList(filtersSequence.asAnyAsyncSequence())
      .first()

    XCTAssertEqual(
      result,
      expectedResult
    )
  }

  func test_groupMembers_fails_whenLoadingDetailsFails() async throws {
    patch(
      \UserGroupDetails.details,
      context: "groupID",
      with: alwaysThrow(MockIssue.error())
    )

    let feature: UserGroups = try await self.testedInstance()

    await XCTAssertError(
      matches: MockIssue.self
    ) {
      try await feature.groupMembers("groupID")
    }
  }

  func test_groupMembers_fails_whenDetailsAccessFails() async throws {
    patch(
      \UserGroupDetails.details,
      context: "groupID",
      with: alwaysThrow(MockIssue.error())
    )
    let feature: UserGroups = try await self.testedInstance()

    await XCTAssertError(
      matches: MockIssue.self
    ) {
      try await feature.groupMembers("groupID")
    }
  }

  func test_groupMembers_returnsList_whenDetailsAccessSucceeds() async throws {
    let expectedResult: OrderedSet<UserDetailsDSV> = [.mock_1]
    patch(
      \UserGroupDetails.details,
      context: "groupID",
      with: always(
        .init(
          id: "groupID",
          name: "group",
          members: expectedResult
        )
      )
    )

    let feature: UserGroups = try await self.testedInstance()

    await XCTAssertValue(
      equal: expectedResult
    ) {
      try await feature.groupMembers("groupID")
    }
  }
}
