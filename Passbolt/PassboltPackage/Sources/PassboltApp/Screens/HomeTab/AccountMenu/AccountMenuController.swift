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
import FeatureScopes
import NetworkOperations
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
  internal var presentAccountDetails: @MainActor () async throws -> Void
  internal var signOut: @MainActor () async throws -> Void
  internal var presentAccountSwitch: @MainActor (Account) async throws -> Void
  internal var presentManageAccounts: @MainActor () async throws -> Void
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

    let accounts: Accounts = try features.instance()
    let session: Session = try features.instance()
    let currentAccountDetails: AccountDetails = try features.instance()

    let navigationToSelf: NavigationToAccountMenu = try features.instance()
    let navigationToAuthorization: NavigationToAuthorization = try features.instance()
    let navigationToAccountDetails: NavigationToAccountDetails = try features.instance()
    let navigationToManageAccounts: NavigationToManageAccounts = try features.instance()
    let mediaDownloadNetworkOperation: MediaDownloadNetworkOperation = try features.instance()

    let currentAccountWithProfile = try currentAccountDetails.profile()

    typealias AccountsListItem = (
      accountWithProfile: AccountWithProfile, avatarImagePublisher: AnyPublisher<Data?, Never>
    )

    nonisolated func accountsListPublisher() -> AnyPublisher<Array<AccountsListItem>, Never> {
      accounts
        .updates
        .asAnyAsyncSequence()
        .map { _ -> Array<AccountsListItem> in
          var listItems:
            Array<(accountWithProfile: AccountWithProfile, avatarImagePublisher: AnyPublisher<Data?, Never>)> = .init()

          for storedAccount in accounts.storedAccounts() where storedAccount.account != currentAccount {  // skip current account

            listItems
              .append(
                (
                  accountWithProfile: storedAccount,
                  avatarImagePublisher: Just(Void())
                    .asyncMap {
                      try? await mediaDownloadNetworkOperation.execute(storedAccount.avatarImageURL)
                    }
                    .eraseToAnyPublisher()
                )
              )
          }
          return listItems
        }
        .asThrowingPublisher()
        .replaceError(with: .init())
        .eraseToAnyPublisher()
    }

    func currentAcountAvatarImagePublisher() -> AnyPublisher<Data?, Never> {
      Just(Void())
        .asyncMap {
          try? await currentAccountDetails.avatarImage()
        }
        .eraseToAnyPublisher()
    }

    func dismiss() async {
      do {
        try await navigationToSelf.revert()
      }
      catch {
        error.logged(
          info: .message(
            "Navigation back from account menu failed!"
          )
        )
      }
    }

    func presentAccountDetails() async {
      do {
        try await navigationToSelf.revert()
        try await navigationToAccountDetails.perform()
      }
      catch {
        error.logged(
          info: .message(
            "Navigation to account details failed!"
          )
        )
      }
    }

    func signOut() async {
      await session.close(.none)
    }

    func presentAccountSwitch(
      account: Account
    ) async {
      do {
        try await navigationToSelf.revert()
        try await navigationToAuthorization.perform(context: account)
      }
      catch {
        error.logged(
          info: .message(
            "Navigation to account switch failed!"
          )
        )
      }
    }

    func presentManageAccounts() async {
      do {
        try await navigationToSelf.revert()
        try await navigationToManageAccounts.perform()
      }
      catch {
        error.logged(
          info: .message(
            "Navigation to manage accounts failed!"
          )
        )
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
