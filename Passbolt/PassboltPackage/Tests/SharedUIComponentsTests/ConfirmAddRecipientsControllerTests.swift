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
import Commons
import FeatureScopes
import TestExtensions
import Users
import XCTest

@testable import Display
@testable import SharedUIComponents

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverForceUnwrap
final class ConfirmAddRecipientsControllerTests: FeaturesTestCase {

  /// Query text each database lookup was made with, in order - the first being the fill on open.
  private let queries: CriticalState<Array<String>> = .init(.init())
  /// What the database answers with. Changed mid-test to make a query find nothing.
  private let matches: CriticalState<Array<UserDetailsDSV>> = .init([.mock_1])

  override func commonPrepare() async throws {
    try await super.commonPrepare()

    set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_default
      )
    )
    patch(
      \UserGroups.filteredUserGroups,
      with: { (_: UserGroupsFilter) in .init() }
    )
    patch(
      \Users.userAvatarImage,
      with: always(Data?.none)
    )
    patch(
      \NavigationToConfirmAddRecipients.mockRevert,
      with: always(Void())
    )
  }

  private func tested(
    excludedUsers: Set<User.ID> = .init()
  ) throws -> ConfirmAddRecipientsController {
    try self.testedInstance(
      context: .init(
        excludedUsers: excludedUsers,
        excludedGroups: .init(),
        onSelect: { (_: Array<User.ID>, _: Array<UserGroup.ID>) in }
      )
    )
  }

  /// Records the query and fulfils the expectation standing for that lookup, so a test waits on the search task
  /// reaching the database rather than on a delay.
  private func recordQueries(
    fulfilling expectations: Array<XCTestExpectation>
  ) {
    patch(
      \Users.filteredUsers,
      with: { (filter: UsersFilter) in
        self.queries.access { (recorded: inout Array<String>) in recorded.append(filter.text) }
        let index: Int = self.queries.get().count - 1
        if expectations.indices.contains(index) {
          expectations[index].fulfill()
        }
        return self.matches.get()
      }
    )
  }

  /// The list is filled on open, so the operator sees who they can pick before typing anything.
  func test_init_fillsTheListWithoutAQuery() async throws {
    let opened: XCTestExpectation = .init(description: "the list is filled on open")
    self.recordQueries(fulfilling: [opened])

    let tested: ConfirmAddRecipientsController = try self.tested()

    await fulfillment(of: [opened], timeout: 1.0)
    let users: Array<UserDetailsDSV> = await tested.viewState.current.users
    XCTAssertEqual(users, [.mock_1])
    XCTAssertEqual(self.queries.get(), [""], "Opening the screen asks for everything")
  }

  /// Emptying the field is a reset: it reaches the database again and the full list comes back.
  func test_updateSearchText_whenEmptied_queriesAgainAndRestoresTheList() async throws {
    let opened: XCTestExpectation = .init(description: "the list is filled on open")
    let searched: XCTestExpectation = .init(description: "the typed query reaches the database")
    let cleared: XCTestExpectation = .init(description: "the emptied field queries again")
    self.recordQueries(fulfilling: [opened, searched, cleared])

    let tested: ConfirmAddRecipientsController = try self.tested()
    await fulfillment(of: [opened], timeout: 1.0)

    // A query nobody matches - the screen shows its empty state.
    self.matches.set(.init())
    tested.updateSearchText("nobody")
    await fulfillment(of: [searched], timeout: 1.0)
    let afterSearch: Array<UserDetailsDSV> = await tested.viewState.current.users
    XCTAssertTrue(afterSearch.isEmpty, "Nothing matched, so the list is empty")

    self.matches.set([.mock_1])
    tested.updateSearchText("")

    await fulfillment(of: [cleared], timeout: 1.0)
    let afterClearing: Array<UserDetailsDSV> = await tested.viewState.current.users
    XCTAssertEqual(afterClearing, [.mock_1], "The full list is back")
    XCTAssertEqual(self.queries.get(), ["", "nobody", ""], "The emptied field asked the database again")
  }

  /// The field's text tracks what was typed even while the query behind it is still in flight - the list is
  /// built from it, so it cannot lag.
  func test_updateSearchText_reportsTheTypedText() async throws {
    let opened: XCTestExpectation = .init(description: "the list is filled on open")
    self.recordQueries(fulfilling: [opened])
    let tested: ConfirmAddRecipientsController = try self.tested()
    await fulfillment(of: [opened], timeout: 1.0)

    tested.updateSearchText("betty")

    let searchText: String = await tested.viewState.current.searchText
    XCTAssertEqual(searchText, "betty")
  }

  /// Recipients already on the confirmation screen are not offered a second time.
  func test_search_excludesRecipientsAlreadyHoldingAccess() async throws {
    let opened: XCTestExpectation = .init(description: "the list is filled on open")
    self.recordQueries(fulfilling: [opened])

    let tested: ConfirmAddRecipientsController = try self.tested(excludedUsers: [.mock_1])

    await fulfillment(of: [opened], timeout: 1.0)
    let users: Array<UserDetailsDSV> = await tested.viewState.current.users
    XCTAssertTrue(users.isEmpty, "The only match already holds access")
  }
}
