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

internal struct WaitFor: UITestStep {

  internal let name: String
  private let element: XCUIElement
  private let predicate: String
  private let timeout: TimeInterval
  private let file: StaticString
  private let line: UInt

  /// - Parameters
  /// - element: The `XCUIElement` to wait for.
  /// - predicate: NSPredicate-format string evaluated against the element. Defaults to `exists == true`.
  /// - timeout: Maximum time in seconds to wait for the predicate to become true.
  /// - description: Optional human-readable description of the step, surfaced in test reports and error messages.
  internal init(
    _ element: XCUIElement,
    predicate: String = "exists == true",
    timeout: TimeInterval = .standardUI,
    _ description: String? = nil,
    file: StaticString = #fileID,
    line: UInt = #line
  ) {
    self.name = description.map { "WaitFor: \($0)" } ?? "WaitFor"
    self.element = element
    self.predicate = predicate
    self.timeout = timeout
    self.file = file
    self.line = line
  }

  @MainActor internal func execute() throws {
    let expectation: XCTNSPredicateExpectation = .init(predicate, object: element)
    let result: XCTWaiter.Result = XCTWaiter().wait(for: [expectation], timeout: timeout)
    if result != .completed {
      throw TimeOut("Predicate for step \(name) failed after \(timeout) seconds.", file: file, line: line)
    }
  }
}

internal struct WaitForDisappearance: CombinedUITestStep {

  internal let name: String
  private let element: XCUIElement
  private let timeout: TimeInterval
  private let file: StaticString
  private let line: UInt

  internal init(
    _ element: XCUIElement,
    timeout: TimeInterval = .standardUI,
    _ description: String? = nil,
    file: StaticString = #fileID,
    line: UInt = #line
  ) {
    self.name = description ?? "WaitForDisappearance"
    self.element = element
    self.timeout = timeout
    self.file = file
    self.line = line
  }

  var steps: Array<UITestStep> {
    [
      WaitFor(
        self.element,
        predicate: "exists == false",
        timeout: self.timeout,
        self.name,
        file: self.file,
        line: self.line
      )
    ]
  }
}
