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

/// The "Confirm permissions" checkpoint shown before a secret is encrypted for others - sharing a resource,
/// editing a shared one, and creating one inside a shared folder. Sharing can never skip it.
final internal class ConfirmPermissionsScreen: Screen {

  /// The title varies by flow, so the confirm button - which every mode shows - is what identifies the screen.
  override internal var requiredElements: Array<XCUIElement> {
    [
      confirmButton
    ]
  }

  /// Title shown when the screen is a checkpoint on a submitted create or edit form.
  internal lazy var confirmTitle: XCUIElement = self.application.staticTexts["Confirm permissions"]
  /// Title shown when the operator opened the screen to share - it keeps the dedicated share screen's title.
  internal lazy var shareTitle: XCUIElement = self.application.staticTexts["Share password"]
  internal lazy var confirmButton: XCUIElement = self.application.buttons["permissions.confirm.button"]
  internal lazy var cancelButton: XCUIElement = self.application.buttons["permissions.confirm.cancel"]
  internal lazy var addButton: XCUIElement = self.application.buttons["permissions.confirm.add"]
  internal lazy var collectionView: XCUIElement = self.application.collectionViews.firstMatch
  internal lazy var ownershipWarning: XCUIElement =
    self.element(identifiedBy: "permissions.confirm.ownership.warning")
  internal lazy var duplicateWarning: XCUIElement =
    self.element(identifiedBy: "permissions.confirm.duplicate.warning")
  internal func recipientRow(_ identity: String) -> XCUIElement {
    self.element(identifiedBy: "permissions.confirm.row.\(identity)")
  }

  // MARK: - Add users or groups

  /// Queried as a text field on purpose: this screen sets the identifier on the whole `SearchView`, and SwiftUI
  /// pushes it down onto the search icon as well, so matching on identifier alone can return the icon instead.
  internal lazy var addSearchField: XCUIElement =
    self.application.textFields["permissions.confirm.add.search"]
  internal lazy var addApplyButton: XCUIElement =
    self.element(identifiedBy: "permissions.confirm.add.apply")

  /// A user offered by the recipient picker, addressed by username.
  internal func addUserCandidate(_ username: String) -> XCUIElement {
    self.element(identifiedBy: "permissions.confirm.add.user.\(username)")
  }

  /// A group offered by the recipient picker, addressed by name.
  internal func addGroupCandidate(_ groupName: String) -> XCUIElement {
    self.element(identifiedBy: "permissions.confirm.add.group.\(groupName)")
  }

  /// List rows and search fields surface as different element types depending on how SwiftUI composes them,
  /// so these are matched by identifier alone rather than by a guessed type.
  private func element(
    identifiedBy identifier: String
  ) -> XCUIElement {
    self.application
      .descendants(matching: .any)
      .matching(identifier: identifier)
      .firstMatch
  }
}
