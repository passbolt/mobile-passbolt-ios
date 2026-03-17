//
// Passbolt - Open source password manager for teams
// Copyright (c) 2023 Passbolt SA
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

import Foundation

final class TransferAccountTests: UITestCase {

  var password: String = MockAccount.automation.password

  private var mainScreen: MainScreen { screen() }
  private var settingsScreen: SettingsScreen { screen() }

  override func beforeEachTestCase() throws {
    try signIn()
    mainScreen
      .ensureDisplayed()
      .openSettings()
      .ensureDisplayed()
  }

  /// https://passbolt.testrail.io/index.php?/cases/view/8147
  func test_asAUserICanSeeAnExplanationOnHowToTransferAnExistingAccount() throws {
    settingsScreen
      .openAccounts()  //  Given   I’m logged in user on Accounts screen
      .ensureDisplayed()
      .tapTransferButton()  //  When    I click “Transfer account to another device”

    //  Then  the “Transfer account details” explanation screen is presented with a corresponding title
    assertPresentsString(matching: "Transfer account details")
    //  And the screen has an arrow button on the top left to go back to the previous screen
    XCTAssertTrue(application.buttons["ArrowLeft"].isHittable)

    //  And   it has an explanation of the different steps of the transfer process

    assertPresentsString(
      matching: "Scan the qr codes sequence"
    )
    //  And   an illustration giving some context about the process
    assertExists("transfer.account.import.image")
    //  And   a "Start transfer" primary action button
    assertInteractive("Start transfer")
  }

  /// https://passbolt.testrail.io/index.php?/cases/view/8150
  func test_asAMobileUserIShouldSeeEnterYourPassphraseScreenWhenTransferStarted() throws {
    //    Given I’m on mobile without any biometry enabled for the Passbolt app
    //    And   I’m logged in user on “Transfer account details” screen
    settingsScreen
      .openAccounts()
      .ensureDisplayed()
      .tapTransferButton()
    //    When  I click “Start Transfer”
    try tap("transfer.account.export.scan.qr.button")
    //    Then  I see a "Enter your passphrase" page
    let authenticationScreen: AuthenticationScreen = screen()
    authenticationScreen
      .set(mode: .unlock)
      .ensureDisplayed()
      //    And   I see my current user's name
      .assertLabel(equals: "\(MockAccount.automation.firstName) \(MockAccount.automation.lastName)")

      //    And   I see my current user's email
      .assertEmail(equals: MockAccount.automation.username)
      //    And   I see the url of the server
      .assertURLLabel(equals: MockAccount.automation.domain)
  }

  /// https://passbolt.testrail.io/index.php?/cases/view/8151
  func test_asAUserIShouldSeeTransferringYourAccountDetailsScreen() throws {
    settingsScreen
      .openAccounts()
      .ensureDisplayed()
      .tapTransferButton()
    //    Given I’m on “Transfer account details” process
    try tap("transfer.account.export.scan.qr.button")
    //    When  I click “Confirm passphrase” or provide valid biometric authentication
    let authenticationScreen: AuthenticationScreen = screen()
    try authenticationScreen
      .set(mode: .unlock)
      .ensureDisplayed()
      .enterPassphrase(password)
      .tapSignIn()

    //    Then  I see a “Transferring your account details” page with corresponding title
    try waitForElement("Transfer account details")
    assertPresentsString(
      matching: "Transfer account details"
    )
    //    And   I see a first QR code
    assertInteractive("transfer.account.export.qrcode.image")
    //    And   I see a “Cancel transfer” primary action button
    assertInteractive("transfer.account.export.cancel.button")
  }

  /// https://passbolt.testrail.io/index.php?/cases/view/8153
  func test_asAUserINeedToConfirmToStopTheQrCodePresentation() throws {
    //      Given   I’m on a “Transferring your account details” page
    settingsScreen
      .openAccounts()
      .ensureDisplayed()
      .tapTransferButton()

    try tap("transfer.account.export.scan.qr.button")

    let authenticationScreen: AuthenticationScreen = screen()
    try authenticationScreen
      .set(mode: .unlock)
      .ensureDisplayed()
      .enterPassphrase(password)
      .tapSignIn()

    //      When    I click “Cancel Transfer” button
    try tap("transfer.account.export.cancel.button")
    //      Then    I see a confirmation dialog
    //      And     I see a message titled “Are you sure?”
    assertPresentsString(
      matching: "Are you sure?"
    )
    //      And     I see some explanation
    assertPresentsString(
      matching: "If you leave, you will need to scan QR codes again."
    )
    //      And     I see a “Cancel” and “Stop transfer” options
    assertInteractive("Cancel")
    assertInteractive("Stop transfer")
  }

  /// https://passbolt.testrail.io/index.php?/cases/view/8154
  func test_asAUserICanStopTheQrCodePresentation() throws {
    //       Given   I’m on a “Transferring your account details” page
    //       And     I see a prompt with “Cancel”                   // tested before
    //       And     I see action buttons                           // tested before
    try openStopTransferPrompt()
    //       When    I click on the “Stop transfer” button
    try tap("Stop transfer")
    //       Then    the prompt is dismissed
    assertNotExists("Stop transfer")
    //       And     the process is stopped
    try waitForElement("FailureMark")
    assertNotExists("Transfer account details")
    //       And     I see “Failed feedback” screen
    assertInteractive("Something went wrong!")
    //       And     I see “Transfer cancelled” explanation
    assertInteractive("Operation has been cancelled.")
  }

  // https://passbolt.testrail.io/index.php?/cases/view/8156
  func test_asAUserIShouldSeeAFailedFeedbackInCaseOfErrorDuringQrCodesSequence() throws {
    //      Given   I’m on a “Transferring your account details” page
    //      When    there is an error during the transfer process
    try openTransferFailureScreen()
    //      Then    I see an unsuccessful “Something went wrong!” screen with a corresponding title
    assertInteractive("Something went wrong!")
    //      And     I see an unsuccessful illustration
    assertInteractive("FailureMark")
    //      And     I see an error message
    assertInteractive("Operation has been cancelled.")
    //      And     I see a “Go back to my account”
    assertInteractive("Try again")
  }

  // https://passbolt.testrail.io/index.php?/cases/view/C8157
  func test_asAUserICouldGoBackFromAFailedFeedbackInCaseOfErrorDuringQrCodesSequence() throws {
    //      Given   I’m on a “Transferring your account details” page
    //      And     there was an error during the transfer process
    try openTransferFailureScreen()
    //      And     I see an unsuccessful “Something went wrong!” screen
    assertInteractive("Something went wrong!")
    //      When    I click a “Go back to my account”
    try tap("Try again")
    //      Then    I see the Account details page
    assertPresentsString(
      matching: "Transfer account details"
    )
  }

  private func openStopTransferPrompt() throws {
    settingsScreen
      .openAccounts()
      .ensureDisplayed()
      .tapTransferButton()

    try tap("transfer.account.export.scan.qr.button")

    let authenticationScreen: AuthenticationScreen = screen()
    try authenticationScreen
      .set(mode: .unlock)
      .ensureDisplayed()
      .enterPassphrase(password)
      .tapSignIn()

    try tap("transfer.account.export.cancel.button")
  }

  /// there is cancel process tested here now - testing a real backend error would be possible only on dedicated backend
  private func openTransferFailureScreen() throws {
    try openStopTransferPrompt()
    try tap("Stop transfer")
  }
}
