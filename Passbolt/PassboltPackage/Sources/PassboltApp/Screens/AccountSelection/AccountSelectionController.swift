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

import AccountSetup
import Accounts
import FeatureScopes
import NetworkOperations
import Session
import SharedUIComponents
import UIComponents

internal struct AccountSelectionController {

  internal var accountsPublisher: @MainActor () -> AnyPublisher<Array<AccountSelectionListItem>, Never>
  internal var listModePublisher: @MainActor () -> AnyPublisher<AccountSelectionListMode, Never>
  internal var removeAccountAlertPresentationPublisher: @MainActor () -> AnyPublisher<Void, Never>
  internal var presentRemoveAccountAlert: @MainActor () -> Void
  internal var removeAccount: @MainActor (Account) -> AnyPublisher<Void, Error>
  internal var addAccount: @MainActor () -> Void
  internal var addAccountPresentationPublisher: @MainActor () -> AnyPublisher<Bool, Never>
  internal var toggleMode: @MainActor () -> Void
  internal var shouldHideTitle: @MainActor () -> Bool
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
    with features: inout Features,
    cancellables: Cancellables
  ) throws -> AccountSelectionController {
    let features: Features = features
    let accounts: Accounts = try features.instance()
    let session: Session = try features.instance()
    let mediaDownloadNetworkOperation: MediaDownloadNetworkOperation = try features.instance()

    let listModeSubject: CurrentValueSubject<AccountSelectionListMode, Never> = .init(.selection)
    let removeAccountAlertPresentationSubject: PassthroughSubject<Void, Never> = .init()
    let addAccountPresentationSubject: PassthroughSubject<Bool, Never> = .init()

    func accountsPublisher() -> AnyPublisher<Array<AccountSelectionListItem>, Never> {
      accounts
        .updates
        .asAnyAsyncSequence()
        .map { _ -> Array<AccountSelectionListItem> in
          let currentAccount: Account? = try? await session.currentAccount()
          var listItems: Array<AccountSelectionListItem> = .init()
          for storedAccount in accounts.storedAccounts() {
            let item: AccountSelectionCellItem = AccountSelectionCellItem(
              account: storedAccount.account,
              title: storedAccount.label,
              subtitle: storedAccount.username,
              isCurrentAccount: storedAccount.account == currentAccount,
              imagePublisher:
                Just(Void())
                .asyncMap {
                  try? await mediaDownloadNetworkOperation.execute(storedAccount.avatarImageURL)
                }
                .eraseToAnyPublisher(),
              listModePublisher: listModeSubject.eraseToAnyPublisher()
            )

            listItems.append(.account(item))
          }
          return listItems
        }
        .asThrowingPublisher()
        .replaceError(with: .init())
        .map { (listItems: Array<AccountSelectionListItem>) in
          listModeSubject
            .map { (mode: AccountSelectionListMode) -> Array<AccountSelectionListItem> in
              if mode == .selection && !listItems.isEmpty {
                var listItems: Array<AccountSelectionListItem> = listItems
                listItems.append(.addAccount(.default))
                return listItems
              }
              else {
                return listItems
              }
            }
        }
        .switchToLatest()
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

    func removeAccount(_ account: Account) -> AnyPublisher<Void, Error> {
      cancellables.executeAsyncWithPublisher {
        try accounts.removeAccount(account)
      }
    }

    func addAccount() {
      cancellables.executeOnMainActor {
        #warning(
          "FIXME: find a way to know when account transfer is already in progress to make it unavailable to perform again"
        )
        addAccountPresentationSubject.send(false)
      }
    }

    func addAccountPresentationPublisher() -> AnyPublisher<Bool, Never> {
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
