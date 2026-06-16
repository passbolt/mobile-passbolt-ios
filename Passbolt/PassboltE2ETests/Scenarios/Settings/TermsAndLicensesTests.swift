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
final internal class TermsAndLicensesTests: UITestCase {

  /// https://passbolt.testrail.io/index.php?/cases/view/8175
  func test_AsALoggedInUserICanSeeTermsAndLicences() async throws {
    await executeSteps {
      On(HomeScreen.self) { home in
        Tap(home.settingsTab, "Open settings")
      }
      On(SettingsScreen.self) { settings in
        Tap(settings.termsAndLicenses, "Open terms and licenses")
      }
      On(TermsAndLicensesScreen.self) { terms in
        Verify(terms.backButton.exists, "Back button exists")

        VerifySettingsEntry(
          title: "Terms & Conditions",
          iconName: "Info",
          hasDisclosureIndicator: true,
          with: terms.termsAndConditions
        )

        VerifySettingsEntry(
          title: "Privacy policy",
          iconName: "LockedLock",
          hasDisclosureIndicator: true,
          with: terms.privacyPolicy
        )

        VerifySettingsEntry(
          title: "Open Source Licences",
          iconName: "Feather",
          hasDisclosureIndicator: true,
          with: terms.openSourceLicenses
        )
      }
    }
  }

  /// https://passbolt.testrail.io/index.php?/cases/view/2429
  func test_AsALoggedInMobileUserOnTheSettingsPageICanOpenTheTermsAndConditionsPage() async throws {
    let safari: XCUIApplication = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
    await executeSteps {
      On(HomeScreen.self) { home in
        Tap(home.settingsTab, "Open settings")
      }
      On(SettingsScreen.self) { settings in
        Tap(settings.termsAndLicenses, "Open terms and licenses")
      }
      On(TermsAndLicensesScreen.self) { terms in
        Tap(terms.termsAndConditions, "Open Terms & Conditions")
      }
      VerifySafariOpened(safari: safari)
    }
  }

  /// https://passbolt.testrail.io/index.php?/cases/view/2432
  func test_AsALoggedInMobileUserOnTheSettingsPageICanOpenThePrivacyPolicyPage() async throws {
    let safari: XCUIApplication = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
    await executeSteps {
      On(HomeScreen.self) { home in
        Tap(home.settingsTab, "Open settings")
      }
      On(SettingsScreen.self) { settings in
        Tap(settings.termsAndLicenses, "Open terms and licenses")
      }
      On(TermsAndLicensesScreen.self) { terms in
        Tap(terms.privacyPolicy, "Open Privacy Policy")
      }
      VerifySafariOpened(safari: safari)
    }
  }
}

internal struct VerifySafariOpened: UITestStep {

  internal var name: String { "Verify Safari opened" }

  private let safari: XCUIApplication
  private let timeout: TimeInterval
  private let file: StaticString
  private let line: UInt

  internal init(
    safari: XCUIApplication,
    timeout: TimeInterval = .standardUI,
    file: StaticString = #fileID,
    line: UInt = #line
  ) {
    self.safari = safari
    self.timeout = timeout
    self.file = file
    self.line = line
  }

  @MainActor
  internal func execute() throws {
    let launched: Bool = safari.wait(for: .runningForeground, timeout: timeout)
    if !launched {
      throw AssertionFailure("Safari did not open within \(timeout) seconds.", file: file, line: line)
    }
  }
}
