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

        On(PermissionsListScreen.self) { permissions in
          VerifyPermissionCellCount(collectionView: permissions.collectionView, expectedCount: 1)
          Tap(permissions.editButton, "Edit permissions")
        }
        On(PermissionsEditScreen.self) { edit in
          Tap(edit.addUsersButton, "Add users")
          AddPermissionForGroup(groupName: "Only Betty Group")
          Tap(edit.applyButton, "Apply changes")
        }
        WaitFor(details.permissionsContent, timeout: .longNetworkCall, "Permissions")
        Tap(details.permissionsContent, "Open permissions again")

        On(PermissionsListScreen.self) { permissions in
          VerifyPermissionCellCount(collectionView: permissions.collectionView, expectedCount: 2)
          Tap(permissions.editButton, "Edit to remove")
        }
        On(PermissionsEditScreen.self) { _ in
          RemovePermissionForGroup(groupName: "Only Betty Group")
        }
        WaitFor(details.permissionsContent, timeout: .longNetworkCall, "Permissions")
        Tap(details.permissionsContent, "Open permissions final check")
        On(PermissionsListScreen.self) { permissions in
          VerifyPermissionCellCount(collectionView: permissions.collectionView, expectedCount: 1)
        }
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

internal struct AddPermissionForGroup: UITestStep {

  internal var name: String { "Add permission for \(groupName)" }

  private let groupName: String

  internal init(groupName: String) {
    self.groupName = groupName
  }

  @MainActor
  internal func execute() throws {
    let textField: XCUIElement = application.textFields["search.view.input"]
    textField.tap()
    textField.typeText(groupName)
    let groupCell: XCUIElement? = application.collectionViews.cells.allElementsBoundByIndex
      .first(where: { $0.staticTexts[groupName].exists })
    guard let groupCell else {
      throw AssertionFailure("Group cell '\(groupName)' not found")
    }
    groupCell.tap()
    application.buttons["Apply"].tap()
  }
}

internal struct RemovePermissionForGroup: UITestStep {

  internal var name: String { "Remove permission for \(groupName)" }

  private let groupName: String

  internal init(groupName: String) {
    self.groupName = groupName
  }

  @MainActor
  internal func execute() throws {
    let groupCell: XCUIElement? = application.collectionViews.cells.allElementsBoundByIndex
      .first(where: { $0.staticTexts[groupName].exists })
    guard let groupCell else {
      throw AssertionFailure("Group cell '\(groupName)' not found")
    }
    groupCell.tap()
    application.buttons["Delete permission"].tap()
    application.buttons["Confirm"].tap()
    application.buttons["Apply"].firstMatch.tap()
  }
}
