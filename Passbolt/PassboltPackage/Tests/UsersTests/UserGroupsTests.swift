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
import Features
import NetworkClient
import TestExtensions

@testable import Accounts
@testable import Users

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class UserGroupsTests: TestCase {

  var accountSession: AccountSession!
  var database: AccountDatabase!
  var networkClient: NetworkClient!

  override func featuresActorSetUp() async throws {
    try await super.featuresActorSetUp()
    self.features.usePlaceholder(for: AccountDatabase.self)
    self.features.usePlaceholder(for: NetworkClient.self)
    self.features.usePlaceholder(for: AccountSessionData.self)
    self.features.patch(
      \AccountSessionData.updatesSequence,
      with: always(
        AsyncVariable(initial: Void())
          .asAnyAsyncSequence()
      )
    )
    self.features.usePlaceholder(for: AccountSession.self)
    self.features.patch(
      \AccountSession.currentState,
      with: always(
        .authorized(.validAccount)
      )
    )
    self.features.usePlaceholder(for: UserGroupMembersDatabaseFetch.self)
    features.usePlaceholder(for: UserGroupsListDatabaseFetch.self)
  }

  func test_filteredUserGroups_producesEmptyList_whenDatabaseFetchingFail() async throws {
    await self.features
      .patch(
        \AccountDatabase.fetchResourceUserGroupList,
        with: .failingWith(MockIssue.error())
      )
    let filtersSequence: AsyncVariable<String> = .init(initial: "filter")

    let feature: UserGroups = try await self.testInstance()

    let result: Array<ResourceUserGroupListItemDSV>? =
      await feature.filteredResourceUserGroupList(filtersSequence.asAnyAsyncSequence())
      .first()

    XCTAssertEqual(
      result,
      []
    )
  }

  func test_filteredUserGroups_producesNonEmptyList_whenDatabaseFetchingSucceeds() async throws {
    let expectedResult: Array<ResourceUserGroupListItemDSV> = [
      .init(
        id: "id",
        name: "name",
        contentCount: 0
      )
    ]
    await self.features
      .patch(
        \AccountDatabase.fetchResourceUserGroupList,
        with: .returning(expectedResult)
      )
    let filtersSequence: AsyncVariable<String> = .init(initial: "filter")

    let feature: UserGroups = try await self.testInstance()

    let result: Array<ResourceUserGroupListItemDSV>? =
      await feature.filteredResourceUserGroupList(filtersSequence.asAnyAsyncSequence())
      .first()

    XCTAssertEqual(
      result,
      expectedResult
    )
  }

  func test_filteredUserGroups_producesUpdatedList_whenFiltersChange() async throws {
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
    await self.features
      .patch(
        \AccountDatabase.fetchResourceUserGroupList,
        with: .returning(nextResult())
      )

    let feature: UserGroups = try await self.testInstance()

    _ = await feature.filteredResourceUserGroupList(filtersSequence.asAnyAsyncSequence())
      .first()

    await filtersSequence.send("changed")

    let result: Array<ResourceUserGroupListItemDSV>? =
      await feature.filteredResourceUserGroupList(filtersSequence.asAnyAsyncSequence())
      .first()

    XCTAssertEqual(
      result,
      expectedResult
    )
  }

  func test_groupMembers_fails_whenLoadingDetailsFails() async throws {
    let feature: UserGroups = try await self.testInstance()

    await XCTAssertError(
      matches: FeatureUndefined.self
    ) {
      try await feature.groupMembers("groupID")
    }
  }

  func test_groupMembers_fails_whenDetailsAccessFails() async throws {
    await features
      .patch(
        \UserGroupDetails.details,
        context: "groupID",
        with: alwaysThrow(
          MockIssue.error()
        )
      )
    let feature: UserGroups = try await self.testInstance()

    await XCTAssertError(
      matches: MockIssue.self
    ) {
      try await feature.groupMembers("groupID")
    }
  }

  func test_groupMembers_returnsList_whenDetailsAccessSucceeds() async throws {
    let expectedResult: OrderedSet<UserDetailsDSV> = [.random()]
    await features
      .patch(
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

    let feature: UserGroups = try await self.testInstance()

    await XCTAssertValue(
      equal: expectedResult
    ) {
      try await feature.groupMembers("groupID")
    }
  }
}
