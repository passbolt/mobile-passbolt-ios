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
final internal class SettingsTests: UITestCase {

  ///    https://passbolt.testrail.io/index.php?/cases/view/2438
  func test_asAMobileUserOnTheMainSettingsPageICanSeeTheListOfSettingsIHaveAccessTo() async throws {
    await executeSteps {
      On(HomeScreen.self) { home in
        Tap(home.settingsTab, "Open settings")
      }
      On(SettingsScreen.self) { settings in
        VerifySettingsEntry(
          title: "App settings",
          iconName: "Settings",
          hasDisclosureIndicator: true,
          with: settings.appSettings
        )
        VerifySettingsEntry(
          title: "Accounts",
          iconName: "People",
          hasDisclosureIndicator: true,
          with: settings.accounts
        )
        VerifySettingsEntry(
          title: "Terms & licenses",
          iconName: "Info",
          hasDisclosureIndicator: true,
          with: settings.termsAndLicenses
        )
        VerifySettingsEntry(
          title: "Debug, logs",
          iconName: "Bug",
          hasDisclosureIndicator: true,
          with: settings.logs
        )
        VerifySettingsEntry(
          title: "Sign out",
          iconName: "Exit",
          hasDisclosureIndicator: false,
          with: settings.signOut
        )
      }
    }
  }

  /// https://passbolt.testrail.io/index.php?/cases/view/2435
  func test_asALoggedInMobileUserOnTheSettingsPageICanSignOut() async throws {
    await executeSteps {
      On(HomeScreen.self) { home in
        Tap(home.settingsTab, "Open settings")
      }
      On(SettingsScreen.self) { settings in
        Tap(settings.signOut, "Sign out")
        Group("Confirm sign out") {
          With(settings.confirmationAlert, as: Alert.self) { alert in
            Verify(alert.title == "Are you sure?", "Alert title")
            Verify(
              alert.message == "If you sign out you will be logged out of your account on this device.",
              "Alert message"
            )
            Verify(alert.buttons["Cancel"]?.exists == true, "Cancel button")
            Verify(alert.buttons["Sign out"]?.exists == true, "Sign out button")
            Tap(alert.buttons["Sign out"]!, "Confirm sign out")
          }
        }
        On(AccountSelectionScreen.self) { accountSelection in
          Verify(accountSelection.isDisplayed, "Account selection screen is displayed")
        }
      }
    }
  }

  /// https://passbolt.testrail.io/index.php?/cases/view/2448
  func test_asALoggedInMobileUserOnTheSettingsPageINeedToConfirmSignOut() async throws {
    await executeSteps {
      On(HomeScreen.self, timeout: .networkCall) { home in
        Tap(home.settingsTab, "Open settings")
      }
      On(SettingsScreen.self) { settings in
        Tap(settings.signOut, "Sign out")
        With(settings.confirmationAlert, as: Alert.self) { alert in
          Verify(alert.title == "Are you sure?", "Alert title")
          Verify(alert.buttons["Cancel"]?.exists == true, "Cancel button exists")
          Tap(alert.buttons["Cancel"]!, "Cancel sign out")
        }
        Verify(settings.title.exists, "Still on settings screen")
      }
    }
  }
}
