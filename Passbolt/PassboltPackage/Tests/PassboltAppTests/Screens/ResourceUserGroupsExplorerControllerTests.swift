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

import Accounts
import Combine
import FeatureScopes
import Features
import Resources
import SessionData
import TestExtensions
import UIComponents
import Users
import XCTest

@testable import PassboltApp

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
@available(iOS 16.0.0, *)
@MainActor
final class ResourceUserGroupsExplorerControllerTests: MainActorTestCase {

  var updates: Variable<Timestamp>!

  override func mainActorSetUp() {
    features
      .set(
        SessionScope.self,
        context: .init(
          account: .mock_ada,
          configuration: .mock_1
        )
      )
    updates = .init(initial: 0)
    features.patch(
      \SessionData.lastUpdate,
      with: updates.asAnyUpdatable()
    )
    features.patch(
      \SessionData.refreshIfNeeded,
      with: always(Void())
    )
    features.patch(
      \UserGroups.filteredResourceUserGroupList,
      with: always(
        AnyAsyncSequence([])
      )
    )
    features.patch(
      \Session.currentAccount,
      with: always(Account.mock_ada)
    )
    features.patch(
      \AccountDetails.profile,
      with: always(AccountWithProfile.mock_ada)
    )
    features.patch(
      \AccountDetails.avatarImage,
      with: always(.init())
    )
  }

  override func mainActorTearDown() {
    updates = .init(initial: 0)
  }

  func test_refreshIfNeeded_showsError_whenRefreshFails() async throws {
    features.patch(
      \SessionData.refreshIfNeeded,
      with: alwaysThrow(MockIssue.error())
    )

    let messagesSubscription = SnackBarMessageEvent.subscribe()

    let controller: ResourceUserGroupsExplorerController = try testController(
      context: nil
    )

    await controller.refreshIfNeeded()

    let message: SnackBarMessageEvent.Payload? = try await messagesSubscription.nextEvent()

    XCTAssertNotNil(message)
  }

  func test_refreshIfNeeded_finishesWithoutError_whenRefreshingSucceeds() async throws {

    let controller: ResourceUserGroupsExplorerController = try await testController(
      context: nil
    )

    await controller.refreshIfNeeded()

    // can't check if succeeded now...
  }

  func test_initally_viewStateTitle_isDefaultString_forTags() async throws {
    let controller: ResourceUserGroupsExplorerController = try await testController(
      context: nil
    )

    XCTAssertEqual(
      controller.viewState.value.title,
      .localized(key: "home.presentation.mode.resource.user.groups.explorer.title")
    )
  }

  func test_initally_viewStateTitle_isTagSlug_forNonRootFolder() async throws {
    features.patch(
      \ResourcesController.filteredResourcesList,
      with: always([])
    )
    features.patch(
      \ResourcesController.lastUpdate,
      with: Variable(initial: 0).asAnyUpdatable()
    )

    let controller: ResourceUserGroupsExplorerController = try await testController(
      context: .init(
        id: .mock_1,
        name: "group",
        contentCount: 0
      )
    )

    XCTAssertEqual(
      controller.viewState.value.title,
      .raw("group")
    )
  }
}
