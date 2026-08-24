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

  /// Element identifying the screen regardless of how its content is scrolled - typically a toolbar item,
  /// which stays in the hierarchy while the content below it scrolls away.
  ///
  /// Screens with scrollable content should override it. When the anchor is present but the required
  /// elements are not, the screen is displayed and merely scrolled, so the appearance check scrolls its
  /// content back to the top and validates again instead of failing. Content scrolled out of view is
  /// dropped from the accessibility hierarchy on small devices (iPhone SE), so a screen returned to in a
  /// scrolled state - i.e. after going back from a screen opened from its bottom - would otherwise look
  /// like it never appeared.
  internal var scrollableContentAnchor: XCUIElement? {
    .none
  }

  /// Slice of an appearance wait, after which the scroll position is reconsidered.
  private static let appearancePollInterval: TimeInterval = 1

  /// Upper bound of scroll gestures used to bring the content of a screen back to its top.
  private static let maxScrollToTopSwipeCount: UInt = 8

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
    let deadline: Date = .init(timeIntervalSinceNow: timeout)

    while true {
      // A screen left scrolled down keeps its required elements out of the hierarchy on small devices,
      // so reset the scroll position before deciding that it is not displayed.
      scrollContentToTopIfNeeded()
      if isDisplayed {
        return self
      }
      let remainingTime: TimeInterval = deadline.timeIntervalSinceNow
      if remainingTime <= 0 {
        break
      }
      // Waiting in slices allows the screen to be scrolled back to the top as soon as it shows up,
      // instead of only after the whole timeout has elapsed.
      try? awaitRequiredElements(timeout: min(remainingTime, Screen.appearancePollInterval))
    }

    // Final attempt, reporting which of the required elements are missing.
    try awaitRequiredElements(timeout: Screen.appearancePollInterval)

    return self
  }

  private func awaitRequiredElements(timeout: TimeInterval) throws {
    let notExistingYet: Array<XCUIElement> = requiredElements.filter { $0.exists == false }
    let expectations: Array<XCTNSPredicateExpectation> = notExistingYet.map {
      XCTNSPredicateExpectation(
        predicate: NSPredicate(format: "exists == true"),
        object: $0
      )
    }

    if expectations.isEmpty {
      return
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
  }

  /// Brings the content of the screen back to its top when the screen is recognized by its
  /// `scrollableContentAnchor` while some of its required elements are missing - which means the screen
  /// is displayed and only scrolled away. Does nothing for screens without an anchor, and costs no
  /// gesture when the required elements are already in place.
  private func scrollContentToTopIfNeeded() {
    guard
      let anchor: XCUIElement = self.scrollableContentAnchor,
      anchor.exists
    else { return }

    var swipeCount: UInt = 0
    while swipeCount < Screen.maxScrollToTopSwipeCount && !isDisplayed {
      scrollUp()
      swipeCount += 1
    }
  }

  @discardableResult
  internal func scrollUp() -> Self {
    let coordinate: XCUICoordinate = self.application.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
    let endCoordinate: XCUICoordinate = self.application.coordinate(
      withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8)
    )
    coordinate.press(forDuration: 0.05, thenDragTo: endCoordinate)
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

