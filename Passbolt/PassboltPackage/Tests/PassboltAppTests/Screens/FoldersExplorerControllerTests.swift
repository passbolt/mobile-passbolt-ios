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
import XCTest

@testable import PassboltApp

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
@MainActor
final class FoldersExplorerControllerTests: MainActorTestCase {

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
    features.usePlaceholder(for: ResourceFolders.self)
    features.usePlaceholder(for: HomePresentation.self)
  }

  override func mainActorTearDown() {
    updates = .none
  }

  override func featuresActorSetUp() async throws {
    try await super.featuresActorSetUp()
    features
      .set(
        SessionScope.self,
        context: .init(
          account: .mock_ada,
          configuration: .mock_1
        )
      )
    features.patch(
      \ResourceFolders.filteredFolderContent,
      with: always(
        .init(
          folderID: .none,
          flattened: false,
          subfolders: [],
          resources: []
        )
      )
    )
    features
      .patch(
        \Session.currentAccount,
        with: always(Account.mock_ada)
      )
    features
      .patch(
        \AccountDetails.avatarImage,
        context: Account.mock_ada,
        with: always(.init())
      )
  }

  func test_refreshIfNeeded_setsViewStateError_whenRefreshFails() async throws {
    features.patch(
      \SessionData.refreshIfNeeded,
      with: alwaysThrow(MockIssue.error())
    )

    let controller: FoldersExplorerController = try testController(
      context: nil
    )

    await controller.refreshIfNeeded()

    XCTAssertNotNil(controller.viewState.value.snackBarMessage)
  }

  func test_refreshIfNeeded_finishesWithoutError_whenRefreshingSucceeds() async throws {

    let controller: FoldersExplorerController = try testController(
      context: nil
    )

    await controller.refreshIfNeeded()

    XCTAssertNil(controller.viewState.value.snackBarMessage)
  }

  func test_initally_viewStateTitle_isDefaultString_forRootFolder() async throws {
    let controller: FoldersExplorerController = try testController(
      context: nil
    )

    XCTAssertEqual(
      controller.viewState.value.title,
      .localized(key: "home.presentation.mode.folders.explorer.title")
    )
  }

  func test_initally_viewStateTitle_isFolderName_forNonRootFolder() async throws {
    let controller: FoldersExplorerController = try testController(
      context: .init(
        id: "folder",
        name: "folder",
        permission: .owner,
        shared: false,
        parentFolderID: nil,
        location: "mockLocation",
        contentCount: 0
      )
    )

    XCTAssertEqual(
      controller.viewState.value.title,
      .raw("folder")
    )
  }
}
