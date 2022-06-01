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
import CommonModels
import Features
import Resources
import TestExtensions
import UIComponents
import Users
import XCTest

@testable import PassboltApp

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
@MainActor
final class ResourcePermissionListControllerTests: MainActorTestCase {

  func test_loading_succeedsWithPermissionList_whenDatabaseFetchSucceeds() async throws {
    await features.usePlaceholder(for: Users.self)
    await features.patch(
      \ResourceUserPermissionsDetailsFetch.execute,
      with: always(.random(countIn: 1..<5))
    )
    await features.patch(
      \ResourceUserGroupPermissionsDetailsFetch.execute,
      with: always(.random(countIn: 1..<5))
    )

    let controller: ResourcePermissionListController = try await testController(
      context: .ignored(
        with: .randomGenerator(
          using: .sharedDebugRandomSource
        )
        .next()
      )
    )

    XCTAssertFalse(controller.viewState.permissionListItems.isEmpty)
    XCTAssertNil(controller.viewState.snackBarMessage)
  }

  func test_loading_succeedsWithErrorMessage_whenDatabaseFetchFails() async throws {
    await features.usePlaceholder(for: Users.self)
    await features.patch(
      \ResourceUserPermissionsDetailsFetch.execute,
      with: alwaysThrow(MockIssue.error())
    )
    await features.patch(
      \ResourceUserGroupPermissionsDetailsFetch.execute,
      with: alwaysThrow(MockIssue.error())
    )

    let controller: ResourcePermissionListController = try await testController(
      context: .ignored(
        with: .randomGenerator(
          using: .sharedDebugRandomSource
        )
        .next()
      )
    )

    XCTAssertTrue(controller.viewState.permissionListItems.isEmpty)
    XCTAssertNotNil(controller.viewState.snackBarMessage)
  }
}
