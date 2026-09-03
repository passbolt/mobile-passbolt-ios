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

@MainActor
final internal class ShareResourceTests: UITestCase {

  /// https://passbolt.testrail.io/index.php?/cases/view/11202
  func test_sharedWithScreen() async throws {
    let resourceName: ResourceName = "ShareTests".withDateSuffix().withRandomSuffix()
    let account: MockAccount = .automation

    await executeSteps {
      SelectAllItemsFilter()
      CreateResource(
        resourceName: resourceName
      )
      VerifySnackBarMessage(expectedMessage: "New password has been created")
      OpenResourceDetails(resourceName: resourceName)
      On(ResourceDetailsScreen.self) { screen in
        ScrollUntilVisible(screen.permissionsTitle, "Permissions section")
        Tap(screen.permissionsContent, "Open permissions")
      }
      On(PermissionsListScreen.self) { permissions in
        VerifyPermissionCellCount(
          collectionView: permissions.collectionView,
          expectedCount: 1
        )
        VerifyPermissionCell(
          collectionView: permissions.collectionView,
          name: "\(account.firstName) \(account.lastName)",
          email: account.username,
          role: "is owner"
        )
      }
    }
  }

  /// https://passbolt.testrail.io/index.php?/cases/view/11206
  ///
  /// The confirmation screen is where a share is composed as well as confirmed; applying returns to the
  /// permissions list it was opened from.
  func test_changePermissionsAndSaveChanges() async throws {
    let resourceName: ResourceName = "ShareTests".withDateSuffix().withRandomSuffix()

    await executeSteps {
      SelectAllItemsFilter()
      CreateResource(resourceName: resourceName)
      VerifySnackBarMessage(expectedMessage: "New password has been created")
      OpenResourceDetails(resourceName: resourceName)
      On(ResourceDetailsScreen.self) { details in
        ScrollUntilVisible(details.permissionsContent, "Permissions section")
        Tap(details.permissionsContent, "Open permissions")
      }
      On(PermissionsListScreen.self) { permissions in
        VerifyPermissionCellCount(collectionView: permissions.collectionView, expectedCount: 1)
        Tap(permissions.editButton, "Edit permissions")
      }
      On(ConfirmPermissionsScreen.self, timeout: .longNetworkCall) { confirm in
        AddPermissionForGroup(groupName: "Only Betty Group")
        Tap(confirm.confirmButton, "Confirm the recipients")
      }
      On(PermissionsListScreen.self, timeout: .longNetworkCall) { permissions in
        WaitFor(
          permissions.collectionView.staticTexts["Only Betty Group"],
          timeout: .longNetworkCall,
          "The confirmed recipient holds the permission"
        )
        Tap(permissions.editButton, "Edit to remove")
      }
      On(ConfirmPermissionsScreen.self, timeout: .longNetworkCall) { confirm in
        RemovePermissionForGroup(groupName: "Only Betty Group")
        Tap(confirm.confirmButton, "Confirm the revocation")
      }
      On(PermissionsListScreen.self, timeout: .longNetworkCall) { permissions in
        WaitForDisappearance(
          permissions.collectionView.staticTexts["Only Betty Group"],
          timeout: .longNetworkCall,
          "The revoked recipient no longer holds the permission"
        )
        VerifyPermissionCellCount(collectionView: permissions.collectionView, expectedCount: 1)
      }
    }
  }
}

// MARK: - Helper Steps

internal struct VerifyPermissionCellCount: UITestStep {

  internal var name: String { "Verify permission cell count" }

  private let collectionView: XCUIElement
  private let expectedCount: Int
  private let file: StaticString
  private let line: UInt

  internal init(
    collectionView: XCUIElement,
    expectedCount: Int,
    file: StaticString = #fileID,
    line: UInt = #line
  ) {
    self.collectionView = collectionView
    self.expectedCount = expectedCount
    self.file = file
    self.line = line
  }

  @MainActor
  internal func execute() throws {
    let cellCount: Int = collectionView.cells.count
    if cellCount != expectedCount {
      throw AssertionFailure(
        "Expected \(expectedCount) permission cells but found \(cellCount)",
        file: file,
        line: line
      )
    }
  }
}

internal struct VerifyPermissionCell: UITestStep {

  internal var name: String { "Verify permission cell for \(expectedName)" }

  private let collectionView: XCUIElement
  private let expectedName: String
  private let expectedEmail: String
  private let expectedRole: String
  private let file: StaticString
  private let line: UInt

