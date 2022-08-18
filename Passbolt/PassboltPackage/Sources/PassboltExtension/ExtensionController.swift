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

internal struct ExtensionController {

  internal var destinationPublisher: @MainActor () -> AnyPublisher<Destination, Never>
}

extension ExtensionController {

  enum Destination: Equatable {

    case authorization(Account)
    case accountSelection(lastUsedAccount: Account?)
    case home(Account)
    case mfaRequired
  }
}

extension ExtensionController: UIController {

  internal typealias Context = Void

  internal static func instance(
    in context: Context,
    with features: FeatureFactory,
    cancellables: Cancellables
  ) async throws -> ExtensionController {

    let accounts: Accounts = try await features.instance()
    let session: Session = try await features.instance()

    let storedAccounts: Array<Account> = accounts.storedAccounts()
    let initialAccount: Account?
    if let lastUsedAccount: Account = accounts.lastUsedAccount() {
      initialAccount = lastUsedAccount
    }
    else if storedAccounts.count == 1, let singleAccount: Account = storedAccounts.first {
      initialAccount = singleAccount
    }
    else {
      initialAccount = .none
    }

    let currentDestination: UpdatableValue<Destination> = .init(
      initial: .accountSelection(lastUsedAccount: initialAccount),
      updatesSequence: session.updatesSequence,
      update: {
        let currentAccount: Account? =
          try? await session
          .currentAccount()
        let pendingAuthorization: SessionAuthorizationRequest? =
          await session
          .pendingAuthorization()

        switch (currentAccount, pendingAuthorization) {
        case let (.some(account), .none):
          return .home(account)

        case let (.some(account), .passphrase):
          return .authorization(account)

        case (.some, .mfa):
          return .mfaRequired

        case (.none, _):
          return .accountSelection(lastUsedAccount: .none)
        }
      }
    )

    func destinationPublisher() -> AnyPublisher<Destination, Never> {
      currentDestination
        .asPublisher()
    }

    return Self(
      destinationPublisher: destinationPublisher
    )
  }
}
