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
import NetworkClient
import Resources
import TestExtensions
import UIComponents
import XCTest

@testable import PassboltApp

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
@MainActor
final class FoldersExplorerControllerTests: MainActorTestCase {

  override func mainActorSetUp() {
    features.usePlaceholder(for: Resources.self)
    features.patch(
      \Resources.refreshIfNeeded,
      with: always(
        Just(Void())
          .setFailureType(to: TheErrorLegacy.self)
          .eraseToAnyPublisher()
      )
    )
    features.usePlaceholder(for: Folders.self)
    features.patch(
      \Folders.filteredFolderContent,
      with: always(
        AnyAsyncSequence([])
      )
    )
    features.usePlaceholder(for: HomePresentation.self)
    features.usePlaceholder(for: AccountSettings.self)
    features
      .patch(
        \AccountSettings.currentAccountAvatarPublisher,
        with: always(
          Just(nil)
            .eraseToAnyPublisher()
        )
      )
  }

  func test_refreshIfNeeded_setsViewStateError_whenRefreshFails() async {
    features.patch(
      \Resources.refreshIfNeeded,
      with: always(
        Fail(error: MockIssue.error().asLegacy)
          .eraseToAnyPublisher()
      )
    )

    let controller: FoldersExplorerController = testController(
      context: .ignored(with: nil)
    )

    await controller.refreshIfNeeded()

    XCTAssertNotNil(controller.viewState.value.snackBarMessage)
  }

  func test_refreshIfNeeded_finishesWithoutError_whenRefreshingSucceeds() async {

    let controller: FoldersExplorerController = testController(
      context: .ignored(with: nil)
    )

    await controller.refreshIfNeeded()

    XCTAssertNil(controller.viewState.value.snackBarMessage)
  }

  func test_initally_viewStateTitle_isDefaultString_forRootFolder() async {
    let controller: FoldersExplorerController = testController(
      context: .ignored(with: nil)
    )

    XCTAssertEqual(
      controller.viewState.value.title,
      .localized(key: "home.presentation.mode.folders.explorer.title")
    )
  }

  func test_initally_viewStateTitle_isFolderName_forNonRootFolder() async {
    let controller: FoldersExplorerController = testController(
      context: .ignored(
        with: .init(
          id: "folder",
          name: "folder",
          permission: .owner,
          parentFolderID: nil,
          contentCount: 0
        )
      )
    )

    XCTAssertEqual(
      controller.viewState.value.title,
      "folder"
    )
  }
}