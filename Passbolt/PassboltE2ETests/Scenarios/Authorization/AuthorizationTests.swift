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

/// Scenarios covering the sign in screen of a configured - but not yet authorized - account.
/// `UnauthorizedUITestCase` leaves the application on that screen instead of signing in during setup.
@MainActor
final internal class AuthorizationTests: UnauthorizedUITestCase {

  func test_asAMobileUserICanSeeTheSignInScreenOfMyConfiguredAccount() async throws {
    let account: MockAccount = .automation
    await executeSteps {
      On(LoginScreen.self, timeout: .networkCall) { login in
        Verify(login.avatar.exists, "Account avatar is displayed")
        Verify(login.accountLabel(of: account).exists, "Account label is displayed")
        VerifyEqual(login.email.label, account.username, "Account username is displayed")
        VerifyEqual(login.url.label, account.domain, "Account domain is displayed")
        Verify(login.passphraseLabel.exists, "Passphrase field is labelled as mandatory")
        Verify(login.passphraseField.exists, "Passphrase field is displayed")
        VerifyEqual(login.signInButton.label, "Sign In", "Primary action title")
        VerifyEqual(login.forgotPassphraseButton.label, "I forgot my passphrase", "Support action title")
        Verify(login.forgotPassphraseButton.isHittable, "Support action is hittable")
        WaitFor(login.helpButton, "Help button")
        Verify(login.helpButton.isHittable, "Help side action is hittable")
      }
    }
  }

  func test_asAMobileUserICannotSignInWithoutEnteringMyPassphrase() async throws {
    await executeSteps {
      On(LoginScreen.self, timeout: .networkCall) { login in
        VerifyEqual(login.signInButton.isEnabled, false, "Sign in is disabled with an empty passphrase")
        TypeText("some passphrase", into: login.passphraseField, "Enter a passphrase")
          .dismissKeyboardIfNeeded()
        VerifyEqual(login.signInButton.isEnabled, true, "Sign in is enabled once a passphrase is entered")
      }
    }
  }

  func test_asAMobileUserICannotSignInWithAnInvalidPassphrase() async throws {
    await executeSteps {
      On(LoginScreen.self, timeout: .networkCall) { login in
        TypeText("definitely-not-the-passphrase", into: login.passphraseField, "Enter an invalid passphrase")
          .dismissKeyboardIfNeeded()
        Tap(login.signInButton, "Sign in")
        WaitFor(
          login.snackBarMessage,
          predicate: "label == \"Invalid passphrase.\"",
          timeout: .networkCall,
          "Invalid passphrase message is displayed"
        )
      }
      On(LoginScreen.self) { login in
        Verify(login.passphraseField.exists, "Sign in screen is still displayed")
      }
    }
  }

  func test_asAMobileUserICanSignInWithMyPassphrase() async throws {
    let account: MockAccount = .automation
    await executeSteps {
      Login(account: account)
      On(HomeScreen.self, timeout: .networkCall) { _ in
        // Successful authorization opens the home screen
      }
      On(HomeListScreen.self) { home in
        WaitForRefreshToComplete(home.list, timeout: .longNetworkCall)
        Verify(home.accountAvatar.exists, "Home list is displayed for the signed in account")
      }
    }
  }

  func test_asAMobileUserICanSeeAnExplanationWhenIForgotMyPassphrase() async throws {
    await executeSteps {
      On(LoginScreen.self, timeout: .networkCall) { login in
        Tap(login.forgotPassphraseButton, "Open the forgotten passphrase explanation")
        With(login.forgotPassphraseAlert, as: Alert.self) { alert in
          Verify(alert.title == "Did you forgot your passphrase?", "Alert title")
          Verify(
            alert.message
              == "Unfortunately you cannot access your data if you do not remember your passphrase. Please contact your administrator to unlock your account.",
            "Alert message"
          )
          Verify(alert.buttons["Got it"]?.isHittable == true, "Got it button is hittable")
        }
      }
    }
  }

  func test_asAMobileUserICanGetHelpFromTheSignInScreen() async throws {
    await executeSteps {
      On(LoginScreen.self, timeout: .networkCall) { login in
        // Toolbar items attach after the screen body, and the help button is not a required element.
        WaitFor(login.helpButton, "Help button")
        Tap(login.helpButton, "Open help menu")
      }
      On(HelpMenuScreen.self) { help in
        Verify(help.accessTheLogsButton.isHittable, "Access the logs button is available")
        Verify(help.importAccountKitButton.isHittable, "Import your account kit button is available")
        Verify(help.visitHelpSiteButton.isHittable, "Visit help site button is available")
      }
    }
  }
}
