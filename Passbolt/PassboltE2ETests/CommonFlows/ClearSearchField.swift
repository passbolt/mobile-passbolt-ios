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

/// Clears the home search field and drops its focus so the filter menu button becomes available again.
///
/// While the search field holds text and/or keeps keyboard focus, the leading filter menu button
/// (`search.view.menu`) is replaced by the search icon. The trailing clear/dismiss button
/// (`search.view.account`) first clears the text and then, on a second tap, drops the focus, which
/// restores the menu button. This is a no-op when the field is already empty and unfocused.
internal struct ClearSearchField: UITestStep {

  internal let name: String = "ClearSearchField"

  @MainActor internal func execute() throws {
    let menuButton: XCUIElement = self.application.buttons["search.view.menu"]
    let clearButton: XCUIElement = self.application.buttons["search.view.account"]
    let maxIterations: Int = 3
    var iteration: Int = 0
    while menuButton.exists == false && iteration < maxIterations {
      guard clearButton.exists else { break }
      clearButton.tap()
      let predicate: NSPredicate = .init(format: "exists == true")
      let expectation: XCTNSPredicateExpectation = .init(predicate: predicate, object: menuButton)
      _ = XCTWaiter().wait(for: [expectation], timeout: 1)
      iteration += 1
    }
  }
}
