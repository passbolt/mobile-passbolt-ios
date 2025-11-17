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

internal final class ResourceFormScreen: Screen {

  internal override var requiredElements: Array<XCUIElement> {
    [
      nameField,
      createButton,
    ]
  }

  private var nameField: XCUIElement {
    app.textFields["form.textfield.text.Name"]
  }

  private var mainURIField: XCUIElement {
    app.textFields["form.textfield.text.Main URI"]
  }

  private var usernameField: XCUIElement {
    app.textFields["form.textfield.text.Username"]
  }

  private var passwordField: XCUIElement {
    app.secureTextFields["form.textfield.field"]
  }

  private var createButton: XCUIElement {
    app.buttons["Create"]
  }

  @discardableResult
  internal func type(name: String) -> Self {
    type(name, to: nameField)
  }

  @discardableResult
  internal func type(mainURI: String) -> Self {
    type(mainURI, to: mainURIField)
  }

  @discardableResult
  internal func type(username: String) -> Self {
    type(username, to: usernameField)
  }

  @discardableResult
  internal func type(password: String) -> Self {
    type(password, to: passwordField)
  }

  @discardableResult
  internal func tapCreateButton() -> Self {
    createButton.tap()
    return self
  }

  @discardableResult
  internal func waitForDisappearance() -> Self {
    waitForDisappearance(of: nameField)
  }
}
