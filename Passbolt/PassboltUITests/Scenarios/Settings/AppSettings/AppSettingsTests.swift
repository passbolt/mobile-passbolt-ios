//
// Passbolt - Open source password manager for teams
// Copyright (c) 2023 Passbolt SA
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

final class AppSettingsTests: UITestCase {

  override func beforeEachTestCase() throws {
    try signIn()
    try tapTab("Settings")
  }

  ///    https://passbolt.testrail.io/index.php?/cases/view/8168
  func test_AsAnIOSUserICanSeeAppSettings() throws {
    //    Given that I am #MOBILE_USER_ON_SETTINGS_PAGE
    //    When    I click on the “App settings” button
    try tap("settings.main.item.application.title")
    //    Then  I see the “App settings” title
    assertPresentsString(matching: "App Settings")
    //    And     I see the back button to go to the main settings page
    ignoreFailure("Back arrow button can't be accessed") {
      assertInteractive("navigation.back")
    }
    //    And     I see a <list item> with an <graphic> icon and a <action item> on the right
    //
    //        Examples:
    //        | list item | graphic | action item |
    //        | FaceID/TouchID | face/fingerprint | switch |
    assertPresentsString(
      matching: "Unavailable"
    )  // I can't add this AccID
    assertExists("Unavailable")  //On emulators biometry is set to unavailable
    assertInteractive("settings.application.biometrics.disabled.toggle")
    //        | Autofill | key | caret |
    assertInteractive("settings.application.item.autofill.title")
    assertExists("Key")
    assertExists("settings.application.item.autofill.disclosure.indicator")
    //        | Default filter | filter | caret |
    assertInteractive("settings.application.item.default.mode.title")
    assertExists("Filter")
    assertExists("settings.application.item.filter.disclosure.indicator")
  }
}
