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

internal final class PermissionsEditScreen: Screen {

  internal override var requiredElements: Array<XCUIElement> {
    [
      backButton,
      title,
      addUsersButton,
      applyButton,
    ]
  }

  private var title: XCUIElement {
    app.staticTexts["Share password"]
  }

  private var applyButton: XCUIElement {
    app.buttons["Apply"]
  }

  private var addUsersButton: XCUIElement {
    app.buttons["Add users"]
  }

  internal func cells() -> Array<PermissionCell> {
    app
      .collectionViews
      .cells
      .asArray
      .dropFirst() // remove "Add users" cell
      .map { PermissionCell(element: $0) }
  }

  internal func tapApplyButton() {
    applyButton.tap()
  }

  internal func tapAddUsersButton() {
    addUsersButton.tap()
  }
}

extension PermissionsEditScreen {

  @MainActor
  final class PermissionCell {
    private let element: XCUIElement

    internal init(element: XCUIElement) {
      self.element = element
    }

    internal var nameLabel: XCUIElement {
      element.staticTexts.element(boundBy: 0)
    }

    internal var emailLabel: XCUIElement {
      element.staticTexts.element(boundBy: 1)
    }

    internal var roleLabel: XCUIElement {
      element.staticTexts.element(boundBy: 2)
    }

    internal func tap() {
      element.tap()
    }
  }
}
