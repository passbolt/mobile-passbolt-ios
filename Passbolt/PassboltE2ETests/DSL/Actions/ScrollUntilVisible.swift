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

internal struct ScrollUntilVisible: UITestStep {

  internal let name: String
  private let element: XCUIElement?
  private let maxSwipeCount: Int
  private let file: StaticString
  private let line: UInt

  /// - Parameters:
  /// - `element` - The `XCUIElement` to scroll into view.
  /// - `maxSwipeCount` - Maximum number of scroll gestures before giving up. Defaults to 10.
  /// - `description` - Optional human-readable description of the step, surfaced in test reports and error messages.
  internal init(
    _ element: XCUIElement?,
    maxSwipeCount: Int = 10,
    _ description: String? = nil,
    file: StaticString = #fileID,
    line: UInt = #line
  ) {
    self.name = description.map { "ScrollUntilVisible: \($0)" } ?? "ScrollUntilVisible"
    self.element = element
    self.maxSwipeCount = maxSwipeCount
    self.file = file
    self.line = line
  }

  @MainActor internal func execute() throws {
    guard let element: XCUIElement = self.element else {
      throw ElementMissing("Element for '\(name)' is nil", file: file, line: line)
    }
    // Short drag instead of swipeUp() so we don't overshoot elements that sit just below the fold.
    let start: XCUICoordinate = application.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6))
    let end: XCUICoordinate = application.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35))
    var swipeCount: Int = 0
    while !element.isHittable && swipeCount < maxSwipeCount {
      start.press(forDuration: 0.05, thenDragTo: end)
      swipeCount += 1
    }
    // one more time, as element can be close to bottom edge
    start.press(forDuration: 0.05, thenDragTo: end)
  }
}
