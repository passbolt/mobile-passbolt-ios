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
import Display
import OSFeatures
import Session
import SessionData
import SharedUIComponents

internal final class AutofillRootNavigationNodeController: ViewController {

  private let navigationTree: NavigationTree
  private let accounts: Accounts
  private let session: Session
  private let sessionConfigurationLoader: SessionConfigurationLoader
  private let authorizationPromptRecoveryTreeState: CriticalState<(account: Account, tree: NavigationTreeState)?>

  private let features: Features

  @MainActor public init(
    context: Void,
    features: Features
  ) throws {
    self.features = features

    self.navigationTree = features.instance()
    self.accounts = try features.instance()
    self.session = try features.instance()
    self.sessionConfigurationLoader = try features.instance()
    self.authorizationPromptRecoveryTreeState = .init(
      .none
    )
  }
}

extension AutofillRootNavigationNodeController {

  internal final func activate() async {
    let storedAccounts: Array<AccountWithProfile> = accounts.storedAccounts()

    if storedAccounts.isEmpty {
      await navigationTree
        .replaceRoot(
          pushing: NoAccountsViewController.self,
          context: Void(),
          using: features
        )
    }
    else {
      let initialAccount: AccountWithProfile?
      if let lastUsedAccount: AccountWithProfile = accounts.lastUsedAccount() {
        initialAccount = lastUsedAccount
      }
      else if storedAccounts.count == 1, let singleAccount: AccountWithProfile = storedAccounts.first {
        initialAccount = singleAccount
      }
      else {
        initialAccount = .none
      }

      await navigationTree
        .replaceRoot(
          pushing: AccountSelectionViewController.self,
          context: .signIn,
          using: features
        )

      if let account: AccountWithProfile = initialAccount {
        await navigationTree
          .push(
            AuthorizationViewController.self,
            context: account.account,
            using: features
          )
      }  // else NOP
    }

    Task {
      do {
        try await SessionStateChangeEvent.subscribe { (event: SessionStateChangeEvent) async throws in
          switch event {
          case .authorized(let account):
            if let (previousAccount, tree): (Account, NavigationTreeState) = self.authorizationPromptRecoveryTreeState
              .get(),
              account == previousAccount
            {
              self.authorizationPromptRecoveryTreeState.set(.none)
              await self.navigationTree.set(treeState: tree)
            }
            else {
              #warning(
                "FIXME: application has a dedicated screen for configuration load fail, this should not break the extension!"
              )
              try await self.navigationTree.replaceRoot(
                pushing: HomeNavigationNodeView.self,
                controller: self.features.instance(
                  context: .init(
                    account: account,
                    configuration: self.sessionConfigurationLoader.sessionConfiguration()
                  )
                )
              )
            }
          case .requestedPassphrase(let account):
            await self.authorizationPromptRecoveryTreeState.set((account, self.navigationTree.treeState))
            await self.navigationTree
              .replaceRoot(
                pushing: AccountSelectionViewController.self,
                context: .signIn,
                using: self.features
              )
            await self.navigationTree
              .push(
                AuthorizationViewController.self,
                context: account,
                using: self.features
              )
          case .requestedMFA(let account, let providers):
            await self.navigationTree
              .replaceRoot(
                pushing: MFARequiredViewController.self,
                context: Void(),
                using: self.features
              )
          case .closed:
            self.authorizationPromptRecoveryTreeState.set(.none)
            if self.accounts.storedAccounts().isEmpty {
              await self.navigationTree
                .replaceRoot(
                  pushing: NoAccountsViewController.self,
                  context: Void(),
                  using: self.features
                )
            }
            else {
              await self.navigationTree
                .replaceRoot(
                  pushing: AccountSelectionViewController.self,
                  context: .signIn,
                  using: self.features
                )
            }
          }
        }
      }
      catch {
        error
          .asTheError()
          .asFatalError(message: "Session monitoring broken.")
      }
    }
  }
}
