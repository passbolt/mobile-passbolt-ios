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

final class SettingsTests: UITestCase {
    override var initialAccounts: Array<MockAccount> {
        [
            .automation
        ]
    }
    
    override func beforeEachTestCase() {
        typeTo("input", text: MockAccount.automation.username)
        tap("button.signin.passphrase")
        tap("biometrics.info.later.button", required: false, timeout: 2.0)
        tap("biometrics.setup.later.button", required: false, timeout: 2.0)
        tap("extension.setup.later.button", required: false, timeout: 2.0)
        tapTab("Settings")
    }
    
    ///    https://passbolt.testrail.io/index.php?/cases/view/2438
    func test_asAMobileUserOnTheMainSettingsPageICanSeeTheListOfSettingsIHaveAccessTo() {
        //    Given     that I am #MOBILE_USER_ON_SETTINGS_PAGE
        //    When      I’m staying on the Settings page
        //    Then      I see the “Settings” title
        assertPresentsString(matching: "Settings")
        //    And       I see a <list item> with an <graphic> icon and a <action item> on the right
        //
        //            Examples:
        //            | list item | graphic | action item |
        //            | App settings | settings | caret |
        assertInteractive("settings.main.item.application.title")
        assertExists("Settings")
        assertExists("settings.main.item.application.disclosure.indicator")
        //            | Accounts | personas | caret |
        assertInteractive("settings.main.item.application.title")
        assertExists("People")
        assertExists("settings.main.item.accounts.disclosure.indicator")
        //            | Terms & licences | info | caret |
        assertInteractive("settings.main.item.terms.and.licenses.title")
        assertExists("Info")
        assertExists("settings.accounts.item.terms.and.licenses.disclosure.indicator")
        //            | Debug, logs | bug | caret |
        assertInteractive("settings.main.item.application.title")
        assertExists("Bug")
        assertExists("settings.accounts.item.troubleshooting.disclosure.indicator")
        //            | Sign out | exit | none |
        assertInteractive("settings.main.item.sign.out.title")
        assertExists("Exit")
    }
    
    /// https://passbolt.testrail.io/index.php?/cases/view/2435
    func test_asALoggedInMobileUserOnTheSettingsPageICanSignOut() {
        //    Given     that I am a mobile user with the application installed
        //    And       the Passbolt application is already opened
        //    And       I completed the login step
        //    And       I am on the settings page
        //    When      I click on the “Sign out” list item
        tap("settings.main.item.sign.out.title")
        //    Then      I see an confirmation modal
        assertPresentsString(matching: "Are you sure?")
        //    And       I see a sign out button
        assertInteractive("settings.main.sign.out.alert.confirm.title")
        //    And       I see a cancel button
        assertInteractive("settings.main.sign.out.alert.cancel.button")
        //    When      I click on the "Sign out" button
        tap("settings.main.sign.out.alert.confirm.title")
        //    Then      I see the “Sign in - List of accounts” welcome screen
        waitForElementExist("account.selection.title")
        assertExists("account.selection.title")
    }
    
    /// https://passbolt.testrail.io/index.php?/cases/view/2448
    func test_asALoggedInMobileUserOnTheSettingsPageINeedToConfirmSignOut() {
        assertExists("Info")
        //    Given     that I am a mobile user with the application installed
        //    And       I am on the settings page
        //    When      I click on the “Sign out” list item
        tap("settings.main.item.sign.out.title")
        //    Then      I see an confirmation modal
        assertPresentsString(matching: "Are you sure?")
        //    When      I click "Cancel" button
        tap("settings.main.sign.out.alert.cancel.button")
        //    Then      I do not see the modal
        //    And       I am not signed out
        assertPresentsString(matching: "Settings")
    }
}
