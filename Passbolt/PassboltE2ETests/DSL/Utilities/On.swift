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

/// Executes nested steps after verification if requested step is available - or after waiting for it to appear.
internal struct On<S: Screen>: UITestStep {

  internal let name: String
  private let timeout: TimeInterval
  private let screenType: S.Type
  private let builder: (S) -> Array<UITestStep>

  internal init(
    _ screenType: S.Type,
    timeout: TimeInterval = .standardUI,
    @UITestStepsBuilder _ builder: @escaping (S) -> Array<UITestStep>
  ) {
    self.name = "On \(String(describing: screenType))"
    self.timeout = timeout
    self.screenType = screenType
    self.builder = builder
  }

  @MainActor internal func execute() throws {
    guard let context: UITestFlowContext = UITestFlowContext.current else {
      XCTFail("On step used outside of UITestFlow context")
      return
    }
    let screen: S = self.screenType.init(application: context.application)
    try XCTContext.runActivity(named: "Wait for \(String(describing: self.screenType))") { _ in
      try screen.waitForAppearance(timeout: self.timeout)
      return ()
    }
    if screen.isDisplayed == false {
      throw TimeOut("Screen \(String(describing: self.screenType)) did not appear in time (\(self.timeout) seconds)")
    }
    let steps: Array<UITestStep> = self.builder(screen)
    for step in steps {
      try XCTContext.runActivity(named: step.name) { _ in
        try step.execute()
      }
    }
  }
}
