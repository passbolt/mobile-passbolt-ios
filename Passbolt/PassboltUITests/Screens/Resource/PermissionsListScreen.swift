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

internal final class PermissionsListScreen: Screen {

  internal override var requiredElements: Array<XCUIElement> {
    [
      backButton,
      title,
      editButton,
    ]
  }

  private var title: XCUIElement {
    app.staticTexts["Shared with"]
  }

  private var editButton: XCUIElement {
    app.buttons["Edit permissions"]
  }

  internal func cells() -> Array<PermissionCell> {
    app.collectionViews.cells.asArray.map { PermissionCell(element: $0) }
  }

  internal func tapEditButton() {
    editButton.tap()
  }
}

extension PermissionsListScreen {

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
      element.staticTexts.last
    }
  }
}

extension XCUIElementQuery {

  public var asArray: Array<XCUIElement> {
    var result: Array<XCUIElement> = .init()
    for index in 0 ..< self.count {
      let element = self.element(boundBy: index)
      result.append(element)
    }
    return result
  }

  public var last: XCUIElement {
    self.element(boundBy: self.count - 1)
  }
}
