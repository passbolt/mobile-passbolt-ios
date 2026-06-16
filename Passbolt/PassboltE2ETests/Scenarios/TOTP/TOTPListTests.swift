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
final internal class TOTPListTests: UITestCase {

  /// https://passbolt.testrail.io/index.php?/cases/view/9164
  func test_totpPageShowsObfuscatedResources() async throws {
    let totp: TOTPTestData = .standaloneTOTP
    let application: XCUIApplication = await self.application

    await executeSteps {
      SelectTOTPTab()
      On(TOTPListScreen.self) { screen in
        TypeText(totp.resourceName, into: screen.searchField, "Search TOTP")
        WaitFor(application.staticTexts[totp.resourceName], timeout: .networkCall, "TOTP resource")
        Verify(screen.totpResourceIcon(identifier: totp.iconIdentifier).exists, "TOTP icon exists")
        Verify(application.staticTexts[totp.resourceName].exists, "TOTP name visible")
        Verify(screen.obfuscationMarker.exists, "TOTP value obfuscated")
        Verify(screen.eyeIcon.exists, "Show eye icon exists")
        Verify(screen.moreButton.exists, "More menu exists")
      }
    }
  }

  /// https://passbolt.testrail.io/index.php?/cases/view/9165
  func test_canRevealTOTPValue() async throws {
    let totp: TOTPTestData = .standaloneTOTP
    let application: XCUIApplication = await self.application

    await executeSteps {
      SelectTOTPTab()
      On(TOTPListScreen.self) { screen in
        // Go through contextual menu, as UI tests sometimes mis-tap the eye icon and copies TOTP value instead.
        OpenTOTPContextualMenu(name: totp.resourceName)
        Tap(application.buttons["Show TOTP"], "Reveal TOTP")
        WaitFor(screen.totpDigits, timeout: .networkCall, "TOTP digits")
        Verify(screen.totpDigits.exists, "TOTP digits visible")
        Verify(screen.timerCircle.exists, "Timer visible")
      }
    }
  }

  /// https://passbolt.testrail.io/index.php?/cases/view/9167
  func test_totpValueObfuscatedAfterAction() async throws {
    let totp: TOTPTestData = .standaloneTOTP
    let application: XCUIApplication = await self.application

    await executeSteps {
      SelectTOTPTab()
      On(TOTPListScreen.self) { screen in
        // Go through contextual menu, as UI tests sometimes mis-tap the eye icon and copies TOTP value instead.
        OpenTOTPContextualMenu(name: totp.resourceName)
        Tap(application.buttons["Show TOTP"], "Reveal TOTP")
        WaitFor(screen.totpDigits, timeout: .standardUI, "TOTP digits")
        Tap(screen.moreButton, "Open menu")
        Verify(application.staticTexts["••• •••"].exists, "TOTP re-obfuscated")
      }
    }
  }
}
