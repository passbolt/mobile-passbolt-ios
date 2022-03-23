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
import NetworkClient
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
    with features: FeatureFactory,
    cancellables: Cancellables
  ) async throws -> AccountSelectionController {
    let accounts: Accounts = try await features.instance()
    let accountSession: AccountSession = try await features.instance()
    let accountSettings: AccountSettings = try await features.instance()
    let diagnostics: Diagnostics = try await features.instance()
    let networkClient: NetworkClient = try await features.instance()

    var initialAccountsWithProfiles: Array<AccountWithProfile> = .init()
    for account in await accounts.storedAccounts() {
      try await initialAccountsWithProfiles.append(accountSettings.accountWithProfile(account))
    }
    let storedAccountsWithProfilesSubject: CurrentValueSubject<Array<AccountWithProfile>, Never> = .init(
      initialAccountsWithProfiles
    )

    let listModeSubject: CurrentValueSubject<AccountSelectionListMode, Never> = .init(.selection)
    let removeAccountAlertPresentationSubject: PassthroughSubject<Void, Never> = .init()
    let addAccountPresentationSubject: PassthroughSubject<Bool, Never> = .init()

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
              title: accountWithProfile.label,
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

    func removeAccount(_ account: Account) -> AnyPublisher<Void, Error> {
      cancellables.executeOnStorageAccessActorWithPublisher {
        let result: Result<Void, Error> = accounts.removeAccount(account)
        var accountsWithProfiles: Array<AccountWithProfile> = .init()
        for account in accounts.storedAccounts() {
          try accountsWithProfiles.append(accountSettings.accountWithProfile(account))
        }
        storedAccountsWithProfilesSubject.send(accountsWithProfiles)

        return try result.get()
      }
    }

    func addAccount() {
      cancellables.executeOnFeaturesActor {
        addAccountPresentationSubject.send(features.isLoaded(AccountTransfer.self))
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
