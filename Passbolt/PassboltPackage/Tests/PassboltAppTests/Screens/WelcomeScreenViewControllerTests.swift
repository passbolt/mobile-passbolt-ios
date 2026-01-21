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

import FeatureScopes
import SharedUIComponents
import TestExtensions

@testable import Display
@testable import PassboltApp

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class WelcomeScreenViewControllerTests: FeaturesTestCase {

  func test_viewState_alert_isNil_initially() async throws {
    let tested: WelcomeScreenViewController = try self.testedInstance(
      context: ()
    )

    XCTAssertNil(tested.viewState.value.alert)
  }

  func test_showNoAccountAlert_setsAlert() async throws {
    let tested: WelcomeScreenViewController = try self.testedInstance(
      context: ()
    )

    tested.showNoAccountAlert()

    XCTAssertNotNil(tested.viewState.value.alert)
    XCTAssertEqual(
      "welcome.no.account.alert.title",
      tested.viewState.value.alert?.title
    )
    XCTAssertEqual(
      "welcome.no.account.alert.text",
      tested.viewState.value.alert?.message
    )
  }

  func test_openHelpMenu_navigatesToHelp() async throws {
    patch(
      \NavigationToHelpMenu.performAnimated,
      with: always(self.mockExecuted())
    )

    let tested: WelcomeScreenViewController = try self.testedInstance(
      context: ()
    )

    await tested.openHelpMenu()

    XCTAssertTrue(self.mockWasExecuted)
  }

  func test_goToScanning_navigatesToAccountImportInfo() async throws {
    patch(
      \NavigationToAccountImportInfo.performAnimated,
      with: always(self.mockExecuted())
    )

    let tested: WelcomeScreenViewController = try self.testedInstance(
      context: ()
    )

    await tested.goToScanning()

    XCTAssertTrue(self.mockWasExecuted)
  }
}
