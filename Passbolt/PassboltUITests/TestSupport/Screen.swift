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

@_exported import XCTest

@MainActor internal class Screen {

  internal let app: XCUIApplication

  internal var requiredElements: Array<XCUIElement> { .init() }

  required internal init(
    application: XCUIApplication
  ) {
    self.app = application
  }

  internal var backButton: XCUIElement {
    self.app.buttons["BackButton"]
  }

  @discardableResult
  internal func ensureDisplayed(timeout: TimeInterval = 5.0) -> Self {
    for element in self.requiredElements where !element.exists {
      // Wait for the element to appear only if it does not already exist to speed up tests
      XCTAssertTrue(
        element.waitForExistence(
          timeout: timeout
        ),
        "Expected element \(element) to be present on screen \(Self.self)"
      )
    }

    return self
  }

  internal func isDisplayed() -> Bool {
    for element in self.requiredElements where !element.exists {
      return false
    }
    return true
  }

  @discardableResult
  internal func type(_ text: String, to element: XCUIElement) -> Self {
    element.tap()
    element.typeText(text)
    if self.app.buttons["return"].exists {
      self.app.buttons["return"].tap()  // Dismiss keyboard
    }

    return self
  }

  @discardableResult
  internal func waitForDisappearance(of element: XCUIElement, timeout: TimeInterval = 30.0) -> Self {
    let predicate = NSPredicate(format: "exists == false")
    let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
    let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
    XCTAssertEqual(result, .completed, "Element did not disappear in time")
    return self
  }

  internal func screen<ScreenType>(_ type: ScreenType.Type = ScreenType.self) -> ScreenType where ScreenType: Screen {
    ScreenType(application: app)
  }
}
