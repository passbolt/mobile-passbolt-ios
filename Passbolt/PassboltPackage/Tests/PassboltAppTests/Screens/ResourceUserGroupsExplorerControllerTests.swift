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
import Users
import XCTest

@testable import PassboltApp

internal final class ResourceUserGroupsExplorerControllerTests: FeaturesTestCase {

  override func commonPrepare() async throws {
    try await super.commonPrepare()
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
  }

  func test_refreshIfNeeded_showsError_whenRefreshFails() async throws {
    patch(
      \SessionData.refreshIfNeeded,
      with: alwaysThrow(MockIssue.error())
    )

    let messagesSubscription = SnackBarMessageEvent.subscribe()

    let controller: ResourceUserGroupsExplorerViewContorller = try testedInstance(
      context: nil
    )

    await controller.refreshIfNeeded()

    let message: SnackBarMessageEvent.Payload? = try await messagesSubscription.nextEvent()

    XCTAssertNotNil(message)
  }

  func test_initally_viewStateTitle_isDefaultString_forGroups() async throws {
    patch(
      \SessionData.lastUpdate,
      with: Variable(initial: 0).asAnyUpdatable()
    )
    patch(
      \UserGroups.filteredResourceUserGroups,
      with: always([])
    )
    let controller: ResourceUserGroupsExplorerViewContorller = try testedInstance(
      context: nil
    )

    let viewState: ResourceUserGroupsExplorerViewContorller.ViewState = await controller.viewState.current

    XCTAssertEqual(
      viewState.title,
      .localized(key: "home.presentation.mode.resource.user.groups.explorer.title")
    )
  }

  func test_initally_viewStateTitle_isGroupName_forGroup() async throws {
    patch(
      \ResourcesController.filteredResourcesList,
      with: always([])
    )

    patch(
      \ResourcesController.lastUpdate,
      with: Variable(initial: 0).asAnyUpdatable()
    )

    let controller: ResourceUserGroupsExplorerViewContorller = try testedInstance(
      context: .init(
        id: .mock_1,
        name: "group",
        contentCount: 0
      )
    )

    let viewState: ResourceUserGroupsExplorerViewContorller.ViewState = await controller.viewState.current

    XCTAssertEqual(
      viewState.title,
      .raw("group")
    )
  }
}
