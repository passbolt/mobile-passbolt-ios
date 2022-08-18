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
import Session
import UIComponents

internal struct AccountMenuController {

  internal let currentAccountWithProfile: AccountWithProfile
  internal let navigation: ComponentNavigation<Void>
  internal var currentAcountAvatarImagePublisher: @MainActor () -> AnyPublisher<Data?, Never>
  internal var accountsListPublisher:
    () -> AnyPublisher<
      Array<(accountWithProfile: AccountWithProfile, avatarImagePublisher: AnyPublisher<Data?, Never>)>, Never
    >
  internal var dismissPublisher: @MainActor () -> AnyPublisher<Void, Never>
  internal var presentAccountDetails: @MainActor () -> Void
  internal var accountDetailsPresentationPublisher: @MainActor () -> AnyPublisher<AccountWithProfile, Never>
  internal var signOut: @MainActor () -> Void
  internal var presentAccountSwitch: @MainActor (Account) -> Void
  internal var accountSwitchPresentationPublisher: @MainActor () -> AnyPublisher<Account, Never>
  internal var presentManageAccounts: @MainActor () -> Void
  internal var manageAccountsPresentationPublisher: @MainActor () -> AnyPublisher<Void, Never>
}

extension AccountMenuController: UIController {

  internal typealias Context = (
    accountWithProfile: AccountWithProfile,
    navigation: ComponentNavigation<Void>
  )

  internal static func instance(
    in context: Context,
    with features: FeatureFactory,
    cancellables: Cancellables
  ) async throws -> Self {
    let accounts: Accounts = try await features.instance()
    let session: Session = try await features.instance()
    let currentAccountDetails: AccountDetails = try await features.instance(context: context.accountWithProfile.account)

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
              storedAccount != context.accountWithProfile.account,
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

    let dismissSubject: PassthroughSubject<Void, Never> = .init()
    func dismiss() {
      dismissSubject.send()
    }

    func dismissPublisher() -> AnyPublisher<Void, Never> {
      dismissSubject.eraseToAnyPublisher()
    }

    let accountDetailsPresentationSubject: PassthroughSubject<AccountWithProfile, Never> = .init()
    func presentAccountDetails() {
      accountDetailsPresentationSubject
        .send(context.accountWithProfile)
    }

    func accountDetailsPresentationPublisher() -> AnyPublisher<AccountWithProfile, Never> {
      accountDetailsPresentationSubject
        .eraseToAnyPublisher()
    }

    func signOut() {
      cancellables.executeAsync {
        await session.close(.none)
      }
    }

    let accountSwitchPresentationSubject: PassthroughSubject<Account, Never> = .init()
    func presentAccountSwitch(account: Account) {
      accountSwitchPresentationSubject.send(account)
    }

    func accountSwitchPresentationPublisher() -> AnyPublisher<Account, Never> {
      accountSwitchPresentationSubject.eraseToAnyPublisher()
    }

    let manageAccountsPresentationSubject: PassthroughSubject<Void, Never> = .init()
    func presentManageAccounts() {
      manageAccountsPresentationSubject.send()
    }

    func manageAccountsPresentationPublisher() -> AnyPublisher<Void, Never> {
      manageAccountsPresentationSubject.eraseToAnyPublisher()
    }

    return Self(
      currentAccountWithProfile: context.accountWithProfile,
      navigation: context.navigation,
      currentAcountAvatarImagePublisher: currentAcountAvatarImagePublisher,
      accountsListPublisher: accountsListPublisher,
      dismissPublisher: dismissPublisher,
      presentAccountDetails: presentAccountDetails,
      accountDetailsPresentationPublisher: accountDetailsPresentationPublisher,
      signOut: signOut,
      presentAccountSwitch: presentAccountSwitch,
      accountSwitchPresentationPublisher: accountSwitchPresentationPublisher,
      presentManageAccounts: presentManageAccounts,
      manageAccountsPresentationPublisher: manageAccountsPresentationPublisher
    )
  }
}
