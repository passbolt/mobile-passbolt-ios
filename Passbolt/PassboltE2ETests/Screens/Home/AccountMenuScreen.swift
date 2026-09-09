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

/// "Switch account" drawer, opened with the avatar in the home list search bar.
final internal class AccountMenuScreen: Screen {

  override internal var requiredElements: Array<XCUIElement> {
    [
      title,
      seeDetailsButton,
      signOutButton,
      manageAccountsButton,
    ]
  }

  internal lazy var title: XCUIElement = self.application.staticTexts["Switch account"].firstMatch
  internal lazy var closeButton: XCUIElement = self.application.buttons["Close"].firstMatch
  internal lazy var seeDetailsButton: XCUIElement = self.application.buttons["See details"]
  internal lazy var signOutButton: XCUIElement = self.application.buttons["Sign out"]
  internal lazy var manageAccountsButton: XCUIElement = self.application.buttons["Manage accounts"]
  /// Scrollable content of the drawer. The home list underneath stays in the hierarchy while the
  /// drawer is presented, so it is excluded explicitly.
  internal lazy var accountsList: XCUIElement =
    self.application
      .scrollViews
      .matching(NSPredicate(format: "identifier != %@", "home.list.collection.view"))
      .firstMatch
  /// Avatars are containers rather than plain images, so they are matched regardless of element type.
  internal lazy var currentAccountAvatar: XCUIElement =
    self.avatar(identifier: "account.menu.current.account.avatar")
  internal lazy var otherAccountAvatar: XCUIElement =
    self.avatar(identifier: "account.menu.other.account.avatar")
  internal lazy var otherAccountRows: XCUIElementQuery =
    self.application.buttons.matching(identifier: "account.menu.other.account.button")

  private func avatar(identifier: String) -> XCUIElement {
    self.application
      .descendants(matching: .any)
      .matching(identifier: identifier)
      .firstMatch
  }

  internal func accountLabel(of account: MockAccount) -> XCUIElement {
    self.application.staticTexts["\(account.firstName) \(account.lastName)"].firstMatch
  }

  internal func accountEmail(of account: MockAccount) -> XCUIElement {
    self.application.staticTexts[account.username].firstMatch
  }

  /// Row of another - not currently signed in - account, matched by its label.
  internal func otherAccountRow(of account: MockAccount) -> XCUIElement {
    self.otherAccountRows
      .containing(
        NSPredicate(format: "label CONTAINS %@", "\(account.firstName) \(account.lastName)")
      )
      .firstMatch
  }
}
