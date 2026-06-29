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

    self.ensureDisplayed()
  }

}

extension PermissionsListScreen {

  func addPermission(
    for identifier: String
  ) {
    self.ensureDisplayed()
    tapEditButton()

    let permissionEditScreen: PermissionsEditScreen = screen()
    permissionEditScreen
      .ensureDisplayed()
      .tapAddUsersButton()

    let groupCell = app.collectionViews.cells.asArray.first(where: { $0.staticTexts[identifier].exists })
    XCTAssert(groupCell?.exists == true)
    groupCell?.tap()
    app.buttons["Apply"].tap()

    permissionEditScreen
      .ensureDisplayed()
      .tapApplyButton()
  }

  func removePermission(
    for identifier: String
  ) {
    self.ensureDisplayed()
    tapEditButton()

    let groupCell = app.collectionViews.cells.asArray.first(where: { $0.staticTexts[identifier].exists })
    XCTAssert(groupCell?.exists == true)
    groupCell?.tap()

    app.buttons["Delete permission"].tap()
    app.buttons["Confirm"].tap()

    let permissionEditScreen: PermissionsEditScreen = screen()
    permissionEditScreen
      .ensureDisplayed()

    app.buttons["Apply"].tap()
  }
}
