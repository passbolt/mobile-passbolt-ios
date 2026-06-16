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

extension UITestStep {

  /// Repeats the step until it succeeds or reaches the maximum number of iterations.
  /// If `errors` is specified, only catches errors of the specified types, otherwise catches all errors.
  internal func `repeat`(onErrors errors: Array<Error.Type>? = .none, maxIterations: UInt) -> UITestStep {
    let repeatStep = Repeat(self, errors: errors, maxIterations: maxIterations)
    return repeatStep
  }
}

private struct Repeat: UITestStep {
  let name: String
  private let step: UITestStep
  private let maxIterations: UInt
  private let errorsToCatch: Array<Error.Type>?

  fileprivate init(_ step: UITestStep, errors: Array<Error.Type>?, maxIterations: UInt) {
    self.name = "Repeat \(step.name) \(maxIterations) times"
    self.step = step
    self.errorsToCatch = errors
    self.maxIterations = maxIterations
  }

  @MainActor func execute() throws {
    for i in 0..<maxIterations {
      do {
        let executed: Bool = try XCTContext.runActivity(named: "Repeating step: \(step.name) (\(i))") { _ in
          try step.execute()
          return true
        }
        if executed {
          break
        }
      }
      catch {
        guard let errorsToCatch else {
          // if no error specified - catch all
          continue
        }
        if errorsToCatch.contains(where: { $0 == type(of: error) }) {
          continue
        }
        else {
          throw error
        }
      }
    }
  }
}
