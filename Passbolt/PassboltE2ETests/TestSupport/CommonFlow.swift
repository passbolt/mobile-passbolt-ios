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

@MainActor
internal class CommonFlow<StartingScreen, Input> where StartingScreen: Screen {

  internal let application: XCUIApplication

  internal var displayName: String {
    String(describing: Self.self)
  }

  internal var initialScreenTimeout: TimeInterval { 5.0 }

  internal init(
    application: XCUIApplication
  ) {
    self.application = application
  }

  internal final func execute(with input: Input) throws {
    let startingScreen: StartingScreen = .init(application: self.application)
    try XCTContext.runActivity(
      named: "Verifying if screen \(String(describing: StartingScreen.self)) is displayed"
    ) { _ in
      if startingScreen.isDisplayed == false {
        try startingScreen.waitForAppearance(timeout: initialScreenTimeout)
      }
    }

    try XCTContext.runActivity(named: "Executing flow: \(displayName)") { _ in
      try executeSteps(from: startingScreen, with: input)
    }
  }

  internal func executeSteps(from _: StartingScreen, with _: Input) throws {
    assertionFailure("executeSteps() should be implemented by subclasses")
  }
}
