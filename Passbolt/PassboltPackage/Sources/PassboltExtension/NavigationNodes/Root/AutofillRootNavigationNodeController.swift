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
import Session
import SharedUIComponents

internal struct AutofillRootNavigationNodeController {

  internal var displayViewState: DisplayViewState<ViewState>
  internal var startSessionMonitoring: () async -> Void
}

extension AutofillRootNavigationNodeController: ContextlessNavigationNodeController {

  internal typealias ViewState = HashableVoid

  #if DEBUG
  nonisolated static var placeholder: Self {
    .init(
      displayViewState: .placeholder,
      startSessionMonitoring: unimplemented()
    )
  }
  #endif
}

extension AutofillRootNavigationNodeController {

  @MainActor fileprivate static func load(
    features: FeatureFactory
  ) async throws -> Self {
    let navigationTree: NavigationTree = features.instance()

    let accounts: Accounts = try await features.instance()
    let session: Session = try await features.instance()
    let authorizationPromptRecoveryTreeState: CriticalState<(account: Account, tree: NavigationTreeState)?> = .init(
      .none
    )

    nonisolated func startSessionMonitoring() async {
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

      await Task.detached { @SessionActor in
        for await _ in session.updatesSequence.dropFirst() {
          let currentAccount: Account? =
            try? await session
            .currentAccount()
          let pendingAuthorization: SessionAuthorizationRequest? =
            session
            .pendingAuthorization()

          switch (currentAccount, pendingAuthorization) {
          case let (.some(currentAccount), .none):
            if let (account, tree): (Account, NavigationTreeState) = authorizationPromptRecoveryTreeState.get(\.self),
              account == currentAccount
            {
              authorizationPromptRecoveryTreeState.set(\.self, .none)
              navigationTree.set(treeState: tree)
            }
            else {
              try await navigationTree.replaceRoot(
                pushing: ResourcesListNavigationNodeView.self,
                controller: features.instance()
              )
            }

          case let (.some(account), .passphrase):
            authorizationPromptRecoveryTreeState.set(\.self, (account, navigationTree.treeState))
            await navigationTree
              .replaceRoot(
                pushing: AccountSelectionViewController.self,
                context: .signIn,
                using: features
              )
            await navigationTree
              .push(
                AuthorizationViewController.self,
                context: account,
                using: features
              )

          case (.some, .mfa):
            await navigationTree
              .replaceRoot(
                pushing: MFARequiredViewController.self,
                context: Void(),
                using: features
              )

          case (.none, _):
            authorizationPromptRecoveryTreeState.set(\.self, .none)
            if accounts.storedAccounts().isEmpty {
              await navigationTree
                .replaceRoot(
                  pushing: NoAccountsViewController.self,
                  context: Void(),
                  using: features
                )
            }
            else {
              await navigationTree
                .replaceRoot(
                  pushing: AccountSelectionViewController.self,
                  context: .signIn,
                  using: features
                )
            }
          }
        }
      }
      .waitForCompletion()
    }

    return .init(
      displayViewState: .init(initial: .init()),
      startSessionMonitoring: startSessionMonitoring
    )
  }
}

extension FeatureFactory {

  @MainActor public func usePassboltAutofillRootNavigationNodeController() {
    self.use(
      .disposable(
        AutofillRootNavigationNodeController.self,
        load: AutofillRootNavigationNodeController.load(features:)
      )
    )
  }
}
