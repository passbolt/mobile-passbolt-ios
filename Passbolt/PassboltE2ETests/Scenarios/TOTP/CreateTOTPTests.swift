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
final internal class CreateTOTPTests: UITestCase {

  /// https://passbolt.testrail.io/index.php?/cases/view/9179
  func test_createManualStandaloneTOTP() async throws {
    let randomName: String = "TOTP ".withRandomSuffix()
    let application: XCUIApplication = await self.application

    await executeSteps {
      Delay(.slowNetworkCall, "Wait for app to be ready")
      SelectTOTPTab()
      CreateTOTP(named: randomName)
      VerifySnackBarMessage(expectedMessage: "New password has been created")
      On(TOTPListScreen.self, timeout: .longNetworkCall) { screen in
        TypeText(randomName, into: screen.searchField, "Search created TOTP")
        WaitFor(application.staticTexts[randomName], timeout: .longNetworkCall, "Created TOTP visible")
        Verify(application.staticTexts[randomName].exists, "TOTP name visible")
        Verify(screen.obfuscationMarker.exists, "TOTP value hidden")
      }
    }
  }
}
