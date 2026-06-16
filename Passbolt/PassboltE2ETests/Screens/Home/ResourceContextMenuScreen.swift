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

final internal class ResourceContextMenuScreen: Screen {

  override internal var requiredElements: Array<XCUIElement> {
    [
      closeButton
    ]
  }

  lazy var closeButton = self.application.buttons["Close"]
  lazy var copyURLButton = self.application.buttons["Copy URL"]
  lazy var copyUsernameButton = self.application.buttons["Copy username"]
  lazy var copyPasswordButton = self.application.buttons["Copy password"]
  lazy var copyDescriptionButton = self.application.buttons["Copy description"]
  lazy var copyNoteButton = self.application.buttons["Copy note"]

  @discardableResult
  internal func verifyCopyURLExists() -> Self {
    XCTAssertTrue(copyURLButton.exists)
    return self
  }

  @discardableResult
  internal func verifyCopyUsernameExists() -> Self {
    XCTAssertTrue(copyUsernameButton.exists)
    return self
  }

  @discardableResult
  internal func verifyCopyPasswordExists() -> Self {
    XCTAssertTrue(copyPasswordButton.exists)
    return self
  }

  @discardableResult
  internal func verifyCopyDescriptionExists() -> Self {
    XCTAssertTrue(copyDescriptionButton.exists)
    return self
  }

  @discardableResult
  internal func verifyCopyNoteExists() -> Self {
    XCTAssertTrue(copyNoteButton.exists)
    return self
  }

  @discardableResult
  internal func verifyCopyNoteNotExists() -> Self {
    XCTAssertFalse(copyNoteButton.exists, "Copy Note button should not be visible in the resource context menu")
    return self
  }
}
