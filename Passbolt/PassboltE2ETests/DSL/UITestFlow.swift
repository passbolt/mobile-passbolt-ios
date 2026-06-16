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

internal struct UITestFlow {

  private let name: String
  private let application: XCUIApplication
  private let steps: Array<UITestStep>

  internal init(
    _ name: String = #function,
    application: XCUIApplication,
    @UITestStepsBuilder _ builder: () -> Array<UITestStep>
  ) {
    self.name = name
    self.application = application
    self.steps = builder()
  }

  @MainActor internal func run(file: StaticString = #file, line: UInt = #line) {
    let context: UITestFlowContext = .init(application: self.application)
    UITestFlowContext.$current.withValue(context) {
      XCTContext.runActivity(named: self.name) { _ in
        for step in self.steps {
          XCTContext.runActivity(named: step.name) { _ in
            do {
              try step.execute()
            }
            catch {
              let failureFile: StaticString
              let failureLine: UInt
              if let located = error as? LocatedError {
                failureFile = located.file
                failureLine = located.line
              }
              else {
                failureFile = file
                failureLine = line
              }
              XCTFail("Step '\(step.name)' failed: \(error)", file: failureFile, line: failureLine)
              return
            }
          }
        }
      }
    }
  }
}
