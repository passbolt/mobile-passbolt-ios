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

  private let accounts: Accounts
  private let session: Session
  private let sessionConfigurationLoader: SessionConfigurationLoader
  private let navigationRestoration: NavigationRestoration
  private let restorationAccount: CriticalState<Account?> = .init(.none)

  private let features: Features

  @MainActor public init(
    context: Void,
    features: Features
  ) throws {
    self.features = features

    self.accounts = try features.instance()
    self.session = try features.instance()
    self.sessionConfigurationLoader = try features.instance()
    self.navigationRestoration = try features.instance()
  }
}

extension AutofillRootNavigationNodeController {

  internal final func activate() async {
    let storedAccounts: Array<AccountWithProfile> = accounts.storedAccounts()

    if storedAccounts.isEmpty {
      await consumingErrors {
        let navigationToNoAccounts: NavigationToNoAccounts = try features.instance()
        try await navigationToNoAccounts.perform()
      }
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

      await consumingErrors {
        let navigationToAccountSelection: NavigationToAccountSelection = try features.instance()
        try await navigationToAccountSelection.perform(
          context: .signIn
        )
      }

      if let account: AccountWithProfile = initialAccount {
        await consumingErrors {
          let navigationToAccountSelection: NavigationToAuthorization = try features.instance()
          try await navigationToAccountSelection.perform(
            context: account.account
          )
        }
      }  // else NOP
    }

    Task {
      do {
        try await SessionStateChangeEvent.subscribe { (event: SessionStateChangeEvent) async throws in
          switch event {
          case .authorized(let account):
            if let restorationAccount: Account = self.restorationAccount.get(),
              restorationAccount == account,
              try await self.navigationRestoration.canRestore()
            {
              self.restorationAccount.set(.none)
              try await self.navigationRestoration.restore()
            }
            else {
              let features: Features = try await self.features
                .branchIfNeeded(scope: AccountScope.self, context: account)
                .branchIfNeeded(
                  scope: SessionScope.self,
                  context: .init(
                    account: account,
                    configuration: await self.sessionConfigurationLoader.sessionConfiguration()
                  )
                )
              let navigationToHome: NavigationToHome = try await features.instance()
              try await navigationToHome.perform(
                context: .init(
                  account: account,
                  configuration: self.sessionConfigurationLoader.sessionConfiguration()
                )
              )
            }

            if let previousAccount: Account = self.restorationAccount
              .get(),
              account == previousAccount
            {
              try await self.navigationRestoration.restore()
            }
            else {
              let features: Features = try await self.features
                .branchIfNeeded(scope: AccountScope.self, context: account)
                .branchIfNeeded(
                  scope: SessionScope.self,
                  context: .init(
                    account: account,
                    configuration: await self.sessionConfigurationLoader.sessionConfiguration()
                  )
                )
              let navigationToHome: NavigationToHome = try await features.instance()
              try await navigationToHome.perform(
                context: .init(
                  account: account,
                  configuration: self.sessionConfigurationLoader.sessionConfiguration()
                )
              )
            }
          case .requestedPassphrase(let account):
            self.restorationAccount.set(account)

            await consumingErrors {
              try await self.navigationRestoration.saveCurrent()
              let navigationToAccountSelection: NavigationToAccountSelection = try await self.features.instance()
              try await navigationToAccountSelection.perform(
                context: .signIn
              )

              let navigationToAuthorization: NavigationToAuthorization = try await self.features.instance()
              try await navigationToAuthorization.perform(context: account)

            }

          case .requestedMFA:
            await consumingErrors {
              let navigationToMFA: NavigationToMFARequired = try await self.features.instance()
              try await navigationToMFA.perform()
            }

          case .closed:
            self.restorationAccount.set(.none)
            if self.accounts.storedAccounts().isEmpty {
              let navigateToNoAccounts: NavigationToNoAccounts = try await self.features.instance()
              try await navigateToNoAccounts.perform()
            }
            else {
              await consumingErrors {
                try await self.navigationRestoration.saveCurrent()
                let navigationToAccountSelection: NavigationToAccountSelection = try await self.features.instance()
                try await navigationToAccountSelection.perform(
                  context: .signIn
                )
              }
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
