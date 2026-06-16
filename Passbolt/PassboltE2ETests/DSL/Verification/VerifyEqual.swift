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

internal struct VerifyEqual<T: Equatable>: UITestStep {

  internal let name: String
  private let actual: () -> T
  private let expected: () -> T
  private let file: StaticString
  private let line: UInt

  ///  Creates a verification step that checks if the actual value is equal to the expected value.
  /// - Parameters:
  ///   - actual: An autoclosure that produces the actual value to be compared.
  ///   - expected: An autoclosure that produces the expected value to be compared against.
  ///   - description: Optional human-readable description of the step, surfaced in test reports and error messages.
  internal init(
    _ actual: @autoclosure @escaping () -> T,
    _ expected: @autoclosure @escaping () -> T,
    _ description: String? = nil,
    file: StaticString = #fileID,
    line: UInt = #line
  ) {
    self.name = description.map { "VerifyEqual: \($0)" } ?? "VerifyEqual"
    self.actual = actual
    self.expected = expected
    self.file = file
    self.line = line
  }

  @MainActor internal func execute() throws {
    let actual: T = self.actual()
    let expected: T = self.expected()
    if actual != expected {
      throw AssertionFailure(
        "VerifyEqual failed: \(self.name); expected: \(expected), actual: \(actual).",
        file: self.file,
        line: self.line
      )
    }
  }
}

