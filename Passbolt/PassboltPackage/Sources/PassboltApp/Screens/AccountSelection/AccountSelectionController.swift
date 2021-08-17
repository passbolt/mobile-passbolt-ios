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
import SharedUIComponents
import UIComponents

internal struct AccountSelectionController {

  internal var accountsPublisher: () -> AnyPublisher<Array<AccountSelectionListItem>, Never>
  internal var listModePublisher: () -> AnyPublisher<AccountSelectionListMode, Never>
  internal var removeAccountAlertPresentationPublisher: () -> AnyPublisher<Void, Never>
  internal var presentRemoveAccountAlert: () -> Void
  internal var removeAccount: (Account) -> Result<Void, TheError>
  internal var addAccount: () -> Void
  internal var addAccountPresentationPublisher: () -> AnyPublisher<Void, Never>
  internal var toggleMode: () -> Void
  internal var shouldHideTitle: () -> Bool
}

extension AccountSelectionController {

  internal struct TitleHidden {

    internal var value: Bool
  }
}

extension AccountSelectionController: UIController {

  internal typealias Context = TitleHidden

  internal static func instance(
    in context: Context,
    with features: FeatureFactory,
    cancellables: Cancellables
  ) -> AccountSelectionController {
    let accounts: Accounts = features.instance()
    let accountSession: AccountSession = features.instance()
    let accountSettings: AccountSettings = features.instance()
    let diagnostics: Diagnostics = features.instance()
    let networkClient: NetworkClient = features.instance()

    let storedAccountsWithProfilesSubject: CurrentValueSubject<Array<AccountWithProfile>, Never> = .init(
      accounts
        .storedAccounts()
        .compactMap(accountSettings.accountWithProfile)
    )

    let listModeSubject: CurrentValueSubject<AccountSelectionListMode, Never> = .init(.selection)
    let removeAccountAlertPresentationSubject: PassthroughSubject<Void, Never> = .init()
    let addAccountPresentationSubject: PassthroughSubject<Void, Never> = .init()

    func accountsPublisher() -> AnyPublisher<Array<AccountSelectionListItem>, Never> {
      Publishers.CombineLatest3(
        storedAccountsWithProfilesSubject,
        listModeSubject,
        accountSession.statePublisher()
      )
      .map { accountsWithProfiles, mode, sessionState -> Array<AccountSelectionListItem> in
        var items: Array<AccountSelectionListItem> =
          accountsWithProfiles
          .map { accountWithProfile in
            let imageDataPublisher: AnyPublisher<Data?, Never> = Deferred { () -> AnyPublisher<Data?, Never> in
              networkClient.mediaDownload.make(
                using: .init(urlString: accountWithProfile.avatarImageURL)
              )
              .map { data -> Data? in data }
              .collectErrorLog(using: diagnostics)
              .replaceError(with: nil)
              .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()

            func isCurrentAccount() -> Bool {
              switch sessionState {
              case let .authorized(account) where account.localID == accountWithProfile.localID,
                let .authorizationRequired(account) where account.localID == accountWithProfile.localID:
                return true
              case _:
                return false
              }
            }

            let item: AccountSelectionCellItem = AccountSelectionCellItem(
              account: accountWithProfile.account,
              title: "\(accountWithProfile.firstName) \(accountWithProfile.lastName)",
              subtitle: accountWithProfile.username,
              isCurrentAccount: isCurrentAccount(),
              imagePublisher: imageDataPublisher.eraseToAnyPublisher(),
              listModePublisher: listModeSubject.eraseToAnyPublisher()
            )

            return .account(item)
          }

        if mode == .selection && !items.isEmpty {
          items.append(.addAccount(.default))
        }
        else {
          /* */
        }

        return items
      }
      .eraseToAnyPublisher()
    }

    func listModePublisher() -> AnyPublisher<AccountSelectionListMode, Never> {
      listModeSubject.eraseToAnyPublisher()
    }

    func removeAccountAlertPresentationPublisher() -> AnyPublisher<Void, Never> {
      removeAccountAlertPresentationSubject.eraseToAnyPublisher()
    }

    func presentRemoveAccountAlert() {
      removeAccountAlertPresentationSubject.send(Void())
    }

    func removeAccount(_ account: Account) -> Result<Void, TheError> {
      let result: Result<Void, TheError> = accounts.removeAccount(account)
      let storedAccounts: Array<AccountWithProfile> =
        accounts
        .storedAccounts()
        .compactMap(accountSettings.accountWithProfile)

      storedAccountsWithProfilesSubject.send(storedAccounts)

      return result
    }

    func addAccount() {
      addAccountPresentationSubject.send()
    }

    func addAccountPresentationPublisher() -> AnyPublisher<Void, Never> {
      addAccountPresentationSubject.eraseToAnyPublisher()
    }

    func toggleMode() {
      switch listModeSubject.value {
      case .selection:
        listModeSubject.send(.removal)
      case .removal:
        listModeSubject.send(.selection)
      }
    }

    func shouldHideTitle() -> Bool {
      context.value
    }

    return Self(
      accountsPublisher: accountsPublisher,
      listModePublisher: listModePublisher,
      removeAccountAlertPresentationPublisher: removeAccountAlertPresentationPublisher,
      presentRemoveAccountAlert: presentRemoveAccountAlert,
      removeAccount: removeAccount,
      addAccount: addAccount,
      addAccountPresentationPublisher: addAccountPresentationPublisher,
      toggleMode: toggleMode,
      shouldHideTitle: shouldHideTitle
    )
  }
}
