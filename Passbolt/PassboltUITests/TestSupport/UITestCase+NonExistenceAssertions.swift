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

extension UITestCase {
  /// Asserts that an element with the given identifier does not exist within a specified timeout period.
  /// If a specifier is provided, it checks for the element's non-existence within that specific UI component.
  ///
  /// - Important: If using a specifier, ensure that the specifier element exists before calling this method.
  ///   You may need to wait for the specifier to appear before asserting the non-existence of the target element.
  ///
  /// - Parameters:
  ///   - identifier: The identifier of the element to check for non-existence.
  ///   - specifier: Optional. The identifier of a containing UI component to narrow the search scope.
  ///   - timeout: The maximum time to wait for the element to not exist. Defaults to 1.0 seconds.
  ///   - file: The file in which the failure occurs. Defaults to the file name of the test case.
  ///   - line: The line number on which the failure occurs. Defaults to the line number on which the method is called.
  ///
  /// - Throws: A `TestFailure.error` if the element exists after the timeout period.
  internal final func assertNotExists(
    _ identifier: String,
    inside specifier: String? = .none,
    timeout: TimeInterval = 1.0,
    file: StaticString = #file,
    line: UInt = #line
  ) {
    do {
      let exists = try self.waitForNonExistence(
        of: identifier,
        inside: specifier,
        timeout: timeout
      )

      if exists {
        throw TestFailure.error(
          message: "Element \"\(identifier)\"\(specifier.map { " inside \"\($0)\"" } ?? "") exists, but it should not!",
          file: file,
          line: line
        )
      }
    }
    catch {
      error.asTestFailure(
        file: file,
        line: line
      )
    }
  }
  /// Waits for an element to not exist within a specified timeout period.
  ///
  /// - Parameters:
  ///   - identifier: The identifier of the element to check for non-existence.
  ///   - specifier: Optional. The identifier of a containing UI component to narrow the search scope.
  ///   - timeout: The maximum time to wait for the element to not exist.
  ///
  /// - Returns: `true` if the element still exists after the timeout, `false` if it doesn't exist.
  private func waitForNonExistence(
    of identifier: String,
    inside specifier: String?,
    timeout: TimeInterval
  ) throws -> Bool {
    let element: XCUIElement
    if let specifier = specifier {
      element = self.application
        .descendants(matching: .any)
        .element(matching: .any, identifier: specifier)
        .descendants(matching: .any)
        .element(matching: .any, identifier: identifier)
    }
    else {
      element = self.application
        .descendants(matching: .any)
        .element(matching: .any, identifier: identifier)
    }

    let start = Date()
    while Date().timeIntervalSince(start) < timeout {
      if !element.exists {
        return false
      }
      RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
    }
    return element.exists
  }
}
