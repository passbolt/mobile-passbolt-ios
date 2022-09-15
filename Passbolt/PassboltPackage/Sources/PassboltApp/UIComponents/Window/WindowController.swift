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

  internal var screenStateDispositionSequence: @MainActor () -> AnyAsyncSequence<ScreenStateDisposition>
}

extension WindowController {

  internal enum ScreenStateDisposition: Equatable {

    case useInitialScreenState(for: Account?)
    case useCachedScreenState(for: Account)
    case requestPassphrase(Account, message: DisplayableString?)
    case requestMFA(Account, providers: Array<SessionMFAProvider>)
  }
}

extension WindowController: UIController {

  internal typealias Context = Void

  internal static func instance(
    in context: Void,
    with features: FeatureFactory,
    cancellables: Cancellables
  ) async throws -> Self {
    let session: Session = try await features.instance()
    let accounts: Accounts = try await features.instance()

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
    let lastDisposition: CriticalState<ScreenStateDisposition> = .init(
      .useInitialScreenState(for: initialAccount)
    )

    func screenStateDispositionSequence() -> AnyAsyncSequence<ScreenStateDisposition> {
      merge(
        AnyAsyncSequence([lastDisposition.get(\.self)]),
        session
          .updatesSequence
          .dropFirst()  // we have predefined initial state
          .compactMap { () -> ScreenStateDisposition? in
            async let currentAccount: Account? = session.currentAccount()
            async let currentAuthorizationRequest: SessionAuthorizationRequest? = session.pendingAuthorization()

            switch (try? await currentAccount, await currentAuthorizationRequest, lastDisposition.get(\.self)) {

            case  // fully authorized after prompting
            let (.some(account), .none, .requestPassphrase),
              let (.some(account), .none, .requestMFA):
              return .useCachedScreenState(for: account)

            case  // fully authorized initially
            let (.some(account), .none, .useCachedScreenState),
              let (.some(account), .none, .useInitialScreenState):
              return .useInitialScreenState(for: account)

            case  // passphrase required
            let (_, .passphrase(account), _):
              return .requestPassphrase(account, message: .none)

            case  // mfa required
            let (_, .mfa(account, providers), _):
              return .requestMFA(account, providers: providers)

            case  // signed out
            (.none, .none, _):
              return .useInitialScreenState(for: .none)
            }
          }
      )
      .map { (disposition: ScreenStateDisposition) -> ScreenStateDisposition in
        lastDisposition.set(\.self, disposition)
        return disposition
      }
      .asAnyAsyncSequence()
    }

    return Self(
      screenStateDispositionSequence: screenStateDispositionSequence
    )
  }
}
