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

/// Executes the nested steps only when the given condition evaluates to `true`, otherwise it is a no-op.
/// The condition is evaluated lazily when the step runs, so it reflects the current UI state.
internal struct When: UITestStep {

  internal let name: String
  private let condition: () -> Bool
  private let steps: () -> Array<UITestStep>

  /// - Parameters:
  ///   - condition: A boolean condition evaluated when the step is executed.
  ///   - description: Optional human-readable description of the step, surfaced in test reports.
  ///   - steps: A builder that returns the steps to execute when the condition holds.
  internal init(
    _ condition: @autoclosure @escaping () -> Bool,
    _ description: String? = nil,
    @UITestStepsBuilder _ steps: @escaping () -> Array<UITestStep>
  ) {
    self.name = description.map { "When: \($0)" } ?? "When"
    self.condition = condition
    self.steps = steps
  }

  @MainActor internal func execute() throws {
    guard self.condition() else { return }
    for step in self.steps() {
      try XCTContext.runActivity(named: step.name) { _ in
        try step.execute()
      }
    }
  }
}
