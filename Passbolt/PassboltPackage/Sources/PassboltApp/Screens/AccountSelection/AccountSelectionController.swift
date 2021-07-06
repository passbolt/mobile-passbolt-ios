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

internal enum AccountSelectionMode {

  case selection
  case removal
}

internal struct AccountSelectionController {

  internal var accountsPublisher: () -> AnyPublisher<Array<AccountSelectionListItem>, Never>
  internal var modePublisher: () -> AnyPublisher<AccountSelectionMode, Never>
  internal var presentRemoveAccountAlertPublisher: () -> AnyPublisher<Void, Never>
  internal var presentRemoveAccountAlert: () -> Void
  internal var removeAccount: (Account.LocalID) -> Result<Void, TheError>
  internal var changeMode: (AccountSelectionMode) -> Void
}

extension AccountSelectionController: UIController {

  internal typealias Context = Void

  internal static func instance(
    in context: Context,
    with features: FeatureFactory,
    cancellables: Cancellables
  ) -> AccountSelectionController {
    let accounts: Accounts = features.instance()
    let diagnostics: Diagnostics = features.instance()
    let networkClient: NetworkClient = features.instance()

    let storedAccountSubject: CurrentValueSubject<Array<AccountWithProfile>, Never> = .init(accounts.storedAccounts())
    let modeSubject: CurrentValueSubject<AccountSelectionMode, Never> = .init(.selection)
    let removeAccountAlertSubject: PassthroughSubject<Void, Never> = .init()

    if storedAccountSubject.value.isEmpty {
      storedAccountSubject.send(completion: .finished)
    }

    func storedAccounts() -> AnyPublisher<Array<AccountSelectionListItem>, Never> {
      storedAccountSubject.map { accounts -> AnyPublisher<Array<AccountSelectionListItem>, Never> in
        var items: Array<AccountSelectionListItem> = accounts.map { account in
          let imageDataPublisher: AnyPublisher<Data?, Never> = Deferred { () -> AnyPublisher<Data?, Never> in
            networkClient.mediaDownload.make(
              using: .init(urlString: account.avatarImageURL)
            )
            .map { data -> Data? in data }
            .collectErrorLog(using: diagnostics)
            .replaceError(with: nil)
            .eraseToAnyPublisher()
          }
          .eraseToAnyPublisher()

          let item: AccountSelectionCellItem = AccountSelectionCellItem(
            localID: account.localID,
            title: "\(account.firstName) \(account.lastName)",
            subtitle: account.username,
            imagePublisher: imageDataPublisher.eraseToAnyPublisher(),
            modePublisher: modeSubject.eraseToAnyPublisher()
          )

          return .account(item)
        }

        if modeSubject.value == .selection && !items.isEmpty {
          items.append(.addAccount(.default))
        }
        else { /* */
        }

        return Just(items).eraseToAnyPublisher()
      }
      .switchToLatest()
      .eraseToAnyPublisher()
    }

    func removeAccount(with id: Account.LocalID) -> Result<Void, TheError> {
      let result: Result<Void, TheError> = accounts.removeAccount(id)
      let storedAccounts: Array<AccountWithProfile> = accounts.storedAccounts()

      if storedAccounts.isEmpty {
        storedAccountSubject.send(completion: .finished)
      }
      else {
        storedAccountSubject.send(storedAccounts)
      }

      return result
    }

    return Self(
      accountsPublisher: storedAccounts,
      modePublisher: modeSubject.eraseToAnyPublisher,
      presentRemoveAccountAlertPublisher: removeAccountAlertSubject.eraseToAnyPublisher,
      presentRemoveAccountAlert: { removeAccountAlertSubject.send(()) },
      removeAccount: removeAccount(with:),
      changeMode: modeSubject.send(_:)
    )
  }
}
