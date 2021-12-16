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
import NetworkClient
import UIComponents

internal struct AccountMenuController {

  internal let currentAccountWithProfile: AccountWithProfile
  internal let parentComponent: AnyUIComponent
  internal var currentAcountAvatarImagePublisher: () -> AnyPublisher<Data?, Never>
  internal var accountsListPublisher:
    () -> AnyPublisher<
      Array<(accountWithProfile: AccountWithProfile, avatarImagePublisher: AnyPublisher<Data?, Never>)>, Never
    >
  internal var dismiss: () -> Void
  internal var dismissPublisher: () -> AnyPublisher<Void, Never>
  internal var presentAccountDetails: () -> Void
  internal var accountDetailsPresentationPublisher: () -> AnyPublisher<AccountWithProfile, Never>
  internal var signOut: () -> Void
  internal var presentAccountSwitch: (Account) -> Void
  internal var accountSwitchPresentationPublisher: () -> AnyPublisher<Account, Never>
  internal var presentManageAccounts: () -> Void
  internal var manageAccountsPresentationPublisher: () -> AnyPublisher<Void, Never>
}

extension AccountMenuController: UIController {

  internal typealias Context = (
    accountWithProfile: AccountWithProfile,
    parentComponent: AnyUIComponent
  )

  internal static func instance(
    in context: Context,
    with features: FeatureFactory,
    cancellables: Cancellables
  ) -> Self {
    let accounts: Accounts = features.instance()
    let accountSession: AccountSession = features.instance()
    let networkClient: NetworkClient = features.instance()
    let accountSettings: AccountSettings = features.instance()

    let storedAccountsWithProfilesSubject: CurrentValueSubject<Array<AccountWithProfile>, Never> = .init(
      accounts
        .storedAccounts()
        .filter { $0 != context.accountWithProfile.account }
        .compactMap(accountSettings.accountWithProfile)
    )
    accountSettings
      .updatedAccountIDsPublisher()
      .sink { updatedAccountID in
        storedAccountsWithProfilesSubject
          .send(
            accounts
              .storedAccounts()
              .filter { $0 != context.accountWithProfile.account }
              .compactMap(accountSettings.accountWithProfile)
          )
      }
      .store(in: cancellables)

    func currentAcountAvatarImagePublisher() -> AnyPublisher<Data?, Never> {
      networkClient
        .mediaDownload
        .make(using: .init(urlString: context.accountWithProfile.avatarImageURL))
        .mapToOptional()
        .replaceError(with: nil)
        .eraseToAnyPublisher()
    }

    func accountsListPublisher() -> AnyPublisher<
      Array<
        (
          accountWithProfile: AccountWithProfile,
          avatarImagePublisher: AnyPublisher<Data?, Never>
        )
      >,
      Never
    > {
      storedAccountsWithProfilesSubject
        .map {
          (accounts: Array<AccountWithProfile>)
            -> Array<
              (
                accountWithProfile: AccountWithProfile,
                avatarImagePublisher: AnyPublisher<Data?, Never>
              )
            > in
          accounts
            .map {
              (accountWithProfile: AccountWithProfile)
                -> (
                  accountWithProfile: AccountWithProfile,
                  avatarImagePublisher: AnyPublisher<Data?, Never>
                ) in
              (
                accountWithProfile: accountWithProfile,
                avatarImagePublisher: networkClient
                  .mediaDownload
                  .make(
                    using: .init(
                      urlString: accountWithProfile.avatarImageURL
                    )
                  )
                  .mapToOptional()
                  .replaceError(with: nil)
                  .eraseToAnyPublisher()
              )
            }
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
      accountSession.close()
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
      parentComponent: context.parentComponent,
      currentAcountAvatarImagePublisher: currentAcountAvatarImagePublisher,
      accountsListPublisher: accountsListPublisher,
      dismiss: dismiss,
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
