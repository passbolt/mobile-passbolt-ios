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
import UIComponents

internal struct AccountMenuController {

  internal let currentAccountWithProfile: AccountWithProfile
  internal var currentAcountAvatarImagePublisher: @MainActor () -> AnyPublisher<Data?, Never>
  internal var accountsListPublisher:
    () -> AnyPublisher<
      Array<(accountWithProfile: AccountWithProfile, avatarImagePublisher: AnyPublisher<Data?, Never>)>, Never
    >
  internal var presentAccountDetails: @MainActor () -> Void
  internal var signOut: @MainActor () -> Void
  internal var presentAccountSwitch: @MainActor (Account) -> Void
  internal var presentManageAccounts: @MainActor () -> Void
}

extension AccountMenuController: UIController {

  internal typealias Context = Void

  internal static func instance(
    in context: Context,
    with features: inout Features,
    cancellables: Cancellables
  ) throws -> Self {
    let features: Features = features

    let currentAccount: Account = try features.sessionAccount()

    let diagnostics: OSDiagnostics = features.instance()
    let asyncExecutor: AsyncExecutor = try features.instance()

    let accounts: Accounts = try features.instance()
    let session: Session = try features.instance()
    let currentAccountDetails: AccountDetails = try features.instance(context: currentAccount)

    let navigationToSelf: NavigationToAccountMenu = try features.instance()
    let navigationToAuthorization: NavigationToAuthorization = try features.instance()
    let navigationToAccountDetails: NavigationToAccountDetails = try features.instance()
    let navigationToManageAccounts: NavigationToManageAccounts = try features.instance()

    let currentAccountWithProfile = try currentAccountDetails.profile()

    typealias AccountsListItem = (
      accountWithProfile: AccountWithProfile, avatarImagePublisher: AnyPublisher<Data?, Never>
    )

    nonisolated func accountsListPublisher() -> AnyPublisher<Array<AccountsListItem>, Never> {
      accounts
        .updates
        .map { () -> Array<AccountsListItem> in
          var listItems:
            Array<(accountWithProfile: AccountWithProfile, avatarImagePublisher: AnyPublisher<Data?, Never>)> = .init()

          for storedAccount in accounts.storedAccounts() {
            guard
              storedAccount != currentAccount,
              let accountDetails: AccountDetails = try? await features.instance(context: storedAccount),
              let accountWithProfile: AccountWithProfile = try? accountDetails.profile()
            else { continue }  // skip current account

            listItems
              .append(
                (
                  accountWithProfile: accountWithProfile,
                  avatarImagePublisher: Just(Void())
                    .asyncMap {
                      try? await accountDetails.avatarImage()
                    }
                    .eraseToAnyPublisher()
                )
              )
          }
          return listItems
        }
        .asPublisher()
    }

    func currentAcountAvatarImagePublisher() -> AnyPublisher<Data?, Never> {
      Just(Void())
        .asyncMap {
          try? await currentAccountDetails.avatarImage()
        }
        .eraseToAnyPublisher()
    }

    func dismiss() {
      asyncExecutor.schedule(.reuse) {
        do {
          try await navigationToSelf.revert()
        }
        catch {
          diagnostics
            .log(
              error: error,
              info: .message(
                "Navigation back from account menu failed!"
              )
            )
        }
      }
    }

    func presentAccountDetails() {
      asyncExecutor.schedule(.reuse) {
        do {
          try await navigationToSelf.revert()
          try await navigationToAccountDetails.perform()
        }
        catch {
          diagnostics
            .log(
              error: error,
              info: .message(
                "Navigation to account details failed!"
              )
            )
        }
      }
    }

    func signOut() {
      cancellables.executeAsync {
        await session.close(.none)
      }
    }

    func presentAccountSwitch(account: Account) {
      asyncExecutor.schedule(.reuse) {
        do {
          try await navigationToSelf.revert()
          try await navigationToAuthorization.perform(context: account)
        }
        catch {
          diagnostics
            .log(
              error: error,
              info: .message(
                "Navigation to account switch failed!"
              )
            )
        }
      }
    }

    func presentManageAccounts() {
      asyncExecutor.schedule(.reuse) {
        do {
          try await navigationToSelf.revert()
          try await navigationToManageAccounts.perform()
        }
        catch {
          diagnostics
            .log(
              error: error,
              info: .message(
                "Navigation to manage accounts failed!"
              )
            )
        }
      }
    }

    return Self(
      currentAccountWithProfile: currentAccountWithProfile,
      currentAcountAvatarImagePublisher: currentAcountAvatarImagePublisher,
      accountsListPublisher: accountsListPublisher,
      presentAccountDetails: presentAccountDetails,
      signOut: signOut,
      presentAccountSwitch: presentAccountSwitch,
      presentManageAccounts: presentManageAccounts
    )
  }
}
