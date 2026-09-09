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
final internal class AccountMenuTests: UITestCase {

  /// https://passbolt.testrail.io/index.php?/cases/view/2472
  func test_asALoggedInUserWithOneAccountICanTriggerTheSwitchAccountDrawer() async throws {
    let account: MockAccount = .automation
    await executeSteps {
      OpenAccountMenu()
      On(AccountMenuScreen.self) { menu in
        Verify(menu.title.exists, "Drawer title is displayed")
        Verify(menu.closeButton.isHittable, "Close button is hittable")
        Verify(menu.currentAccountAvatar.exists, "Current account avatar is displayed")
        Verify(menu.accountLabel(of: account).exists, "Current account label is displayed")
        Verify(menu.accountEmail(of: account).exists, "Current account email is displayed")
        Verify(menu.seeDetailsButton.isHittable, "See details button is hittable")
        Verify(menu.signOutButton.isHittable, "Sign out button is hittable")
        Verify(menu.accountsList.exists, "Account list is displayed")
        VerifyEqual(menu.otherAccountRows.count, 0, "No other account is configured")
        Verify(menu.manageAccountsButton.isHittable, "Manage accounts button is hittable")
      }
    }
  }

  /// https://passbolt.testrail.io/index.php?/cases/view/2475
  func test_asALoggedInUserOnTheSwitchAccountDrawerICanTriggerTheManageMyAccountsPage() async throws {
    let account: MockAccount = .automation
    await executeSteps {
      OpenAccountMenu()
      On(AccountMenuScreen.self) { menu in
        Tap(menu.manageAccountsButton, "Open manage accounts")
      }
      On(ManageAccountsScreen.self) { manageAccounts in
        Verify(manageAccounts.logo.exists, "Passbolt logo is displayed")
        Verify(manageAccounts.subtitle.exists, "Account selection subtitle is displayed")
        Verify(manageAccounts.accountRow(of: account).exists, "Account list contains the account")
        Verify(manageAccounts.removeAccountButton.isHittable, "Remove an account button is hittable")
      }
    }
  }

  /// https://passbolt.testrail.io/index.php?/cases/view/2477
  ///
  /// Signing out closes the session, so the splash screen finds no current account and presents the
  /// "Welcome back!" account list - without preselecting an account for authorization.
  func test_asALoggedInUserOnTheSwitchAccountDrawerICanSignOut() async throws {
    let account: MockAccount = .automation
    await executeSteps {
      OpenAccountMenu()
      On(AccountMenuScreen.self) { menu in
        Tap(menu.signOutButton, "Sign out")
      }
      On(AccountSelectionScreen.self, timeout: .networkCall) { accountSelection in
        VerifyEqual(accountSelection.title.label, "Welcome back!", "Welcome back title is displayed")
        Verify(accountSelection.message.exists, "Account selection message is displayed")
        Verify(accountSelection.accountRow(of: account).exists, "Signed out account is listed")
      }
    }
  }
}

// MARK: - Navigation Helpers

internal struct OpenAccountMenu: CombinedUITestStep {

  @UITestStepsBuilder
  @MainActor
  internal var steps: Array<UITestStep> {
    On(HomeListScreen.self) { home in
      Tap(home.accountAvatar, "Open switch account drawer")
    }
  }
}
