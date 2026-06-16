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
internal class Screen {

  internal var requiredElements: Array<XCUIElement> {
    .init()
  }

  internal let application: XCUIApplication

  internal required init(application: XCUIApplication) {
    self.application = application
  }

  internal var isDisplayed: Bool {
    assert(
      !requiredElements.isEmpty,
      "A screen should have at least one required element to be able to determine if it's displayed."
    )
    return requiredElements.allSatisfy { $0.exists }
  }

  @discardableResult
  internal func waitForAppearance(timeout: TimeInterval = .standardUI) throws -> Self {
    assert(
      !requiredElements.isEmpty,
      "A screen should have at least one required element to be able to wait for its appearance."
    )
    let notExistingYet: Array<XCUIElement> = requiredElements.filter { $0.exists == false }
    let expectations: Array<XCTNSPredicateExpectation> = notExistingYet.map {
      XCTNSPredicateExpectation(
        predicate: NSPredicate(format: "exists == true"),
        object: $0
      )
    }

    if expectations.isEmpty {
      return self
    }

    let result: XCTWaiter.Result = XCTWaiter().wait(for: expectations, timeout: timeout)

    if result != .completed {
      for expectation in expectations {
        guard let element = expectation.object as? XCUIElement else {
          continue
        }
        if element.exists == false {
          throw TimeOut(
            """
            Timeout while waiting for screen to appear. The following element did not appear: \(element)
            """
          )
        }
      }
      throw ScreenFailedToAppear(
        waitedForElements: notExistingYet,
        expectations: expectations,
        result: result
      )
    }

    return self
  }

  @discardableResult
  internal func scrollDown() -> Self {
    let coordinate = self.application.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
    let endCoordinate = self.application.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
    coordinate.press(forDuration: 0.05, thenDragTo: endCoordinate)
    return self
  }

  @discardableResult
  internal func findAndType(
    _ text: String,
    into: XCUIElement,
    maxIterations: UInt = 5,
    file: StaticString = #file,
    line: UInt = #line
  ) -> Self {
    let typeText: () -> Void = {
      into.tap()
      into.typeText(text)
      if self.application.buttons["Return"].exists {
        self.application.buttons["Return"].tap()
      }
    }
    var iteration: UInt = 0
    while iteration < maxIterations {
      if into.exists {
        typeText()
        return self
      }
      scrollDown()
      iteration += 1
    }
    if into.exists {
      typeText()
    }
    else {
      XCTFail(
        "Failed to find element after \(maxIterations) iterations of scrolling.",
        file: file,
        line: line
      )
    }
    return self
  }
}

fileprivate struct ScreenFailedToAppear: Error, CustomStringConvertible, CustomDebugStringConvertible {
  private let waitedForElements: Array<XCUIElement>
  private let expectations: Array<XCTNSPredicateExpectation>
  private let result: XCTWaiter.Result

  fileprivate var description: String {
    """
    ScreenFailedToAppear: Timeout while waiting for screen to appear. Result: \(result). Waited for elements: \(waitedForElements).
    Expectations: \(expectations).
    """
  }

  fileprivate var debugDescription: String { description }


  fileprivate init(
    waitedForElements: Array<XCUIElement>,
    expectations: Array<XCTNSPredicateExpectation>,
    result: XCTWaiter.Result
  ) {
    self.waitedForElements = waitedForElements
    self.expectations = expectations
    self.result = result
  }
}

enum ScreenError: Error {
  case timeout
}

