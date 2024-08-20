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

import Foundation

final class CreateTOTPTests: UITestCase {

  override func beforeEachTestCase() throws {
    try signIn()
    try tapTab("TOTP")
  }

  ///    https://passbolt.testrail.io/index.php?/cases/view/9173
  func test_asALoggedInUserICanSeeTheCreateTotpFormPage() throws {
    //        Given   that I am a [logged in user on the TOTP page with resources]
    //        And I am on the “Create TOTP” drawer
    try tap("totp.create.button")
    //        When    I click on the “Create TOTP manually” list item
    try tap("EditAlt")
    //        Then    I see a “Create TOTP” page
    assertPresentsString(matching: "Create TOTP")
    //        And I see page title with a back arrow to go back to the previous page
    ignoreFailure("Back arrow button can't be accessed") {
      assertInteractive("navigation.back")
    }
    //        And I see a field with a <label>, a <option> option, input field with a <placeholder> placeholder
    //        And I see an “Advanced settings” section link with an icon and a caret
    assertPresentsString(matching: "Advanced settings")
    //        And I see a “Create a standalone TOTP” primary button
    assertExists("Create standalone TOTP")
    //        And I see a “Link TOTP to a password” link below the primary button
    assertExists("Link TOTP to a password")
    //        | label        | option    | placeholder |
    //        | Name (Label) | mandatory | Name        |
    assertPresentsString(matching: "Name (Label) *")
    assertPresentsString(matching: "Name")
    //        | URL (Issuer) | optional  | URL         |
    assertPresentsString(matching: "URL (Issuer)")
    assertPresentsString(matching: "URL")
    //        | Secret       | mandatory | Secret      |
    assertPresentsString(matching: "Secret *")
    assertPresentsString(matching: "Secret")
  }

  ///    https://passbolt.testrail.io/index.php?/cases/view/9179
  func test_asALoggedInUserICanAddAManuallyCreatedStandaloneTotpResource() throws {
    //        Given   that I am a [logged in user on the TOTP page with resources]
    try tap("totp.create.button")
    try tap("EditAlt")
    //        And I am on the “Create TOTP” page
    assertPresentsString(matching: "Create TOTP")
    //        And I filled out at least the mandatory field with a valid entry
    let randomName = "TOTP " + String(Int.random(in: 0 ..< 100_000))
    try type(text: randomName, to: "Name")
    try type(text: "AAABBBCCC", to: "Secret")
    //        When    I click on the “Create a standalone TOTP” primary button
    try tap("Create standalone TOTP")
    //        Then    I see the main TOTP page
    try type(text: randomName, to: "search.view.input")
    //        And I see the TOTP resource I created manually
    assertPresentsString(matching: randomName)
    //        And I see the TOTP value hidden
    assertExists("••• •••", inside: "totp.collection.view")
  }
}
