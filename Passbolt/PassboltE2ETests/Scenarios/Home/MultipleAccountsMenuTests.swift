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

/// Scenarios requiring a second configured account. They skip when `MockAccount.secondary`
/// is not provided through the test runner environment.
@MainActor
final internal class MultipleAccountsMenuTests: UITestCase {

  override internal func configureLauncher() {
    launcher.with(account: .automation)
    if let secondaryAccount: MockAccount = MockAccount.secondary {
      launcher.with(account: secondaryAccount)
    }
    // Without it the application cannot preselect an account and opens the account list instead.
    launcher.with(lastUsedAccountID: MockAccount.automation.userID)
  }

  /// https://passbolt.testrail.io/index.php?/cases/view/2473
  func test_asALoggedInUserWithMultipleAccountsICanTriggerTheSwitchAccountDrawer() async throws {
    let currentAccount: MockAccount = .automation
    let otherAccount: MockAccount = try self.requireSecondaryAccount()
    await executeSteps {
      OpenAccountMenu()
      On(AccountMenuScreen.self) { menu in
        Verify(menu.title.exists, "Drawer title is displayed")
        Verify(menu.closeButton.isHittable, "Close button is hittable")
        Verify(menu.currentAccountAvatar.exists, "Current account avatar is displayed")
        Verify(menu.accountLabel(of: currentAccount).exists, "Current account label is displayed")
        Verify(menu.accountEmail(of: currentAccount).exists, "Current account email is displayed")
        Verify(menu.seeDetailsButton.isHittable, "See details button is hittable")
        Verify(menu.signOutButton.isHittable, "Sign out button is hittable")
        Verify(menu.accountsList.exists, "Account list is displayed")
        Verify(menu.otherAccountRow(of: otherAccount).exists, "Other account row is displayed")
        Verify(menu.otherAccountAvatar.exists, "Other account avatar is displayed")
        Verify(menu.accountLabel(of: otherAccount).exists, "Other account label is displayed")
        Verify(menu.accountEmail(of: otherAccount).exists, "Other account email is displayed")
        Verify(menu.manageAccountsButton.isHittable, "Manage accounts button is hittable")
      }
    }
  }

  /// https://passbolt.testrail.io/index.php?/cases/view/2476
  func test_asALoggedInUserWithMultipleAccountsICanSwitchAccounts() async throws {
    let otherAccount: MockAccount = try self.requireSecondaryAccount()
    await executeSteps {
      OpenAccountMenu()
      On(AccountMenuScreen.self) { menu in
        Tap(menu.otherAccountRow(of: otherAccount), "Switch to the other account")
      }
      On(LoginScreen.self, timeout: .networkCall) { login in
        VerifyEqual(login.email.label, otherAccount.username, "Other account email is displayed")
        VerifyEqual(login.url.label, otherAccount.domain, "Other account URL is displayed")
      }
      Login(account: otherAccount)
      On(HomeScreen.self, timeout: .networkCall) { _ in
        // Nothing to do here, just waiting for the other account home screen
      }
      On(HomeListScreen.self) { home in
        WaitForRefreshToComplete(home.list, timeout: 60)
      }
    }
  }

  private func requireSecondaryAccount() throws -> MockAccount {
    try XCTSkipIf(
      MockAccount.secondary == nil,
      "Secondary account is not configured - see `MockAccount.secondary` for the required environment variables."
    )
    return try XCTUnwrap(MockAccount.secondary)
  }
}
