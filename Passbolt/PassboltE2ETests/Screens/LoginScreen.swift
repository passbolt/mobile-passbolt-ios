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

internal class LoginScreen: Screen {

  override internal var requiredElements: Array<XCUIElement> {
    [
      email,
      url,
      passphraseLabel,
      passphraseField,
      signInButton
    ]
  }

  lazy var email: XCUIElement = self.application.staticTexts["label.account.name"]
  lazy var url: XCUIElement = self.application.staticTexts["label.account.url"]
  lazy var passphraseLabel: XCUIElement = self.application.staticTexts["Passphrase *"]
  lazy var passphraseField: XCUIElement = self.application.secureTextFields["input.text.passphrase"]
  lazy var signInButton: XCUIElement = self.application.buttons["button.signIn"]

  @discardableResult
  internal func verifyScreenData(matches account: MockAccount) -> Self {
    XCTContext.runActivity(named: "Verifying account data") { _ in
      XCTAssertTrue(self.application.staticTexts["\(account.firstName) \(account.lastName)"].exists, "Account full name does not match expected value")
      XCTAssertTrue(email.label == account.username, "Account name does not match expected value")
    }

    return self
  }

  @discardableResult
  internal func type(password: String) -> Self {
    passphraseField.tap()
    passphraseField.typeText(password)
    return self
  }

  @discardableResult
  internal func tapSignIn() -> Self {
    signInButton.tap()
    return self
  }

  @discardableResult
  internal func waitForLoaderToDisappear() -> Self {
    let activityIndicator: XCUIElement = self.application.activityIndicators.firstMatch
    activityIndicator.waitForExistence("Loading indicator did not appear in time", timeout: .standardUI)
    activityIndicator.waitForDisappearance("Loading indicator did not disappear in time")

    return self
  }
}

