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
import CommonModels
import Session
import UIComponents

internal struct WindowController {

  internal var initialAccount: @Sendable () -> Account?
  internal var screenStateDispositionSequence: @MainActor () -> AnyAsyncSequence<ScreenStateDisposition>
}

extension WindowController {

  internal enum ScreenStateDisposition: Equatable {

    case useInitialScreenState
    case useAuthorizedScreenState(for: Account)
    case requestPassphrase(Account, message: DisplayableString?)
    case requestMFA(Account, providers: Array<SessionMFAProvider>)
  }
}

extension WindowController: UIController {

  internal typealias Context = Void

  internal static func instance(
    in context: Void,
    with features: inout Features,
    cancellables: Cancellables
  ) throws -> Self {
    let accounts: Accounts = try features.instance()
    let sessionStateChangeSubscription: EventSubscription<SessionStateChangeEvent> = SessionStateChangeEvent.subscribe()

    @Sendable nonisolated func initialAccount() -> Account? {
      let storedAccounts: Array<AccountWithProfile> = accounts.storedAccounts()
      if let lastUsedAccount: AccountWithProfile = accounts.lastUsedAccount() {
        return lastUsedAccount.account
      }
      else if storedAccounts.count == 1, let singleAccount: AccountWithProfile = storedAccounts.first {
        return singleAccount.account
      }
      else {
        return .none
      }
    }

    @Sendable nonisolated func screenStateDispositionSequence() -> AnyAsyncSequence<ScreenStateDisposition> {
      sessionStateChangeSubscription
        .map { (event: SessionStateChangeEvent) -> ScreenStateDisposition in
          switch event {
          case .authorized(let account):
            return .useAuthorizedScreenState(for: account)
          case .requestedPassphrase(let account):
            return .requestPassphrase(account, message: .none)
          case .requestedMFA(let account, let providers):
            return .requestMFA(account, providers: providers)
          case .closed:
            return .useInitialScreenState
          }
        }
        .asAnyAsyncSequence()
    }

    return Self(
      initialAccount: initialAccount,
      screenStateDispositionSequence: screenStateDispositionSequence
    )
  }
}