  internal init(
    collectionView: XCUIElement,
    name: String,
    email: String,
    role: String,
    file: StaticString = #fileID,
    line: UInt = #line
  ) {
    self.collectionView = collectionView
    self.expectedName = name
    self.expectedEmail = email
    self.expectedRole = role
    self.file = file
    self.line = line
  }

  @MainActor
  internal func execute() throws {
    let nameExists: Bool = collectionView.staticTexts[expectedName].exists
    let emailExists: Bool = collectionView.staticTexts[expectedEmail].exists
    let roleExists: Bool = collectionView.staticTexts[expectedRole].exists
    if !nameExists || !emailExists || !roleExists {
      throw AssertionFailure(
        "Permission cell not found: name=\(expectedName)(\(nameExists)), email=\(expectedEmail)(\(emailExists)), role=\(expectedRole)(\(roleExists))",
        file: file,
        line: line
      )
    }
  }
}

/// Adds a group to the recipients on the confirmation screen, which is where a share is composed.
internal struct AddPermissionForGroup: UITestStep {

  internal var name: String { "Add permission for \(groupName)" }

  private let groupName: String

  internal init(groupName: String) {
    self.groupName = groupName
  }

  @MainActor
  internal func execute() throws {
    application.descendants(matching: .any)
      .matching(identifier: "permissions.confirm.add")
      .firstMatch
      .tap()

    // The picker refreshes users and groups from the server before opening. Its field answers to
    // `permissions.confirm.add.search`, not `search.view.input` - the identifier set on the whole `SearchView`
    // replaces the one its text field carries, and lands on the search icon too, hence the `textFields` query.
    let textField: XCUIElement = application.textFields["permissions.confirm.add.search"]
    guard textField.waitForExistence(timeout: .slowNetworkCall)
    else { throw AssertionFailure("Recipient picker was not shown") }
    textField.tap()
    textField.typeText(groupName)
    // Apply is anchored to the bottom of the picker, where the search keyboard would swallow the tap.
    dismissKeyboardIfPresent()

    let groupCandidate: XCUIElement = application.descendants(matching: .any)
      .matching(identifier: "permissions.confirm.add.group.\(groupName)")
      .firstMatch
    guard groupCandidate.waitForExistence(timeout: .networkCall)
    else { throw AssertionFailure("Group candidate '\(groupName)' not offered") }
    groupCandidate.tap()

    let applyButton: XCUIElement = application.buttons["permissions.confirm.add.apply"]
    guard applyButton.waitForExistence(timeout: .standardUI)
    else { throw AssertionFailure("Apply was not offered in the recipient picker") }
    guard applyButton.isHittable
    else { throw AssertionFailure("Apply is covered by another view - the picker cannot be applied") }
    applyButton.tap()

    // Applying fetches the recipient's key and membership before the row appears. Waiting for *hittable* also
    // proves the picker closed - `Tap` only checks existence, so a button beneath it would be tapped through.
    let addedRow: XCUIElement = application.descendants(matching: .any)
      .matching(identifier: "permissions.confirm.row.\(groupName)")
      .firstMatch
    try WaitFor(
      addedRow,
      predicate: "isHittable == true",
      timeout: .slowNetworkCall,
      "Group '\(groupName)' added to the recipients"
    )
    .execute()
  }
}

/// Removes a group from the recipients by opening its details from the confirmation screen and using the Remove
/// action there. The list itself offers no removal - a level change or a removal is only committed from details.
internal struct RemovePermissionForGroup: UITestStep {

  internal var name: String { "Remove permission for \(groupName)" }

  private let groupName: String

  internal init(groupName: String) {
    self.groupName = groupName
  }

  @MainActor
  internal func execute() throws {
    let groupRow: XCUIElement = application.descendants(matching: .any)
      .matching(identifier: "permissions.confirm.row.\(groupName)")
      .firstMatch
    guard groupRow.waitForExistence(timeout: .networkCall)
    else { throw AssertionFailure("Recipient row '\(groupName)' not found") }
    groupRow.tap()

    let removeButton: XCUIElement = application.buttons["permissions.confirm.group.remove"]
    guard removeButton.waitForExistence(timeout: .networkCall)
    else { throw AssertionFailure("Remove was not offered in the details of '\(groupName)'") }
    removeButton.tap()

    // Removing returns to the recipient list, so the row going is what proves it landed.
    try WaitFor(
      groupRow,
      predicate: "exists == false",
      timeout: .standardUI,
      "Recipient '\(groupName)' removed from the list"
    )
    .execute()
  }
}
