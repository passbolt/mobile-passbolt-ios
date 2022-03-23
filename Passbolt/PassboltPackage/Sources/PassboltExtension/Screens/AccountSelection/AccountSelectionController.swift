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

  internal var accountsPublisher: @MainActor () -> AnyPublisher<Array<AccountSelectionListItem>, Never>
  internal var screenMode: @MainActor () -> AccountSelectionController.Mode
}

extension AccountSelectionController {

  internal enum Mode {

    case switchAccount
    case signIn
  }
}

extension AccountSelectionController: UIController {

  internal typealias Context = AccountSelectionController.Mode

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

    func accountsPublisher() -> AnyPublisher<Array<AccountSelectionListItem>, Never> {
      Publishers.CombineLatest(
        storedAccountsWithProfilesSubject,
        accountSession.statePublisher()
      )
      .map { accountsWithProfiles, sessionState -> Array<AccountSelectionListItem> in
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
              listModePublisher: Empty().eraseToAnyPublisher()
            )

            return .account(item)
          }
      }
      .eraseToAnyPublisher()
    }

    func screenMode() -> AccountSelectionController.Mode {
      context
    }

    return Self(
      accountsPublisher: accountsPublisher,
      screenMode: screenMode
    )
  }
}
