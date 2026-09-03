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

internal final class ShareResourceTests: UITestCase {

  override func beforeEachTestCase() throws {
    try super.beforeEachTestCase()
    try signIn()
    homeScreen.ensureDisplayed()
    let resourceName = "TestiOS"
    homeScreen
      .search(for: resourceName)
      .selectItem(at: 1)

    let detailsScreen: ResourceDetailsScreen = screen()
    detailsScreen
      .ensureDisplayed()
      .scrollToPermissions()
      .openPermissionDetails()
  }

  /// https://passbolt.testrail.io/index.php?/cases/view/11202
  internal func testSharedWithScreen() async {

    let permissionsListScreen: PermissionsListScreen = screen()
    permissionsListScreen.ensureDisplayed()

    let cells: Array<PermissionsListScreen.PermissionCell> = permissionsListScreen.cells()
    XCTAssertEqual(cells.count, 1)
    let firstCell = cells[0]
    XCTAssertEqual(firstCell.nameLabel.label, "\(MockAccount.automation.firstName) \(MockAccount.automation.lastName)")
    XCTAssertEqual(firstCell.emailLabel.label, "\(MockAccount.automation.username)")
    XCTAssertEqual(firstCell.roleLabel.label, "is owner")
  }

  /// https://passbolt.testrail.io/index.php?/cases/view/11206
  internal func testChangePermissionsAnsSaveChanges() {

    let permissionsListScreen: PermissionsListScreen = screen()
    permissionsListScreen.ensureDisplayed()

    var cells: Array<PermissionsListScreen.PermissionCell> = permissionsListScreen.cells()
    XCTAssertEqual(cells.count, 1)

    permissionsListScreen.addPermission(for: "Only Betty Group")

    // Applying the confirmation leaves the operator on this list; reopening it reloads the refreshed permissions.
    permissionsListScreen.ensureDisplayed()
    permissionsListScreen.backButton.tap()

    let detailsScreen: ResourceDetailsScreen = screen()
    detailsScreen
      .ensureDisplayed()
      .openPermissionDetails()

    permissionsListScreen.ensureDisplayed()

    cells = permissionsListScreen.cells()
    XCTAssertEqual(cells.count, 2)

    let bettyGroupCell = cells.first(where: { $0.nameLabel.label == "Only Betty Group" })
    let bettyUser = cells.first(where: {
      $0.nameLabel.label == "\(MockAccount.automation.firstName) \(MockAccount.automation.lastName)"
    })

    XCTAssertEqual(bettyGroupCell?.roleLabel.label, "can read")
    XCTAssertEqual(bettyUser?.roleLabel.label, "is owner")

    permissionsListScreen.removePermission(for: "Only Betty Group")

    permissionsListScreen.ensureDisplayed()
    permissionsListScreen.backButton.tap()

    detailsScreen
      .ensureDisplayed()
      .openPermissionDetails()

    permissionsListScreen.ensureDisplayed()

    cells = permissionsListScreen.cells()
    XCTAssertEqual(cells.count, 1)
  }
}

extension ResourceDetailsScreen {

  func addPermission(
    for identifier: String
  ) {
    let permissionList: PermissionsListScreen = self.scrollToPermissions()
      .openPermissionDetails()
    permissionList.ensureDisplayed()
    permissionList.addPermission(for: identifier)
    // Applying the confirmation leaves the operator on the permissions list it was opened from.
    permissionList.ensureDisplayed()
  }

}

extension PermissionsListScreen {

  /// Recipients are composed on the "Confirm permissions" screen - there is no separate share screen - so both the
  /// change and its confirmation happen there, and applying it leaves the operator back on this list.
  func addPermission(
    for identifier: String
  ) {
    self.ensureDisplayed()
    tapEditButton()

    let addRow: XCUIElement = element(identifiedBy: "permissions.confirm.add")
    XCTAssert(
      addRow.waitForExistence(timeout: 30),
      "Sharing must open the permission confirmation"
    )
    addRow.tap()

    // `permissions.confirm.add.search`, not `search.view.input`: SwiftUI pushes a container's identifier down
    // onto its children, so the one this screen sets on the whole `SearchView` replaces the field's own.
    let searchField: XCUIElement = app.textFields["permissions.confirm.add.search"]
    XCTAssert(searchField.waitForExistence(timeout: 30), "Recipient picker was not shown")
    searchField.tap()
    searchField.typeText(identifier)
    // Apply is anchored to the bottom of the picker, where the search keyboard would swallow the tap.
    dismissKeyboardIfPresent()

    let groupCandidate: XCUIElement = element(identifiedBy: "permissions.confirm.add.group.\(identifier)")
    XCTAssert(groupCandidate.waitForExistence(timeout: 10))
    groupCandidate.tap()

    let applyButton: XCUIElement = app.buttons["permissions.confirm.add.apply"]
    XCTAssert(applyButton.waitForExistence(timeout: 10))
    XCTAssert(applyButton.isHittable, "Apply is covered by another view - the picker cannot be applied")
    applyButton.tap()

    // Applying fetches the picked recipient's key and membership before the row appears - confirming sooner would
    // confirm a list the group has not joined yet.
    let addedRow: XCUIElement = element(identifiedBy: "permissions.confirm.row.\(identifier)")
    XCTAssert(
      addedRow.waitForExistence(timeout: 30),
      "Group '\(identifier)' was not added to the recipients"
    )

    confirmPermissions()
  }

  func removePermission(
    for identifier: String
  ) {
    self.ensureDisplayed()
    tapEditButton()

    let recipientRow: XCUIElement = element(identifiedBy: "permissions.confirm.row.\(identifier)")
    XCTAssert(
      recipientRow.waitForExistence(timeout: 30),
      "Sharing must open the permission confirmation"
    )
    // Removal lives in the recipient's details, not on the row - the list offers no swipe action.
    recipientRow.tap()

    let removeButton: XCUIElement = app.buttons["permissions.confirm.group.remove"]
    XCTAssert(
      removeButton.waitForExistence(timeout: 10),
      "Remove was not offered in the details of '\(identifier)'"
    )
    removeButton.tap()

    confirmPermissions()
  }

  /// Closes the keyboard if one is up, so a tap meant for a bottom-anchored button does not land on a key.
  private func dismissKeyboardIfPresent() {
    guard app.keyboards.count > 0, app.keyboards.buttons["Return"].exists
    else { return }
    app.keyboards.buttons["Return"].tap()
  }

  /// Sharing always routes through the "Confirm permissions" checkpoint - it can never be skipped, so every share
  /// has to be confirmed before it reaches the server.
  private func confirmPermissions() {
    let confirmButton: XCUIElement = app.buttons["permissions.confirm.button"]
    XCTAssert(
      confirmButton.waitForExistence(timeout: 30),
      "Permission confirmation must be shown for a share"
    )
    confirmButton.tap()
  }

  /// List rows and search fields surface as different element types depending on how SwiftUI composes them, so
  /// these are matched by identifier alone rather than by a guessed type.
  private func element(
    identifiedBy identifier: String
  ) -> XCUIElement {
    app
      .descendants(matching: .any)
      .matching(identifier: identifier)
      .firstMatch
  }
}
