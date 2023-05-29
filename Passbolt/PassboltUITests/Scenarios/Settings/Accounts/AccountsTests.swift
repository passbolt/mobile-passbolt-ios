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

final class AccountsTests: UITestCase {

  override func beforeEachTestCase() throws {
    try signIn()
    try tapTab("Settings")
  }

  ///    https://passbolt.testrail.io/index.php?/cases/view/8174
  func test_AsAMobileUserICanSeeAccounts() throws {

    //        Given that I am #MOBILE_USER_ON_SETTINGS_PAGE
    //        When    I click on the “Accounts” button
    try tap("settings.main.item.accounts.title")
    //        Then  I see the “Accounts” title
    assertPresentsString(matching: "Accounts")
    //        And     I see the back button to go to the main settings page
    ignoreFailure("The Back Arrow button can't be automated currently") {
      assertInteractive("navigation.back")
    }
    //        And     I see a <list item> with an <graphic> icon and a <action item> on the right
    //
    //        Examples:
    //        | list item | graphic | action item |
    //        | Manage accounts | peronas | caret |
    assertInteractive("settings.accounts.item.manage.title")
    assertExists("Accounts")
    assertExists("ChevronRight", inside: "settings.accounts.item.manage.title")
    //        | Transfer account to another device | lorry | caret |
    assertInteractive("settings.accounts.item.export.title")
    assertExists("MobileTransfer")
    assertExists("ChevronRight", inside: "settings.accounts.item.export.title")
  }
}
