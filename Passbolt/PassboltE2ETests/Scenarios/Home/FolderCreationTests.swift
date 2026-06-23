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

@MainActor
final internal class FolderCreationTests: UITestCase {

  /// https://passbolt.testrail.io/index.php?/cases/view/17611
  func test_onTheFoldersWorkspaceICanClickCreateButtonWhenV5ResourcesAreEnabledAndDefault() async throws {
    await executeSteps {
      SelectFoldersFilter()
      On(FoldersScreen.self) { folders in
        Verify(folders.createButton.exists, "Create button exists")
        Tap(folders.createButton, "Create button")
      }
      On(FolderCreateMenuScreen.self) { menu in
        Verify(menu.addFolderButton.exists, "Add folder button exists")
        Verify(menu.addPasswordButton.exists, "Add password button exists")
        Verify(menu.addTOTPButton.exists, "Add TOTP button exists")
        Verify(menu.addNoteButton.exists, "Add note button exists")
        Verify(menu.PINCodeButton.exists, "Add pin code button exists")
        Verify(menu.closeButton.exists, "Close button exists")
      }
    }
  }

  /// https://passbolt.testrail.io/index.php?/cases/view/8162
  func test_onTheFolderWorkspaceICanCancelCreationProcess() async throws {
    await executeSteps {
      SelectFoldersFilter()
      On(FoldersScreen.self) { folders in
        Tap(folders.createButton, "Create button")
      }
      On(FolderCreateMenuScreen.self) { menu in
        Tap(menu.closeButton, "Close")
      }
      On(FoldersScreen.self) { folders in
        Verify(folders.createButton.exists, "Back on folders workspace")
      }
    }
  }

  /// https://passbolt.testrail.io/index.php?/cases/view/8163
  func test_onTheFolderWorkspaceICanClickAddFolderAndOpenCreateFolderWorkspace() async throws {
    await executeSteps {
      SelectFoldersFilter()
      On(FoldersScreen.self, timeout: .networkCall) { folders in
        Tap(folders.createButton, "Create button")
      }
      On(FolderCreateMenuScreen.self) { menu in
        Tap(menu.addFolderButton, "Add folder")
      }
      On(FolderEditScreen.self, timeout: .networkCall) { edit in
        Verify(edit.backButton.exists, "Back button exists")
        Verify(edit.nameLabel.exists, "Name label exists")
        Verify(edit.locationLabel.exists, "Location label exists")
        Verify(edit.sharedWithLabel.exists, "Shared with label exists")
        Verify(edit.saveButton.exists, "Save button exists")
      }
    }
  }

  /// https://passbolt.testrail.io/index.php?/cases/view/8164
  func test_onTheRootFolderWorkspaceIWillSeeAnErrorWhenSavingFolderWithoutItsName() async throws {
    await executeSteps {
      SelectFoldersFilter()
      On(FoldersScreen.self) { folders in
        Tap(folders.createButton, "Create button")
      }
      On(FolderCreateMenuScreen.self) { menu in
        Tap(menu.addFolderButton, "Add folder")
      }
      On(FolderEditScreen.self, timeout: .longNetworkCall) { edit in
        WaitFor(edit.saveButton, timeout: .networkCall, "Save button loaded")
        Tap(edit.saveButton, "Save without name")
        Verify(edit.errorLabel.exists, "Error label shown")
      }
    }
  }

  /// https://passbolt.testrail.io/index.php?/cases/view/8165
  func test_onTheRootFolderWorkspaceICanSaveNewFolder() async throws {
    await executeSteps {
      SelectFoldersFilter()
      On(FoldersScreen.self) { folders in
        Tap(folders.createButton, "Create button")
      }
      On(FolderCreateMenuScreen.self, timeout: .networkCall) { menu in
        Tap(menu.addFolderButton, "Add folder")
      }
      On(FolderEditScreen.self) { edit in
        WaitFor(edit.nameField, timeout: .slowNetworkCall, "Name field loaded")
        TypeText(FolderTestData.automatedTestsFolder.folderName, into: edit.nameField, "Folder name")
          .dismissKeyboardIfNeeded()
        Tap(edit.saveButton, "Save folder")
      }
      On(HomeListScreen.self, timeout: .longNetworkCall) { home in
        WaitForRefreshToComplete(home.list)
      }
      On(FoldersScreen.self, timeout: .longNetworkCall) { folders in
        Verify(folders.createButton.exists, "Redirected to folders workspace")
      }
    }
  }

  /// https://passbolt.testrail.io/index.php?/cases/view/8166
  func test_onTheFolderWorkspaceICanOpenFolder() async throws {
    let application: XCUIApplication = await self.application
    UITestFlow(application: application) {
      SelectFoldersFilter()
      On(FoldersScreen.self) { folders in
        TypeText(FolderTestData.emptyFolder.folderName, into: folders.searchField)
        WaitFor(
          application.buttons.containing(
            .init(format: "identifier == %@", "folder_contents_folder_" + FolderTestData.emptyFolder.folderDescription)
          ).element,
          timeout: .networkCall
        )
        Tap(
          application.buttons.containing(
            .init(format: "identifier == %@", "folder_contents_folder_" + FolderTestData.emptyFolder.folderDescription)
          ).element
        )
      }
      On(FolderContentScreen.self) { content in
        Verify(content.backButton.exists)
        Verify(content.folderIcon.exists)
        Verify(content.filterButton.exists)
        Verify(content.searchField.exists)
        Verify(content.noResultsText.exists)
        Verify(content.createButton.exists)
      }
    }
    .run()
  }
}
