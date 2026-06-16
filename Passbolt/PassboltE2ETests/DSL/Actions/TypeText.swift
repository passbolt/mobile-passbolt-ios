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

internal struct TypeText: UITestStep {

  internal let name: String
  private let text: String
  private let element: XCUIElement
  private let file: StaticString
  private let line: UInt

  /// - Parameters:
  ///  - text: The text to type into the element.
  ///  - element: The target `XCUIElement` receiving the text.
  ///  - description: Optional human-readable description of the step, surfaced in test reports.
  internal init(
    _ text: String,
    into element: XCUIElement,
    _ description: String? = nil,
    file: StaticString = #fileID,
    line: UInt = #line
  ) {
    self.name = description.map { "TypeText: \($0)" } ?? "TypeText"
    self.text = text
    self.element = element
    self.file = file
    self.line = line
  }

  @MainActor internal func execute() throws {
    try ensureExists(element, file: file, line: line)
    guard text.isEmpty == false else { return }
    self.element.tap()
    if self.element.hasKeyboardFocus == false {
      // sometimes first tap dismisses snack bar or other overlay, so we need to tap again to focus the element
      let maxIterations = 3
      var iteration = 0
      while iteration < maxIterations {
        let predicate: NSPredicate = .init(format: "hasKeyboardFocus == true")
        let expectation: XCTNSPredicateExpectation = .init(predicate: predicate, object: self.element)
        _ = XCTWaiter.wait(for: [expectation], timeout: 1)
        if self.element.hasKeyboardFocus == false {
          self.element.tap()
          iteration += 1
        }
        else {
          break
        }
      }
    }
    // With animations disabled, the keyboard reports focus before it can reliably accept input,
    // so a single fast typeText() can drop the first 1-2 characters. Clear + type + verify length;
    // for secure fields `value` is a bullet string whose length equals the real text length.
    // First try fast typing up to 3 times; if that still fails, fall back to slow per-character
    // typing (also up to 3 times) before giving up.
    let maxFastAttempts: Int = 3
    var fastAttempt: Int = 0
    while fastAttempt < maxFastAttempts {
      self.clearField()
      self.element.typeText(self.text)
      if self.typedLengthMatches() { return }
      fastAttempt += 1
    }
    let maxSlowAttempts: Int = 3
    var slowAttempt: Int = 0
    while slowAttempt < maxSlowAttempts {
      self.clearField()
      for char in self.text {
        self.element.typeText(String(char))
        usleep(10_000)  // 10ms between chars to mimic real typing and let the UI catch up
      }
      if self.typedLengthMatches() { return }
      slowAttempt += 1
    }
    let finalLength: Int = ((self.element.value as? String)?.count) ?? 0
    XCTFail(
      "TypeText '\(self.name)' verification failed: expected length \(self.text.count), got \(finalLength)",
      file: self.file,
      line: self.line
    )
  }

  @MainActor private func clearField() {
    let currentValue: String = (self.element.value as? String) ?? ""
    guard currentValue.isEmpty == false else { return }
    self.element.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count))
  }

  @MainActor private func typedLengthMatches() -> Bool {
    ((self.element.value as? String)?.count ?? 0) == self.text.count
  }
}

internal struct SlowTypeText: UITestStep {

  internal let name: String
  private let text: String
  private let element: XCUIElement
  private let file: StaticString
  private let line: UInt

  /// - Parameters:
  ///  - text: The text to type into the element.
  ///  - element: The target `XCUIElement` receiving the text.
  ///  - description: Optional human-readable description of the step, surfaced in test reports.
  internal init(
    _ text: String,
    into element: XCUIElement,
    _ description: String? = nil,
    file: StaticString = #fileID,
    line: UInt = #line
  ) {
    self.name = description.map { "TypeText: \($0)" } ?? "TypeText"
    self.text = text
    self.element = element
    self.file = file
    self.line = line
  }

  @MainActor internal func execute() throws {
    try ensureExists(element, file: file, line: line)
    guard text.isEmpty == false else { return }
    self.element.tap()
    // Type text character by character with a small delay to mimic real typing and allow UI to react
    for char in text {
      self.element.typeText(String(char))
      usleep(10_000) // 10ms between chars
    }
  }
}

private struct DismissKeyboard: UITestStep {

  private let after: UITestStep
  private let file: StaticString
  private let line: UInt

  fileprivate init(after: UITestStep, file: StaticString, line: UInt) {
    self.after = after
    self.file = file
    self.line = line
  }

  @MainActor internal func execute() throws {
    try after.execute()
    if self.application.keyboards.count > 0, self.application.keyboards.buttons["Return"].exists
    {
      self.application.keyboards.buttons["Return"].tap()
    }
  }
}

extension UITestStep {

  internal func dismissKeyboardIfNeeded(file: StaticString = #fileID, line: UInt = #line) -> some UITestStep {
    DismissKeyboard(after: self, file: file, line: line)
  }
}
