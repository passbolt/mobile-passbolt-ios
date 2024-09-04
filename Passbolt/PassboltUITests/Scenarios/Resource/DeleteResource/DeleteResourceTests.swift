//
// Passbolt - Open source password manager for teams
// Copyright (c) 2024 Passbolt SA
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

import XCTest

final class DeleteResourceTests: UITestCase {

  override func beforeEachTestCase() throws {
    try signIn()
    try tap("search.view.menu")
    try tap("plainResourcesList")
  }

  ///    https://passbolt.testrail.io/index.php?/cases/view/8140
  func test_onTheActionMenuDrawerICanClickDeletePasswordElement() throws {
    //        Given that I am on the resource’s action menu drawer
    //        And I see ‘Delete password’ element enabled
    try type(text: "TestiOS", to: "search.view.input")
    try selectCollectionViewItem(identifier: "resource.list.collection.view", at: 1)
    try tapButton("resource.details.more.button")
    //        When I click ‘Delete password’
    try tap("Trash")
    //        Then I see a popup with ‘Are you sure?’ information
    assertPresentsString(matching: "Are you sure?")
    //        And I see description of this popup
    //        And I see ‘Cancel’ button in @blue
    assertInteractive("Cancel")
    //        And I see ‘Delete’ button in @blue
    assertInteractive("Delete")
  }

  ///    https://passbolt.testrail.io/index.php?/cases/view/8141
  func test_onThePasswordRemovalPopupICanClickTheCancelButton() throws {
    //          Given that I am on removal popup
    try type(text: "TestiOS", to: "search.view.input")
    try selectCollectionViewItem(identifier: "resource.list.collection.view", at: 1)
    try tapButton("resource.details.more.button")
    try tap("Trash")
    //          When I click ‘Cancel’ button in @blue
    try tap("Cancel")
    //          Then I am back on the resource view page
    assertPresentsString(matching: "TestiOS")
  }

  ///    https://passbolt.testrail.io/index.php?/cases/view/8142
  func test_onThePasswordRemovalPopupICanClickTheDeleteButton() throws {
    let randomName = "TestiOS" + String(Int.random(in: 0 ..< 100_000))
    try createResource(
      name: randomName,
      username: "UsernameTestOniOS",
      uri: "UrlTestOniOS",
      password: "PasswordTestOniOS"
    )
    //          Given that I am on removal popup
    try type(text: randomName, to: "search.view.input")
    try selectCollectionViewItem(identifier: "resource.list.collection.view", at: 1)
    try tapButton("resource.details.more.button")
    //          When I click ‘Delete’ button in @blue
    try tap("Trash")
    //          Then I am back on the homepage
    //          And I see a popup "<password name> password was deleted." in @green
    //      TODO: There is no snackbar Accessibility ID https://app.clickup.com/t/2593179/MOB-1985

    try tap("Delete")
    //          Then I am back on the resource view page
    try waitForElement("resource.list.collection.view")
    assertNotExists(randomName, inside: "resource.list.collection.view")
  }
}
