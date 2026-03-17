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

internal final class AuthenticationScreen: Screen {

  internal enum Mode {
    case signIn
    case unlock
  }

  private var mode: Mode = .signIn

  internal override var requiredElements: Array<XCUIElement> {
    [
      title,
      avatar,
      nameLabel,
      urlLabel,
      passphraseTextField,
      passwordRevealButton,
      signInButton,
    ] + (mode == .signIn ? [forgotPasswordButton] : [])
  }

  private var passphraseTextField: XCUIElement {
    app.secureTextFields["input.text.passphrase"]
  }

  private var nameLabel: XCUIElement {
    app.staticTexts["label.account.name"]
  }

  private var urlLabel: XCUIElement {
    app.staticTexts["label.account.url"]
  }

  private var title: XCUIElement {
    app.staticTexts["Enter your passphrase"]
  }

  private var forgotPasswordButton: XCUIElement {
    app.buttons["button.forgot.passphrase"]
  }

  private var passwordRevealButton: XCUIElement {
    app.buttons["input.text.passphrase"]
  }

  private var signInButton: XCUIElement {
    app.buttons["button.signIn"]
  }

  private var avatar: XCUIElement {
    app.images["authorization.passphrase.avatar"]
  }

  internal func revealPassword() {
    passwordRevealButton.tap()
  }

  @discardableResult
  internal func enterPassphrase(
    _ passphrase: String,
    timeout: TimeInterval = 5.0,
    file: StaticString = #file,
    line: UInt = #line
  ) throws -> Self {
    UIPasteboard.general.string = passphrase
    passphraseTextField.tap()

    let maxIterationsCount: Int = 3
    for _ in 0 ..< maxIterationsCount {

      passphraseTextField.doubleTap()  // to trigger text menu

      let pasteMenuItem = XCUIApplication().menuItems.element(boundBy: 0)
      let menuExists: Bool =
        pasteMenuItem.exists
        ? true
        : pasteMenuItem.waitForExistence(timeout: timeout)
      if menuExists {
        pasteMenuItem.tap()
        return self
      }
    }

    throw TestFailure.error(
      message: "Paste menu did not appear after attempting to double-tap the element \"input.text.passphrase\"",
      file: file,
      line: line
    )
  }

  internal func tapSignIn() {
    signInButton.tap()
  }

  @discardableResult
  internal func set(mode: Mode) -> Self {
    self.mode = mode
    return self
  }

  @discardableResult
  internal func assertLabel(equals name: String) -> Self {
    let element: XCUIElement = app.staticTexts[name]
    XCTAssertTrue(element.exists)
    XCTAssertEqual(element.label, name)
    return self
  }

  @discardableResult
  internal func assertURLLabel(equals: String) -> Self {
    XCTAssertEqual(urlLabel.label, equals)
    return self
  }

  @discardableResult
  internal func assertEmail(equals: String) -> Self {
    XCTAssertEqual(nameLabel.label, equals)
    return self
  }
}
