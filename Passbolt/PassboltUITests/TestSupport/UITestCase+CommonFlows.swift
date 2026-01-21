//
// Passbolt - Open source password manager for teams
// Copyright (c) 2021, 2024 Passbolt SA
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

extension UITestCase {

  internal final func signIn(
    password: String = MockAccount.automation.password,
    index: Int = 0
  ) throws {
    try takeFirstAccount()
    let authScreen: AuthenticationScreen = screen()
    authScreen.ensureDisplayed()
    try authScreen.enterPassphrase(password)
    authScreen.revealPassword()
    authScreen.tapSignIn()
    try avoidTutorial()
  }

  internal final func takeFirstAccount() throws {
    ignoreFailure("Test can start already on login screen") {
      try selectCollectionViewItem(
        identifier: "account.selection.collectionview",
        at: 0
      )
    }
  }

  internal final func avoidTutorial() throws {
    // Test can start on tutorial screens
    if unfinishedBiometrySetup || unfinishedAutofillSetup {
      wait(for: application.staticTexts["Maybe later"])
      wait(for: application.buttons["extension.setup.later.button"])
    }
  }

  private func wait(for elementFetcher: @autoclosure () -> XCUIElement, timeout: TimeInterval = 5.0) {
    let element: XCUIElement = elementFetcher()
    let predicate = NSPredicate(format: "exists == true")
    let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
    _ = XCTWaiter().wait(for: [expectation], timeout: timeout)
    if element.exists {
      element.tap()
    }
  }

  internal final func allowCookies()
    throws
  {
    let cookiesButton = safari.buttons["Allow selection"]
    if cookiesButton.exists, cookiesButton.isHittable {
      cookiesButton.tap()
    }
  }

  internal final func createResource(
    name: String = "",
    username: String = "",
    uri: String = "",
    password: String = "",
    description: String = ""
  )
    throws
  {
    try tap("search.view.menu")
    try tap("plainResourcesList")
    try tap("Create")
    try tap("Password", inside: "Password")
    try type(text: name, to: "Enter a name")
    try type(text: username, to: "Enter username")
    try type(text: uri, to: "Enter URI")
    try tap("Return")  // Dismiss keyboard
    try type(text: password, to: "Enter password")
    //        try type(text: description, to: "Enter description") //TODO: the description field is not hittable as for now, needs more investigation.
    try tap("Return")  // Dismiss keyboard
    try tap("Create")
  }
}
