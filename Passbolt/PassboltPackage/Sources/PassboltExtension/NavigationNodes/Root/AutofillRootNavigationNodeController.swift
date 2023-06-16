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

  private let diagnostics: OSDiagnostics
  private let asyncExecutor: AsyncExecutor
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

    self.diagnostics = features.instance()
    self.asyncExecutor = try features.instance()

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
    let storedAccounts: Array<Account> = accounts.storedAccounts()

    if storedAccounts.isEmpty {
      await navigationTree
        .replaceRoot(
          pushing: NoAccountsViewController.self,
          context: Void(),
          using: features
        )
    }
    else {
      let initialAccount: Account?
      if let lastUsedAccount: Account = accounts.lastUsedAccount() {
        initialAccount = lastUsedAccount
      }
      else if storedAccounts.count == 1, let singleAccount: Account = storedAccounts.first {
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

      if let account: Account = initialAccount {
        await navigationTree
          .push(
            AuthorizationViewController.self,
            context: account,
            using: features
          )
      }  // else NOP
    }

    self.asyncExecutor.schedule(.unmanaged) { [unowned self] () async -> Void in
      do {
        try await self.session.updates
          .dropFirst()
          .forEach { @SessionActor in
            do {
              let currentAccount: Account? =
                try? await self.session
                .currentAccount()
              let pendingAuthorization: SessionAuthorizationRequest? =
                self.session
                .pendingAuthorization()

              switch (currentAccount, pendingAuthorization) {
              case let (.some(currentAccount), .none):
                if let (account, tree): (Account, NavigationTreeState) = self.authorizationPromptRecoveryTreeState.get(
                  \.self
                ),
                  account == currentAccount
                {
                  self.authorizationPromptRecoveryTreeState.set(\.self, .none)
                  await self.navigationTree.set(treeState: tree)
                }
                else {
                  #warning("FIXME: application has a dedicated screen for configuration load fail, this should not break the extension so ignoring the error for now using fallback to defaults")
                  try? await self.sessionConfigurationLoader.fetchIfNeeded()
                  try await self.navigationTree.replaceRoot(
                    pushing: HomeNavigationNodeView.self,
                    controller: self.features.instance(
                      context: .init(
                        account: currentAccount,
                        configuration: self.sessionConfigurationLoader.sessionConfiguration()
                      )
                    )
                  )
                }

              case let (.some(account), .passphrase):
                await self.authorizationPromptRecoveryTreeState.set(\.self, (account, self.navigationTree.treeState))
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

              case (.some, .mfa):
                await self.navigationTree
                  .replaceRoot(
                    pushing: MFARequiredViewController.self,
                    context: Void(),
                    using: self.features
                  )

              case (.none, _):
                self.authorizationPromptRecoveryTreeState.set(\.self, .none)
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
            catch {
              self.diagnostics
                .log(
                  error: error,
                  info: .message(
                    "Root navigation failed."
                  )
                )
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
