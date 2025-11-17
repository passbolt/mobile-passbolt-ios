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

@MainActor final internal class TOTPDrawerTests: UITestCase {

  override func beforeEachTestCase() throws {
    try signIn()
    try tapTab("TOTP", timeout: 30.0)
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

  ///    https://passbolt.testrail.io/index.php?/cases/view/9190
  func test_asALoggedInUserICanDeleteATotp() throws {
    // create TOTP with pseudo-random name
    let randomDeleteName = "Delete me ".withRandomSuffix()

    createTOTP(named: randomDeleteName)

    let mainTOTPScreen: MainTOTPScreen = screen()
    //        Given   that I am a [logged in user on the TOTP page with standalone resources]
    mainTOTPScreen.ensureDisplayed(timeout: 30.0)
    mainTOTPScreen.search(for: randomDeleteName)

    //        And I am on the 'Delete TOTP' popup
    //        When    I click on 'Delete TOTP' button

    try selectCollectionViewButton(identifier: "totp.collection.view", buttonIdentifier: "More", at: 1)
    try tap("Trash")
    try tap("Delete TOTP")
    //        Then    I see the main TOTP page
    try waitForElement("totp.collection.view")
    assertNotExists(randomDeleteName, inside: "totp.collection.view", timeout: 10)
    //        And I see a snackbar telling me the TOTP was deleted
    // TODO: There is no snackbar Accessibility ID https://app.clickup.com/t/2593179/MOB-1985
  }
}
