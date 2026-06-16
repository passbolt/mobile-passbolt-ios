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

/// Performs predcondition check before executing a test step, and retries if the check fails, up to a maximum number of attempts.
internal struct Precondition: UITestStep {

  let name: String
  private let maxAttempsCount: Int
  private let check: () -> Array<UITestStep>
  private let retry: () -> Array<UITestStep>

  private let file: StaticString
  private let line: UInt

  /// - Parameters:
  ///   - name: The name of the precondition, used for logging and error messages
  ///   - maxAttempsCount: The maximum number of attempts to perform the check and retry steps before throwing an error
  ///   - check: A closure that returns an array of `UITestStep` to execute for checking the precondition.
  ///   - retry: A closure that returns an array of `UITestStep` to execute for retrying the precondition if the check fails, for example, to reset the app state
  internal init(
    _ name: String,
    maxAttempsCount: Int = 3,
    @UITestStepsBuilder check: @escaping () -> Array<UITestStep>,
    @UITestStepsBuilder retry: @escaping () -> Array<UITestStep>,
    file: StaticString = #fileID,
    line: UInt = #line
  ) {
    self.name = name
    self.maxAttempsCount = maxAttempsCount
    self.check = check
    self.retry = retry
    self.file = file
    self.line = line
  }

  @MainActor func execute() throws {
    for attempt in 0..<self.maxAttempsCount {
      let result = try XCTContext.runActivity(named: "Running precondition: \(name) attempts: \(attempt)") { _ in
        do {
          for step in self.check() {
            try step.execute()
            return true
          }
        }
        catch {
          for step in self.retry() {
            try step.execute()
          }
        }

        return false
      }

      if result {
        return
      }
    }
    throw PreconditionFailure(
      "Precondition '\(name)' failed after \(maxAttempsCount) attempts",
      file: self.file,
      line: self.line
    )
  }
}

extension Precondition {

  internal struct PreconditionFailure: Error {

    internal let message: String
    internal let file: StaticString
    internal let line: UInt

    internal init(_ message: String, file: StaticString = #fileID, line: UInt = #line) {
      self.message = message
      self.file = file
      self.line = line
    }
  }
}
