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
final internal class WelcomeScreenTests: NoAccountUITestCase {

  /// https://passbolt.testrail.io/index.php?/cases/view/2332
  func test_asAMobileUserICanSeeTheWelcomeScreenWhenNoAccountIsSetUp() async throws {
    await executeSteps {
      On(WelcomeScreen.self) { welcome in
        Verify(welcome.logo.exists, "Passbolt logo is displayed")
        Verify(welcome.illustration.exists, "Welcome illustration is displayed")
        VerifyEqual(welcome.title.label, "Welcome!", "Welcome message title")
        VerifyEqual(
          welcome.message.label,
          "You need an existing account to get started. Sign in with your existing account on the desktop browser extension to connect it with the mobile device.",
          "Welcome message description"
        )
        VerifyEqual(
          welcome.connectToAccountButton.label,
          "Connect to an existing account",
          "Primary action title"
        )
        Verify(welcome.connectToAccountButton.isHittable, "Primary action is hittable")
        VerifyEqual(welcome.noAccountButton.label, "I don’t have an account", "Secondary action title")
        Verify(welcome.noAccountButton.isHittable, "Secondary action is hittable")
        WaitFor(welcome.helpButton, "Help button")
        Verify(welcome.helpButton.isHittable, "Help side action is hittable")
      }
    }
  }

  /// https://passbolt.testrail.io/index.php?/cases/view/2333
  func test_asAMobileUserICanSeeAnExplanationWhyICannotCreateAnAccountOnTheMobileApp() async throws {
    await executeSteps {
      On(WelcomeScreen.self) { welcome in
        Tap(welcome.noAccountButton, "Open no account explanation")
        With(welcome.noAccountAlert, as: Alert.self) { alert in
          Verify(alert.title == "How to create an account?", "Alert title")
          Verify(
            alert.message
              == "It is currently not possible to create an account using the mobile app. First you will need create an account using your desktop browser extension.",
            "Alert message"
          )
          Verify(alert.buttons["Got it"]?.exists == true, "Got it button exists")
          Verify(alert.buttons["Got it"]?.isHittable == true, "Got it button is clickable")
        }
      }
    }
  }

  /// https://passbolt.testrail.io/index.php?/cases/view/2334
  func test_asAMobileUserICanSeeAnExplanationOnHowToConnectAnExistingAccount() async throws {
    await executeSteps {
      On(WelcomeScreen.self) { welcome in
        Tap(welcome.connectToAccountButton, "Connect to an existing account")
      }
      On(AccountImportInfoScreen.self) { info in
        Verify(info.title.exists, "Title is displayed")
        Verify(info.backButton.isHittable, "Back button is hittable")
        Verify(info.transferDescription.exists, "Transfer description is displayed")
        Verify(info.firstStep.exists, "First setup step is displayed")
        Verify(info.secondStep.exists, "Second setup step is displayed")
        Verify(info.thirdStep.exists, "Third setup step is displayed")
        Verify(info.fourthStep.exists, "Fourth setup step is displayed")
        Verify(info.illustration.exists, "Illustration is displayed")
        Verify(info.scanQRCodesButton.isHittable, "Scan QR codes button is hittable")
        Tap(info.backButton, "Go back to the welcome screen")
      }
      On(WelcomeScreen.self) { _ in
        // Back button returns to the welcome screen
      }
    }
  }

  /// https://passbolt.testrail.io/index.php?/cases/view/6190
  func test_asAMobileUserICanGetHelpBeforeTheQRCodeScanningProcess() async throws {
    await executeSteps {
      On(WelcomeScreen.self) { welcome in
        // The help button lives in the toolbar, which the navigation bar attaches a moment after the
        // screen body - and it is not one of the screen's required elements, so nothing waited for it.
        WaitFor(welcome.helpButton, "Help button")
        Tap(welcome.helpButton, "Open help menu")
      }
      On(HelpMenuScreen.self) { help in
        Verify(help.accessTheLogsButton.isHittable, "Access the logs button is available")
        Verify(help.importAccountKitButton.isHittable, "Import your account kit button is available")
        Verify(help.visitHelpSiteButton.isHittable, "Visit help site button is available")
      }
    }
  }

  /// https://passbolt.testrail.io/index.php?/cases/view/6191
  func test_asAMobileUserICanOpenHelpWebpageBeforeTheQRCodeScanningProcess() async throws {
    let safari: XCUIApplication = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
    await executeSteps {
      On(WelcomeScreen.self) { welcome in
        // The help button lives in the toolbar, which the navigation bar attaches a moment after the
        // screen body - and it is not one of the screen's required elements, so nothing waited for it.
        WaitFor(welcome.helpButton, "Help button")
        Tap(welcome.helpButton, "Open help menu")
      }
      On(HelpMenuScreen.self) { help in
        Tap(help.visitHelpSiteButton, "Visit help site")
      }
      VerifySafariOpened(safari: safari)
    }
  }
}
