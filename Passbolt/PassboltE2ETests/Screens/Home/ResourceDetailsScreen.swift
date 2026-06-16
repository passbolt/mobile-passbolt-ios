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

final internal class ResourceDetailsScreen: Screen {

  internal override var requiredElements: Array<XCUIElement> {
    [
      title,
      passwordSectionTitle,
    ]
  }

  // MARK: - Navigation

  lazy var backButton: XCUIElement = self.application.buttons["ArrowLeft"]
  lazy var moreButton: XCUIElement = self.application.buttons["resource.details.more.button"]

  // MARK: - Header

  lazy var title: XCUIElement = self.application.staticTexts.firstMatch

  internal func resourceIcon(identifier: String) -> XCUIElement {
    self.application.images[identifier]
  }

  // MARK: - Field labels

  lazy var mainURILabel: XCUIElement = self.application.staticTexts["Main URI"]
  lazy var usernameLabel: XCUIElement = self.application.staticTexts["Username"]
  lazy var passwordLabel: XCUIElement = self.application.staticTexts["Password"]
  lazy var descriptionLabel: XCUIElement = self.application.staticTexts["Description"]
  lazy var noteLabel: XCUIElement = self.application.staticTexts["Note"]

  // MARK: - Field values

  private lazy var passwordSectionTitle: XCUIElement =
    self.application.staticTexts["resource.detail.section.password.title"]
  lazy var usernameValue: XCUIElement = self.application.staticTexts["text.value.Username"]
  lazy var encryptedPasswordValue: XCUIElement = self.application.staticTexts["text.encrypted.Password"]
  lazy var revealedPasswordValue: XCUIElement = self.application.staticTexts["text.password.Password"]
  lazy var mainURIValue: XCUIElement = self.application.staticTexts["text.value.Main URI"]
  lazy var encryptedNoteValue: XCUIElement = self.application.buttons["text.encrypted.note"]

  // MARK: - Buttons

  lazy var copyURIButton: XCUIElement = self.application.buttons["copy.button.Main URI"]
  lazy var copyUsernameButton: XCUIElement = self.application.buttons["copy.button.Username"]
  lazy var copyDescriptionButton: XCUIElement = self.application.buttons["copy.button.Description"]
  lazy var revealPasswordButton: XCUIElement = self.application.buttons["reveal.button.Password"]
  lazy var hidePasswordButton: XCUIElement = self.application.buttons["hide.button.Password"]
  lazy var revealNoteButton: XCUIElement = self.application.buttons["reveal.button.note"]
  lazy var hideNoteButton: XCUIElement = self.application.buttons["hide.button.note"]

  // MARK: - Sections

  lazy var metadataSection: XCUIElement = self.application.staticTexts["Metadata"]
  lazy var tagsSection: XCUIElement = self.application.staticTexts["Tags"]
  lazy var locationSection: XCUIElement = self.application.staticTexts["Location"]
  lazy var sharedWithSection: XCUIElement = self.application.staticTexts["Shared with"]
  lazy var permissionsTitle: XCUIElement = self.application.staticTexts["resource.detail.section.permissions.title"]
  lazy var permissionsContent: XCUIElement = self.application.images["resource.detail.section.permissions.content"].firstMatch
}
