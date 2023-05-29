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

import XCTest

final class TermsAndLicensesTests: UITestCase {

  override func beforeEachTestCase() throws {
    try signIn()
    try tapTab("Settings")
  }

  ///    https://passbolt.testrail.io/index.php?/cases/view/8175
  func test_AsALoggedInUserICanSeeTermsAndLicences() throws {
    //        Given that I am #MOBILE_USER_ON_SETTINGS_PAGE
    //        When    I click on the “Terms & licences” button
    try tap("settings.main.item.terms.and.licenses.title")
    //        Then  I see the “Terms & licences” title
    assertPresentsString(
      matching: "Terms & licenses"
    )
    //            And     I see the back button to go to the main settings page
    ignoreFailure("Back arrow button can't be accessed") {
      assertInteractive("navigation.back")
    }
    //        And     I see a <list item> with an <graphic> icon and a <action item> on the right
    //
    //        Examples:
    //        | list item | graphic | action item |
    //        | Terms & Conditions | info | caret |
    assertInteractive("settings.terms.and.licenses.item.terms.title")
    assertExists("Info")
    assertExists("ChevronRight", inside: "settings.terms.and.licenses.item.terms.title")
    //        | Privacy policy | lock | caret |
    assertInteractive("settings.terms.and.licenses.item.privacy.title")
    assertExists("LockedLock")
    assertExists("ChevronRight", inside: "settings.terms.and.licenses.item.privacy.title")
    //        | Open Source Licences | feather | caret |
    assertInteractive("settings.terms.and.licenses.item.licenses.title")
    assertExists("Feather")
    assertExists("ChevronRight", inside: "settings.terms.and.licenses.item.licenses.title")
  }

  ///    https://passbolt.testrail.io/index.php?/cases/view/2429
  func test_AsALoggedInMobileUserOnTheSettingsPageICanOpenTheTermsAndConditionsPage() throws {
    //      Given   that I am #MOBILE_USER_ON_SETTINGS_PAGE
    //      And     I clicked on the “Terms & licences” button
    try tap("settings.main.item.terms.and.licenses.title")
    //      When    I click on the “Terms & Conditions” button
    try tap("settings.terms.and.licenses.item.terms.title")
    //      Then    I see a “Terms & Conditions” page (as web page)
    try assertPresentsSafari()
    try allowCookies()
    assertPresentsStringInSafari(matching: "Terms and policies")
  }

  /// https://passbolt.testrail.io/index.php?/cases/view/2432
  func test_AsALoggedInMobileUserOnTheSettingsPageICanOpenThePrivacyPolicyPage() throws {
    //      Given   that I am #MOBILE_USER_ON_SETTINGS_PAGE
    //      And     I clicked on the “Terms & licences” button
    try tap("settings.main.item.terms.and.licenses.title")
    //      When    I click on the “Privacy Policy” button
    try tap("settings.terms.and.licenses.item.privacy.title")
    //      Then    I see a “Privacy Policy” page (as web page)
    try assertPresentsSafari()
    try allowCookies()
    assertPresentsStringInSafari(matching: "Website Privacy Policy")
  }
}
