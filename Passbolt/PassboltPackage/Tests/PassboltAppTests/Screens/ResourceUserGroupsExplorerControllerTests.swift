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
import Features
import Resources
import SessionData
import TestExtensions
import UIComponents
import Users
import XCTest

@testable import PassboltApp

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
@MainActor
final class ResourceUserGroupsExplorerControllerTests: MainActorTestCase {

  var updates: UpdatesSequenceSource!

  override func mainActorSetUp() {
    updates = .init()
    features.patch(
      \SessionData.updatesSequence,
      with: updates.updatesSequence
    )
    features.patch(
      \SessionData.refreshIfNeeded,
      with: always(Void())
    )
    features.usePlaceholder(for: Resources.self)
    features.patch(
      \UserGroups.filteredResourceUserGroupList,
      with: always(
        AnyAsyncSequence([])
      )
    )
    features.usePlaceholder(for: HomePresentation.self)
    features.patch(
      \Session.currentAccount,
      with: always(Account.valid)
    )
    features.patch(
      \AccountDetails.profile,
      context: Account.valid,
      with: always(AccountWithProfile.valid)
    )
    features.patch(
      \AccountDetails.avatarImage,
      context: Account.valid,
      with: always(.init())
    )
  }

  override func mainActorTearDown() {
    updates = .init()
  }

  func test_refreshIfNeeded_setsViewStateError_whenRefreshFails() async throws {
    features.patch(
      \SessionData.refreshIfNeeded,
      with: alwaysThrow(MockIssue.error())
    )

    let controller: ResourceUserGroupsExplorerController = try await testController(
      context: .ignored(with: nil)
    )

    await controller.refreshIfNeeded()

    XCTAssertNotNil(controller.viewState.value.snackBarMessage)
  }

  func test_refreshIfNeeded_finishesWithoutError_whenRefreshingSucceeds() async throws {

    let controller: ResourceUserGroupsExplorerController = try await testController(
      context: .ignored(with: nil)
    )

    await controller.refreshIfNeeded()

    XCTAssertNil(controller.viewState.value.snackBarMessage)
  }

  func test_initally_viewStateTitle_isDefaultString_forTags() async throws {
    let controller: ResourceUserGroupsExplorerController = try await testController(
      context: .ignored(with: nil)
    )

    XCTAssertEqual(
      controller.viewState.value.title,
      .localized(key: "home.presentation.mode.resource.user.groups.explorer.title")
    )
  }

  func test_initally_viewStateTitle_isTagSlug_forNonRootFolder() async throws {
    features.patch(
      \Resources.filteredResourcesListPublisher,
      with: always(
        Just([])
          .eraseToAnyPublisher()
      )
    )

    let controller: ResourceUserGroupsExplorerController = try await testController(
      context: .ignored(
        with: .init(
          id: "groupID",
          name: "group",
          contentCount: 0
        )
      )
    )

    XCTAssertEqual(
      controller.viewState.value.title,
      "group"
    )
  }
}
