//
// Passbolt - Open source password manager for teams
// Copyright (c) 2024 Passbolt SA
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

internal final class CreateTOTPTests: UITestCase {

  override func beforeEachTestCase() throws {
    try signIn()
    try tapTab("TOTP", timeout: 10.0)
  }

  ///    https://passbolt.testrail.io/index.php?/cases/view/9179
  @MainActor func test_asALoggedInUserICanAddAManuallyCreatedStandaloneTotpResource() throws {
    let randomName: String = "TOTP ".withRandomSuffix()
    // Steps performed as common flow:
    // Given   that I am a [logged in user on the TOTP page with resources]
    // And I am on the “Create a resource” page
    // And I filled out at least the mandatory field with a valid entry
    // When    I click on the “Create” primary button
    createTOTP(named: randomName)
    //        Then    I see the main TOTP page
    let mainTOTPPage: MainTOTPScreen = screen()
    mainTOTPPage.ensureDisplayed()
    mainTOTPPage.search(for: randomName)

    //        And I see the TOTP resource I created manually
    assertPresentsString(matching: randomName)
    //        And I see the TOTP value hidden
    assertExists("••• •••", inside: "totp.collection.view")
  }
}
