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

import Accounts
import FeatureScopes
import SharedUIComponents
import TestExtensions

@testable import Display
@testable import PassboltApp

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class AccountSelectionViewControllerTests: FeaturesTestCase {

  override func commonPrepare() {
    super.commonPrepare()
    patch(
      \Accounts.storedAccounts,
      with: {
        [
          .init(account: .mock_ada, profile: .mock_ada),
          .init(account: .betty, profile: .betty),
        ]
      }
    )
    patch(
      \Accounts.updates,
      with: Variable(initial: Void())
        .asAnyUpdatable()
    )
    patch(
      \Session.currentAccount,
      with: { .mock_ada }
    )
    patch(
      \MediaDownloadNetworkOperation.execute,
      with: { _ in Data() }
    )
  }

  func test_viewState_initialMode_isSelection() async throws {
    let tested: AccountSelectionViewController = try self.testedInstance(
      context: .init(isSignIn: true)
    )

    XCTAssertEqual(
      AccountSelectionViewController.Mode.selection,
      tested.viewState.value.mode
    )
  }

  func test_viewState_isSignIn_matchesContext() async throws {
    let tested: AccountSelectionViewController = try self.testedInstance(
      context: .init(isSignIn: true)
    )

    XCTAssertTrue(tested.viewState.value.isSignIn)
  }

  func test_viewState_accounts_containsStoredAccounts() async throws {
    let tested: AccountSelectionViewController = try self.testedInstance(
      context: .init(isSignIn: false)
    )

    let state: AccountSelectionViewController.ViewState = await tested.viewState.current

    XCTAssertEqual(2, state.accounts.count)
    XCTAssertEqual("ada@passbolt.com", state.accounts.first?.subtitle)
  }

  func test_viewState_canAddAccount_isTrue_whenModeIsSelection() async throws {
    let tested: AccountSelectionViewController = try self.testedInstance(
      context: .init(isSignIn: false)
    )

    XCTAssertTrue(tested.viewState.value.canAddAccount)
  }

  func test_viewState_canAddAccount_isFalse_whenModeIsRemoval() async throws {
    let tested: AccountSelectionViewController = try self.testedInstance(
      context: .init(isSignIn: false)
    )

    await tested.toggleMode()

    XCTAssertFalse(tested.viewState.value.canAddAccount)
  }

  func test_toggleMode_switchesBetweenSelectionAndRemoval() async throws {
    let tested: AccountSelectionViewController = try self.testedInstance(
      context: .init(isSignIn: false)
    )

    XCTAssertEqual(.selection, tested.viewState.value.mode)

    await tested.toggleMode()
    XCTAssertEqual(.removal, tested.viewState.value.mode)

    await tested.toggleMode()
    XCTAssertEqual(.selection, tested.viewState.value.mode)
  }

  func test_selectAccount_navigatesToAuthorization() async throws {
    patch(
      \NavigationToAuthorization.performAnimated,
      with: always(self.mockExecuted())
    )

    let tested: AccountSelectionViewController = try self.testedInstance(
      context: .init(isSignIn: true)
    )

    try await tested.selectAccount(.mock_ada)

    XCTAssertTrue(self.mockWasExecuted)
  }

  func test_addAccount_navigatesToAccountImportInfo() async throws {
    patch(
      \NavigationToAccountImportInfo.performAnimated,
      with: always(self.mockExecuted())
    )

    let tested: AccountSelectionViewController = try self.testedInstance(
      context: .init(isSignIn: false)
    )

    await tested.addAccount()

    XCTAssertTrue(self.mockWasExecuted)
  }

  func test_removeAccount_showsAlert() async throws {
    let tested: AccountSelectionViewController = try self.testedInstance(
      context: .init(isSignIn: false)
    )

    await tested.removeAccount(.mock_ada)

    XCTAssertNotNil(tested.viewState.value.alert)
    XCTAssertEqual(
      "account.selection.remove.alert.title",
      tested.viewState.value.alert?.title
    )
  }

  func test_removeAccount_removesAccount_whenConfirmed() async throws {
    let accountRemoved: CriticalState<Bool> = .init(false)
    patch(
      \Accounts.removeAccount,
      with: { _ in
        accountRemoved.set(true)
      }
    )

    let tested: AccountSelectionViewController = try self.testedInstance(
      context: .init(isSignIn: false)
    )

    await tested.removeAccount(.mock_ada)

    if let destructiveAction = tested.viewState.value.alert?.actions
      .first(
        where: { action in
          if case .destructive = action {
            return true
          }
          else {
            return false
          }
        })
    {
      if case .destructive(_, _, let perform) = destructiveAction {
        await perform()
      }
    }

    XCTAssertTrue(accountRemoved.get())
  }

  func test_openHelp_navigatesToHelpMenu() async throws {
    patch(
      \NavigationToHelpMenu.performAnimated,
      with: always(self.mockExecuted())
    )

    let tested: AccountSelectionViewController = try self.testedInstance(
      context: .init(isSignIn: false)
    )

    await tested.openHelp()

    XCTAssertTrue(self.mockWasExecuted)
  }

  func test_viewState_navigatesToWelcomeScreen_whenNoAccountsStored() async throws {
    patch(
      \Accounts.storedAccounts,
      with: { [] }
    )
    patch(
      \NavigationToWelcomeScreen.performAnimated,
      with: always(self.mockExecuted())
    )

    let tested: AccountSelectionViewController = try self.testedInstance(
      context: .init(isSignIn: false)
    )
    let _ = await tested.viewState.current  // Force viewState evaluation

    XCTAssertTrue(self.mockWasExecuted)
  }

  func test_backButtonTapped_revertsNavigation_whenInSessionScope() async throws {
    set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_default
      )
    )
    patch(
      \NavigationToManageAccounts.revertAnimated,
      with: always(self.mockExecuted())
    )

    let tested: AccountSelectionViewController = try self.testedInstance(
      context: .init(isSignIn: false)
    )

    await tested.backButtonTapped()

    XCTAssertTrue(self.mockWasExecuted)
  }
}
