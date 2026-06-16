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

/// Adds a delay before executing the next step. This can be useful to wait for animations to complete or for elements to appear on the screen.
internal struct Delay: UITestStep {

  let name: String
  private let timeout: TimeInterval

  /// - Parameters:
  /// - `timeout`: The duration of the delay in seconds.
  /// - `description`: Optional human-readable description of the step, surfaced in test reports.
  internal init(
    _ timeout: TimeInterval,
    _ description: String? = nil
  ) {
    self.name = description ?? "Delay \(timeout)s"
    self.timeout = timeout
  }

  @MainActor internal func execute() throws {
    let nonexistingElement: XCUIElement = self.application.otherElements[UUID().uuidString]
    _ = nonexistingElement.waitForExistence(timeout: self.timeout)
    debugPrint("Delay of \(self.timeout) seconds completed")
  }
}
