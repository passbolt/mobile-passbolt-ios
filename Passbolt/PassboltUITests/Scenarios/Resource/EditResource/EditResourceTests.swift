//
// Passbolt - Open source password manager for teams
// Copyright (c) 2024 Passbolt SA
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

import XCTest

final class EditResourceTests: UITestCase {

  override func beforeEachTestCase() throws {
    try signIn()
  }

  ///    https://passbolt.testrail.io/index.php?/cases/view/8135
  func test_onTheEditPasswordPageICanEditElements() throws {
    //        Given that I am on Edit password screen
    selectAllItemsFilter()
    try type(text: "ResourcesEditionTestOniOS", to: "search.view.input", timeout: 10.0)
    try selectCollectionViewItem(identifier: "resource.list.collection.view", at: 1)
    try tapButton("resource.details.more.button")
    try tap("Edit")
    //        And I see Edit password workspace
    //        And <placeholder> is filled
    //        When I change <placeholder>
    //        Then <placeholder> is changed
    //
    //        Examples:
    //        | placeholder |
    //        | Enter a name |
    try type(text: "DeleteMe", to: "form.textfield.text.Name")
    assertExists("ResourcesEditionTestOniOSDeleteMe")
    //        | Enter URL |
    try type(text: "DeleteMe", to: "form.textfield.text.Main URI")
    assertExists("TestURLDeleteMe")
    //        | Enter username |
    try type(text: "DeleteMe", to: "form.textfield.text.Username")
    assertExists("TestUsernameDeleteMe")
    //        | Enter a password |
    try swipeUp("form.textfield.text.Main URI")
    try tap("form.textfield.eye")
    try type(text: "DeleteMe", to: "form.textfield.field")
    let passwordValue = try self.element("form.textfield.field", inside: nil).value as? String
    XCTAssert(passwordValue?.contains("DeleteMe") ?? false)

    //        | Enter description | // TODO: when description will work
    //        try type(text: "SoDeleteMe", to: "form.textfield.text.Description")
    //        assertPresentsString(matching: "ResourcesEditionTestOniOSDeleteMe")
  }

  ///    https://passbolt.testrail.io/index.php?/cases/view/8136
  func test_onTheEditPasswordPageICanSaveChangedResources() throws {
    selectAllItemsFilter()
    createResource(
      name: "TestiOS",
      mainURI: "UrlTestOniOS",
      username: "UsernameTestOniOS",
      password: "PasswordTestOniOS"
    )
    //        Given that I am on Edit password screen
    //        And I see Edit password workspace
    try type(text: "TestiOS", to: "search.view.input", timeout: 10.0)
    try selectCollectionViewItem(identifier: "resource.list.collection.view", at: 1)
    try tapButton("resource.details.more.button")
    try tap("Edit")
    //        And <placeholder> was changed
    let randomName = String(Int.random(in: 0 ..< 100_000))
    try type(text: "DeleteMe" + randomName, to: "form.textfield.text.Name")
    try type(text: "DeleteMe", to: "form.textfield.text.Main URI")
    try type(text: "DeleteMe", to: "form.textfield.text.Username")
    try swipeUp("form.textfield.text.Main URI")
    try tap("form.textfield.eye")
    try type(text: "DeleteMe", to: "form.textfield.field")
    try tap("Return")  // dismiss keyboard
    //        When I click ‘Save’ button
    try tap("Save")
    //        Then I see a popup "{password name} password was successfully edited." in @green
    // TODO: There is no snackbar Accessibility ID https://app.clickup.com/t/2593179/MOB-1985
    assertPresentsString(matching: "DeleteMe" + randomName, timeout: 15.0)
    //
    //        Examples:
    //        | placeholder |
    //        | Enter a name |
    //        | Enter URL |
    //        | Enter username |
    //        | Enter a password |
    //        | Enter description |
  }
}
