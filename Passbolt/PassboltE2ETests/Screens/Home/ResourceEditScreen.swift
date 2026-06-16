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

final internal class ResourceEditScreen: Screen {

  override internal var requiredElements: Array<XCUIElement> {
    [
      nameLabel,
      passwordLabel,
      mainURILabel,
      usernameLabel,
      backButton,
      saveButton,
      nameField,
      mainURIField,
      usernameField,
      passwordField,
    ]
  }

  private lazy var nameLabel = self.application.staticTexts["Name"]
  private lazy var passwordLabel = self.application.staticTexts["Password"]
  private lazy var mainURILabel = self.application.staticTexts["Main URI"]
  private lazy var usernameLabel = self.application.staticTexts["Username"]
  lazy var backButton = self.application.buttons["ArrowLeft"]
  lazy var saveButton = self.application.buttons["screen.resource.edit"]
  lazy var nameField = self.application.textFields["form.textfield.text.Name"]
  lazy var mainURIField = self.application.textFields["form.textfield.text.Main URI"]
  lazy var usernameField = self.application.textFields["form.textfield.text.Username"]
  lazy var passwordField = self.application.secureTextFields["form.textfield.field"]
}
