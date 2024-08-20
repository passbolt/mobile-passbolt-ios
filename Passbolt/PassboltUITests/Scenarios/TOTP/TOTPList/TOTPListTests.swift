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

final class TOTPListTests: UITestCase {

  override func beforeEachTestCase() throws {
    try signIn()
    try tapTab("TOTP")
  }

  ///    https://passbolt.testrail.io/index.php?/cases/view/9164
  func test_AsALoggedInUserICanSeeTotpPageWithObfuscatedResources() throws {
    //      Given   that I am a [logged in user on the TOTP page with resources]
    //      Then    I see the list of TOTP resources
    //      And     I see a <item> for each TOTP resource list items
    //
    //      | item                                                                   |
    //      | icon with the first letter of the resource in a random colour  |
    try type(text: "A Standalone TOTP", to: "search.view.input")
    assertPresentsString(matching: "AS")
    //      | name of the resource with the URL in parenthesis                       |
    assertPresentsString(matching: "A Standalone TOTP")
    //      | an obfuscated TOTP value grouped by 3 symbols for a total of 6 symbols |
    assertExists("••• •••", inside: "totp.collection.view")
    //      | a show icon next to the obfuscated value                               |
    assertExists("Eye", inside: "totp.collection.view")
    //      | a 3 dot menu on the right                                              |
    assertExists("More")
  }

  ///    https://passbolt.testrail.io/index.php?/cases/view/9165
  func test_asALoggedInUserICanSeeATotpValueInTheTotpPage() throws {
    //        Given   that I am a [logged in user on the TOTP page with resources]
    //        When    I click on the show icon
    try type(text: "A Standalone TOTP", to: "search.view.input")
    try tap("Eye")
    //        Then    I see clearly the TOTP value with a highly readable font
    assertExists("totp.digits")
    //        And the TOTP value is shown in groups of 3 characters
    assertExistsWithPattern("totp.digits")
    //        And I see a timer instead of the show icon
    assertExists("totp.loader.circle")
    //        And I see a snackbar explaining me the TOTP value has been copied to the clipboard // TODO: there is no way currently to add accessibilityID to a snackbar
  }

  ///    https://passbolt.testrail.io/index.php?/cases/view/9167
  func test_asALoggedInUserICanSeeATotpValueIsObfuscatedWhenIPerformAnAction() throws {
    //        Given   that I am a [logged in user on the TOTP page with resources]
    //        And TOTP resource is revealed
    try type(text: "A Standalone TOTP", to: "search.view.input")
    try tap("Eye")
    //        When    I perform any type of action or close the application
    try tap("More")
    //        Then    I see the TOTP value is obfuscated
    assertExists("••• •••")
  }
}
