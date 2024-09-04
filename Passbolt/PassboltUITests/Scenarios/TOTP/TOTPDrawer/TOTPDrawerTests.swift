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

final class TOTPDrawerTests: UITestCase {

  override func beforeEachTestCase() throws {
    try signIn()
    try tapTab("TOTP")
  }

  ///    https://passbolt.testrail.io/index.php?/cases/view/9181
  func test_asALoggedInUserICanSeeATotpResourceDrawer() throws {
    //        Given that I am a [logged in user on the TOTP page with resources]
    //        When  I click on the 3 dot menu of a TOTP resource
    try type(text: "A Standalone", to: "search.view.input")
    try selectCollectionViewButton(identifier: "totp.collection.view", buttonIdentifier: "More", at: 1)
    //        Then  I see the TOTP resource drawer
    //        And   I see the label of the resource with a close button
    assertExists("Close")
    assertPresentsString(matching: "A Standalone TOTP")
    //        And I see a <menu item> list item with a <graphic> icon
    //        And I see the Delete TOTP list item in @red //NOTE: XCUITest not allowing to check the colour
    //
    //        | menu item         | graphic           |
    //        | Copy TOTP         | two squares       |
    assertExists("Copy TOTP")
    assertExists("Copy")
    //        | Show TOTP         | eye               |
    assertExists("Show TOTP")
    assertExists("Eye")
    //        | Edit TOTP         | square and pencil |
    assertExists("Edit TOTP")
    assertExists("Edit")
    //        | Delete TOTP       | trash             |
    assertExists("Delete TOTP")
    assertExists("Trash")
  }

  ///    https://passbolt.testrail.io/index.php?/cases/view/9184
  func test_asALoggedInUserICanSeeTheEditTOTPDrawer() throws {
    //        Given   that I am a [logged in user on the TOTP page with resources]
    //        And     I am on a TOTP resource drawer
    try type(text: "A Standalone", to: "search.view.input")
    try selectCollectionViewButton(identifier: "totp.collection.view", buttonIdentifier: "More", at: 1)
    //        When    I click on 'Edit TOTP' list item
    try tap("resource.menu.item.edit.otp")
    //        Then    I see the Edit TOTP drawer
    //        And     I see the title of the drawer with a close button
    assertPresentsString(matching: "Edit TOTP")
    assertExists("Close")
    //        And     I see a <menu item> list item with a <graphic> icon
    //
    //        | menu item              | graphic           |
    //        | Scan a new QR code     | camera            |
    assertExists("Scan QR code")
    assertExists("Camera")
    //        | Edit the TOTP manually | square and pencil |
    assertExists("Edit TOTP manually")
    assertExists("EditAlt")
  }

  ///    https://passbolt.testrail.io/index.php?/cases/view/9190
  func test_asALoggedInUserICanDeleteATotp() throws {
    // create TOTP with pseudo-random name
    try tap("totp.create.button")
    try tap("EditAlt")
    let randomDeleteName = "Delete me " + String(Int.random(in: 0 ..< 10_000))
    try type(text: randomDeleteName, to: "Name")
    try type(text: "AAABBBCCC", to: "Secret")
    try tap("Create standalone TOTP")
    //        Given   that I am a [logged in user on the TOTP page with standalone resources]
    //        And I am on the 'Delete TOTP' popup
    //        When    I click on 'Delete TOTP' button
    try type(text: randomDeleteName, to: "search.view.input")
    try selectCollectionViewButton(identifier: "totp.collection.view", buttonIdentifier: "More", at: 1)
    try tap("Trash")
    try tap("Delete TOTP")
    //        Then    I see the main TOTP page
    try waitForElement("totp.collection.view")
    assertNotExists(randomDeleteName, inside: "totp.collection.view", timeout: 5)
    //        And I see a snackbar telling me the TOTP was deleted
    // TODO: There is no snackbar Accessibility ID https://app.clickup.com/t/2593179/MOB-1985
  }
}
