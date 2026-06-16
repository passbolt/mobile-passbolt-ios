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

final internal class FolderContentScreen: Screen {

  override internal var requiredElements: Array<XCUIElement> {
    [
      backButton,
      folderIcon
    ]
  }

  internal lazy var backButton: XCUIElement = self.application.buttons["ArrowLeft"]
  internal lazy var folderIcon: XCUIElement = self.application.images["Folder"]
  internal lazy var createButton: XCUIElement = self.application.buttons["folder_contents_create_button"]
  internal lazy var filterButton: XCUIElement = self.application.buttons["Filter"]
  internal lazy var searchField: XCUIElement = self.application.textFields["search.view.input"]
  internal lazy var searchCancel: XCUIElement = self.application.buttons["search.view.cancel"]
  internal lazy var noResultsText: XCUIElement = self.application.staticTexts["There are no results"]
}
