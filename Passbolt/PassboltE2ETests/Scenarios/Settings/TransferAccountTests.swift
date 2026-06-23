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
final internal class TransferAccountTests: UITestCase {

  /// https://passbolt.testrail.io/index.php?/cases/view/8147
  func test_asAUserICanSeeAnExplanationOnHowToTransferAnExistingAccount() async throws {
    await executeSteps {
      NavigateToTransferDetails()
      On(TransferAccountDetailsScreen.self) { transfer in
        Verify(transfer.title.exists, "Title is displayed")
        Verify(transfer.backButton.isHittable, "Back button is hittable")
        Verify(transfer.scanDescription.exists, "Scan description is displayed")
        Verify(transfer.illustration.exists, "Illustration is displayed")
        Verify(transfer.startTransferButton.exists, "Start transfer button exists")
      }
    }
  }

  /// https://passbolt.testrail.io/index.php?/cases/view/8150
  func test_asAMobileUserIShouldSeeEnterYourPassphraseScreenWhenTransferStarted() async throws {
    let account: MockAccount = .automation
    await executeSteps {
      NavigateToTransferDetails()
      On(TransferAccountDetailsScreen.self) { transfer in
        Tap(transfer.startTransferButton, "Start transfer")
      }
      On(TransferPassphraseScreen.self) { passphrase in
        Verify(passphrase.title.exists, "Title is displayed")
        Verify(
          passphrase.application.staticTexts["\(account.firstName) \(account.lastName)"].exists,
          "User name is displayed"
        )
        VerifyEqual(passphrase.accountName.label, account.username, "Email matches")
        VerifyEqual(passphrase.accountURL.label, account.domain, "URL matches")
      }
    }
  }

  /// https://passbolt.testrail.io/index.php?/cases/view/8151
  func test_asAUserIShouldSeeTransferringYourAccountDetailsScreen() async throws {
    await executeSteps {
      NavigateToTransferQRCode()
      On(TransferQRCodeScreen.self) { qrCode in
        Verify(qrCode.title.exists, "Title is displayed")
        Verify(qrCode.qrCodeImage.exists, "QR code image is displayed")
        Verify(qrCode.cancelButton.exists, "Cancel button is displayed")
      }
    }
  }

  /// https://passbolt.testrail.io/index.php?/cases/view/8153
  func test_asAUserINeedToConfirmToStopTheQrCodePresentation() async throws {
    await executeSteps {
      NavigateToTransferQRCode()
      On(TransferQRCodeScreen.self) { qrCode in
        Tap(qrCode.cancelButton, "Cancel transfer")
        With(qrCode.confirmationAlert, as: Alert.self) { alert in
          Verify(alert.title == "Are you sure?", "Alert title")
          Verify(alert.message == "If you leave, you will need to scan QR codes again.", "Alert message")
          Verify(alert.buttons["Cancel"]?.exists == true, "Cancel button exists")
          Verify(alert.buttons["Stop transfer"]?.exists == true, "Stop transfer button exists")
        }
      }
    }
  }

  /// https://passbolt.testrail.io/index.php?/cases/view/8154
  func test_asAUserICanStopTheQrCodePresentation() async throws {
    await executeSteps {
      NavigateToTransferQRCode()
      On(TransferQRCodeScreen.self) { qrCode in
        Tap(qrCode.cancelButton, "Cancel transfer")
        With(qrCode.confirmationAlert, as: Alert.self) { alert in
          Tap(alert.buttons["Stop transfer"]!, "Stop transfer")
        }
      }
      On(TransferFailureScreen.self) { failure in
        Verify(failure.failureImage.exists, "Failure image is displayed")
        Verify(failure.title.exists, "Title is displayed")
        Verify(failure.errorMessage.exists, "Error message is displayed")
      }
    }
  }

  /// https://passbolt.testrail.io/index.php?/cases/view/8156
  func test_asAUserIShouldSeeAFailedFeedbackInCaseOfErrorDuringQrCodesSequence() async throws {
    await executeSteps {
      NavigateToTransferQRCode()
      On(TransferQRCodeScreen.self) { qrCode in
        Tap(qrCode.cancelButton, "Cancel transfer")
        With(qrCode.confirmationAlert, as: Alert.self) { alert in
          Tap(alert.buttons["Stop transfer"]!, "Stop transfer")
        }
      }
      On(TransferFailureScreen.self) { failure in
        Verify(failure.title.exists, "Title is displayed")
        Verify(failure.failureImage.exists, "Failure image is displayed")
        Verify(failure.errorMessage.exists, "Error message is displayed")
        Verify(failure.tryAgainButton.exists, "Try again button exists")
      }
    }
  }

  /// https://passbolt.testrail.io/index.php?/cases/view/8157
  func test_asAUserICouldGoBackFromAFailedFeedbackInCaseOfErrorDuringQrCodesSequence() async throws {
    await executeSteps {
      NavigateToTransferQRCode()
      On(TransferQRCodeScreen.self) { qrCode in
        Tap(qrCode.cancelButton, "Cancel transfer")
        With(qrCode.confirmationAlert, as: Alert.self) { alert in
          Tap(alert.buttons["Stop transfer"]!, "Stop transfer")
        }
      }
      On(TransferFailureScreen.self) { failure in
        Verify(failure.title.exists, "Title is displayed")
        Tap(failure.tryAgainButton, "Try again")
      }
      On(TransferAccountDetailsScreen.self) { transfer in
        Verify(transfer.title.exists, "Transfer details screen is displayed")
      }
    }
  }
}

// MARK: - Navigation Helpers

internal struct NavigateToTransferDetails: CombinedUITestStep {

  @UITestStepsBuilder
  @MainActor
  internal var steps: Array<UITestStep> {
    On(HomeScreen.self) { home in
      Tap(home.settingsTab, "Open settings")
    }
    On(SettingsScreen.self) { settings in
      Tap(settings.accounts, "Open accounts")
    }
    On(AccountsSettingsScreen.self) { accounts in
      Tap(accounts.transferAccount, "Open transfer")
    }
  }
}

internal struct NavigateToTransferQRCode: CombinedUITestStep {

  @UITestStepsBuilder
  @MainActor
  internal var steps: Array<UITestStep> {
    NavigateToTransferDetails()
    On(TransferAccountDetailsScreen.self) { transfer in
      Tap(transfer.startTransferButton, "Start transfer")
    }
    On(TransferPassphraseScreen.self) { passphrase in
      TypeText(MockAccount.automation.password, into: passphrase.passphraseField, "Enter passphrase")
        .dismissKeyboardIfNeeded()
      Tap(passphrase.signInButton, "Confirm passphrase")
    }
  }
}
