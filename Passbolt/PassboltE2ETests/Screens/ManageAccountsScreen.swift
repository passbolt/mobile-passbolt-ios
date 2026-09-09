//
// Passbolt - Open source password manager for teams
// Copyright (c) 2021 Passbolt SA
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

/// "Manage accounts" page - the account selection screen presented outside of the sign in flow,
/// so it shows the account list without the "Welcome back!" title.
final internal class ManageAccountsScreen: Screen {

  override internal var requiredElements: Array<XCUIElement> {
    [
      subtitle,
      removeAccountButton,
    ]
  }

  internal lazy var logo: XCUIElement = self.application.images["account.selection.app.logo.imageview"]
  internal lazy var subtitle: XCUIElement = self.application.staticTexts["Choose an account to sign in!"]
  internal lazy var addAccountButton: XCUIElement = self.application.buttons["Add new account"]
  internal lazy var removeAccountButton: XCUIElement =
    self.application.buttons["Remove an account from this device"]
  internal lazy var backButton: XCUIElement = self.application.buttons["ArrowLeft"]

  /// Row of the account in the list, matched by its label - the list container itself carries an
  /// identifier that SwiftUI does not expose as an element.
  internal func accountRow(of account: MockAccount) -> XCUIElement {
    self.application.staticTexts["\(account.firstName) \(account.lastName)"].firstMatch
  }
}
