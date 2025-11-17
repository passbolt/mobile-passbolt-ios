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

internal class TOTPCreateScreen: Screen {
  private let screenIdentifier = "screen.resource.edit"

  override var requiredElements: Array<XCUIElement> {
    [
      header,
      nameField,
      totpSection,
      secretField,
      createButton,
    ]
  }

  private var header: XCUIElement {
    self.app.staticTexts["Create a resource"]
  }

  private var nameField: XCUIElement {
    self.app.textFields["form.textfield.text.Name"]
  }

  private var totpSection: XCUIElement {
    self.app.staticTexts["TOTP"]
  }

  private var secretField: XCUIElement {
    self.app.textFields["form.textfield.text.Secret"]
  }

  private var createButton: XCUIElement {
    self.app.descendants(matching: .any).element(matching: .button, identifier: screenIdentifier)
  }

  internal func type(name: String) {
    self.type(name, to: nameField)
  }

  internal func type(secret: String) {
    self.type(secret, to: secretField)
  }

  internal func tapCreateButton() {
    self.createButton.tap()
  }

  internal func waitForDisappearance() {
    self.waitForDisappearance(of: createButton)
  }
}
