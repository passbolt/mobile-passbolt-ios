//
// Passbolt - Open source password manager for teams
// Copyright (c) 2021, 2024 Passbolt SA
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

import Foundation

final class FolderCreationTests: UITestCase {

  override func beforeEachTestCase() throws {
    //      Given I already have account admin_automated
    //      And I am logged in mobile app
    //      And I want to create new folder
    //      And I am on the folders filter view
    //      And I have the permission to create a folder in my current location
    try signIn()
    try tap("search.view.menu", timeout: 4.0)
    try tap("foldersExplorer")
  }

  /// https://passbolt.testrail.io/index.php?/cases/view/8160
  func test_onTheFoldersWorkspaceICanClickCreateButton() throws {

    //      Given   I am on #PRO_FOLDER_CREATION_WITH_PERMISSION
    //      And     I see a create button with an icon in @blue
    assertExists("folder.explore.create.new")
    //      When    I click create button
    try tap("folder.explore.create.new")
    //      Then    I see a menu with a item ‘Add folder’ with folder icon
    assertExists("resource.folders.add.folder")
    //      And     I see a menu with a item ‘Add password’ with key icon
    assertExists("resource.folders.add.password")
    //      And     I see ‘X’ close button
    assertExists("Close")
  }

  ///   https://passbolt.testrail.io/index.php?/cases/view/8161
  func test_onTheFoldersWorkspaceICanClickAddPasswordAndOpenNewPasswordWorkspace() throws {
    //      Given that I am on #PRO_FOLDER_CREATION_WITH_PERMISSION
    //        And I clicked on the create button
    try tap("folder.explore.create.new")
    //        When    I click ‘Add password’
    try tap("resource.folders.add.password")
    //        Then    I see ‘New password’ workspace
    assertPresentsString(matching: "Password")
  }

  ///   https://passbolt.testrail.io/index.php?/cases/view/8162
  func test_onTheFolderWorkspaceICanCancelCreationProcess() throws {
    //      Given that I am on #PRO_FOLDER_CREATION_WITH_PERMISSION
    //        And I clicked on the create button
    try tap("folder.explore.create.new")
    //        When    I click ‘X’ button
    try tap("Close")
    //        Then    I am on folders workspace
    assertPresentsString(matching: "Folders")
  }

  ///   https://passbolt.testrail.io/index.php?/cases/view/8163
  func test_onTheFolderWorkspaceICanClickAddFolderAndOpenCreateFolderWorkspace() throws {
    //      Given that I am on #PRO_FOLDER_CREATION_WITH_PERMISSION
    //        And I clicked on the create button
    try tap("folder.explore.create.new")
    //        When    I click ‘Add folder’ button
    try tap("resource.folders.add.folder")
    //        Then    I see ‘Create folder’ workspace
    assertPresentsString(matching: "Create folder")
    //        And I see a back arrow to go back to the previous page
    assertExists("Back")
    //        And I see a mandatory input text field with a ‘Name’ label
    assertPresentsString(matching: "Name *")
    //        And I see ‘Location’ label with ‘Root’ information
    assertPresentsString(matching: "Location")
    //        And I see an icon of a user who creates a folder
    assertPresentsString(matching: "Shared with")
    //        And I see ‘Save’ button in @blue
    assertExists("folder.edit.form.button")
  }

  ///   https://passbolt.testrail.io/index.php?/cases/view/8164
  func test_onTheRootFolderWorkspaceIWillSeeAnErrorWhenSavingFolderWithoutItsName() throws {
    //      Given that I am on #PRO_FOLDER_CREATION_WITH_PERMISSION
    //        And I clicked on the create button
    try tap("folder.explore.create.new")
    //        And I clicked on the create folder button
    try tap("resource.folders.add.folder")
    //        When I click ‘Save’ button
    try tap("folder.edit.form.button")
    //        Then I see the label of the ‘Name’ field in @red //INFO: we can't check colour on iOS via XCUITest
    //        And I see stroke of the ‘Name’ field in @red //INFO: we can't check colour on iOS
    //        And I see exclamation mark in @red // Android only
    //        And I see error ‘Length should be between 1 and 256’ below the field in @red
    assertExists("form.field.error")
  }

  ///   https://passbolt.testrail.io/index.php?/cases/view/8165
  func test_onTheRootFolderWorkspaceICanSaveNewFolder() throws {
    //      Given that I am on #PRO_FOLDER_CREATION_WITH_PERMISSION
    //        And I clicked on the create button
    try tap("folder.explore.create.new")
    //        And I clicked on the create folder button
    try tap("resource.folders.add.folder")
    //        And I filled out mandatory ‘Name’ field
    try type(text: "Automated tests folder iOS", to: "form.textfield.text")
    //        When I click ‘Save’ button
    try tap("folder.edit.form.button")
    //        Then I see ‘New folder {folder’s name} has been created!’ in @green //INFO: we can't check colour on iOS via XCUITest
    //    TODO: There is no snackbar here: https://app.clickup.com/t/2593179/MOB-1905
    //        And I am redirected to the folders workspace
    assertPresentsString(matching: "Folders")
  }

  ///   https://passbolt.testrail.io/index.php?/cases/view/8166
  func test_onTheFolderWorkspaceICanOpenFolder() throws {

    //        Given that I am on #PRO_FOLDER_CREATION_WITH_PERMISSION
    //        And I have at least the "can update" permission in the current context
    //        When I click a folder which I created before //INFO: a dedicated folder was created as it would be hard to use previously created one
    try type(text: "Empty Folder", to: "search.view.input")
    try tap("Empty folder for testing")
    //        Then I see a back arrow to go back to the previous page
    assertExists("Back")
    //        And I see folder icon
    assertExists("Folder")
    //        And I see folder name
    assertPresentsString(matching: "Empty folder for testing")
    //        And I see ‘3 dots’ // TODO: Add accessibility identifier for this element
    ignoreFailure("There is no accessibility identifier for this 3-dot menu on folder's screen") {
      assertExists("More")
    }
    //        And I see filters icon
    assertExists("Filter")
    //        And I see search bar
    assertExists("search.view.input")
    //        And I see user’s current avatar // TODO: Add accessibility identifier for this element
    assertExists("search.view.cancel")
    //        And I see ‘There are no passwords’ description with picture
    assertPresentsString(matching: "There are no results")
    //        And I see create button in @blue //INFO: we can't check colour on iOS via XCUITest
    assertExists("folder.explore.create.new")
  }
}
