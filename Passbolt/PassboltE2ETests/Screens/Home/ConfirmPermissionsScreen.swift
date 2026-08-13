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

/// The "Confirm permissions" checkpoint shown before a secret is encrypted for others
/// (create-in-shared-folder, edit-shared). The explicit share flow uses the dedicated share screen instead.
final internal class ConfirmPermissionsScreen: Screen {

  override internal var requiredElements: Array<XCUIElement> {
    [
      title,
      confirmButton
    ]
  }

  internal lazy var title: XCUIElement = self.application.staticTexts["Confirm permissions"]
  internal lazy var confirmButton: XCUIElement = self.application.buttons["permissions.confirm.button"]
  internal lazy var cancelButton: XCUIElement = self.application.buttons["permissions.confirm.cancel"]
  internal lazy var addButton: XCUIElement = self.application.buttons["permissions.confirm.add"]
  internal lazy var collectionView: XCUIElement = self.application.collectionViews.firstMatch
  /// Warning shown when a recipient would receive access more than once (directly and through a group,
  /// or through several groups).
  internal lazy var duplicateWarning: XCUIElement =
    self.application.otherElements["permissions.confirm.duplicate.warning"]

  /// A recipient row, addressed by the identity the operator sees - a username for a user, a name for a group.
  /// Tapping it opens that recipient's details, where its permission level is adjusted.
  internal func recipientRow(_ identity: String) -> XCUIElement {
    self.element(identifiedBy: "permissions.confirm.row.\(identity)")
  }

  // MARK: - Add users or groups

  internal lazy var addSearchField: XCUIElement =
    self.element(identifiedBy: "permissions.confirm.add.search")
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
