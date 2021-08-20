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
import UIComponents

internal struct ExtensionController {

  internal var destinationPublisher: () -> AnyPublisher<Destination, Never>
}

extension ExtensionController {

  enum Destination: Equatable {

    case authorization(Account)
    case accountSelection(lastUsedAccount: Account?)
    case home(Account)
  }
}

extension ExtensionController: UIController {

  internal typealias Context = Void

  internal static func instance(
    in context: Context,
    with features: FeatureFactory,
    cancellables: Cancellables
  ) -> ExtensionController {

    let accounts: Accounts = features.instance()
    let accountSession: AccountSession = features.instance()

    accountSession
      .authorizationPromptPresentationPublisher()
      .sink { _ in
        // We are not using authorization prompt in extension,
        // Instead when authorization would be required we treat it as logout.
        // Typical use of extension is to select password (and search for it if there is none)
        // while session (and passphrase cache) lasts for 5 minutes.
        accountSession.close()
      }
      .store(in: cancellables)

    func destinationPublisher() -> AnyPublisher<Destination, Never> {
      accountSession
        .statePublisher()
        .compactMap { state -> Destination? in
          switch state {
          case let .authorized(account):
            return .home(account)

          case .authorizationRequired:
            return .none // ignored

          case let .none(lastUsedAccount):
            if let lastUsedAccount = lastUsedAccount {
              return .accountSelection(lastUsedAccount: lastUsedAccount)
            }
            else {
              let storedAccounts: Array<Account> = accounts.storedAccounts()
              if storedAccounts.count == 1 {
                return .accountSelection(lastUsedAccount: storedAccounts.first)
              }
              else {
                return .accountSelection(lastUsedAccount: nil)
              }
            }
          }
        }
        .eraseToAnyPublisher()
    }

    return Self(
      destinationPublisher: destinationPublisher
    )
  }
}
