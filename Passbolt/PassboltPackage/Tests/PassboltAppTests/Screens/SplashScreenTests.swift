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

import CommonModels
import Display
import Features
import SessionData
import SharedUIComponents
import TestExtensions

@testable import Accounts
@testable import PassboltApp

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals

final class NewSplashScreenViewTests: FeaturesTestCase {

  var updates: Updates!

  override func commonPrepare() {
    super.commonPrepare()
    updates = .init()
    patch(
      \UpdateCheck.checkRequired,
      with: always(false)
    )
    patch(
      \Session.updates,
      with: updates.asAnyUpdatable()
    )
    patch(
      \Session.currentAccount,
      with: always(Account.mock_ada)
    )
    patch(
      \Session.pendingAuthorization,
      with: always(.none)
    )

    patch(
      \SessionConfigurationLoader.sessionConfiguration,
      with: alwaysThrow(MockIssue.error())
    )
    patch(
      \Accounts.verifyDataIntegrity,
      with: always(Void())
    )
    patch(
      \Accounts.storedAccounts,
      with: always([AccountWithProfile.mock_ada])
    )
  }

  func test_navigateToDiagnostics_whenDataIntegrityCheckFails() async throws {
    patch(
      \Accounts.verifyDataIntegrity,
      with: alwaysThrow(MockIssue.error())
    )

    try await verifyIfTriggersNavigation(NavigationToLogsViewer.self)
  }

  func test_navigateToAccountSetup_whenNoStoredAccounts() async throws {
    patch(
      \Accounts.storedAccounts,
      with: always([])
    )

    try await verifyIfTriggersNavigation(NavigationToWelcomeScreen.self)
  }

  func test_navigateToAccountSelection_whenStoredAccountsPresent_withAccount_andNotAuthorized() async throws {
    patch(
      \Accounts.storedAccounts,
      with: always([AccountWithProfile.mock_ada])
    )
    patch(
      \Session.currentAccount,
      with: alwaysThrow(SessionMissing.error())
    )

    patch(
      \NavigationToAuthorization.mockPerform,
      with: always(self.mockExecuted())
    )

    try await verifyIfTriggersNavigation(
      NavigationToAccountSelection.self,
      with: Account.mock_ada,
      mocksTriggered: 2
    )
  }

  func test_navigateToAccountSelection_whenStoredAccountsPresent_withoutLastUsedAccount_andNotAuthorized() async throws
  {
    patch(
      \Accounts.storedAccounts,
      with: always([AccountWithProfile.mock_ada])
    )
    patch(
      \Session.currentAccount,
      with: alwaysThrow(SessionMissing.error())
    )

    try await verifyIfTriggersNavigation(
      NavigationToAccountSelection.self
    )
  }

  func test_navigateToHome_whenAuthorized_andFeatureFlagsDownloadSucceeds() async throws {
    patch(
      \Session.currentAccount,
      with: always(Account.mock_ada)
    )
    patch(
      \SessionConfigurationLoader.sessionConfiguration,
      with: always(.default)
    )

    try await verifyIfTriggersNavigation(
      NavigationToMainTabs.self
    )
  }

  func test_navigateToFeatureFlagsFetchError_whenAuthorized_andFeatureFlagsDownloadFails() async throws {
    patch(
      \Session.currentAccount,
      with: always(Account.mock_ada)
    )
    patch(
      \SessionConfigurationLoader.sessionConfiguration,
      with: alwaysThrow(MockIssue.error())
    )

    try await verifyIfTriggersNavigation(
      NavigationToStartupError.self
    )
  }

  private func verifyIfTriggersNavigation<N>(
    _: NavigationTo<N>.Type = NavigationTo<N>.self,
    with context: SplashScreenViewController.Context = .none,
    mocksTriggered: UInt = 1,
    file: StaticString = #file,
    line: UInt = #line,
  ) async throws where N: NavigationDestination {
    patch(
      \NavigationTo<N>.mockPerform,
      with: always(self.mockExecuted())
    )

    await withInstance(
      of: SplashScreenViewController.self,
      context: context,
      mockExecuted: mocksTriggered,
      file: file,
      line: line
    ) { @MainActor feature in
      await feature.activate()
    }
  }
}
