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
import UIComponents

internal struct WindowController {

  internal var screenStateDispositionPublisher: () -> AnyPublisher<ScreenStateDisposition, Never>
}

extension WindowController {

  internal enum ScreenStateDisposition: Equatable {

    case useInitialScreenState(for: Account?)
    case useCachedScreenState(for: Account)
    case authorize(Account, message: LocalizedMessage?)
  }
}
extension WindowController: UIController {

  internal typealias Context = Void

  internal static func instance(
    in context: Void,
    with features: FeatureFactory,
    cancellables: Cancellables
  ) -> Self {

    let accountSession: AccountSession = features.instance()

    let screenStateDispositionSubject: CurrentValueSubject<ScreenStateDisposition, Never> = .init(
      .useInitialScreenState(for: .none)
    )

    Publishers.Merge(
      accountSession
        .authorizationPromptPresentationPublisher()
        .compactMap { (promptRequest: AuthorizationPromptRequest) -> ScreenStateDisposition? in
          switch screenStateDispositionSubject.value {
          case .authorize:
            return .none
          case .useCachedScreenState , .useInitialScreenState:
              return .authorize(promptRequest.account, message: promptRequest.message)
          }
        },
      accountSession
        .statePublisher()
        .removeDuplicates()
        .dropFirst()
        .compactMap { sessionState -> ScreenStateDisposition? in
          switch (sessionState, screenStateDispositionSubject.value) {
          // authorized after prompting (from signed in state)
          case let (.authorized(account), .authorize(promptedAccount, _))
          where promptedAccount == account:
            return .useCachedScreenState(for: account)

          // switched to same account (from signed in state)
          case let (.authorized(account), .useInitialScreenState(previousAccount))
          where account == previousAccount:
            return .useInitialScreenState(for: account)

          // switched to same account (from signed in state)
          case let (.authorized(account), .useCachedScreenState(previousAccount))
          where account == previousAccount:
            return .useInitialScreenState(for: account)

          // initially authorized (from signed out state)
          case let (.authorized(account), .useInitialScreenState),
            let (.authorized(account), .authorize):
            return .useInitialScreenState(for: account)

          // switched to other account (from signed in state)
          case let (.authorized(account), .useCachedScreenState):
            return .useInitialScreenState(for: account)

          // passphrase cache cleared or started authorization for other account
          case (.authorizationRequired, _):
            return .none

          // no change at all (authorization screen displayed without session)
          case (.none, .authorize), (.none, .useInitialScreenState(.none)):
            return .none

          // signed out
          case (.none, .useInitialScreenState(.some)),
            (.none, .useCachedScreenState):
            return .useInitialScreenState(for: .none)
          }
        }
    )
    .subscribe(screenStateDispositionSubject)
    .store(in: cancellables)

    func screenStateDispositionPublisher() -> AnyPublisher<ScreenStateDisposition, Never> {
      screenStateDispositionSubject
        .filter { [unowned features] disposition in
          switch disposition {
          case .authorize, .useCachedScreenState:
            return true
          case .useInitialScreenState:
            // We are blocking automatic screen changes while
            // account transfer is in progress (from QR code scanning
            // up to successfull authorization)
            return !features.isLoaded(AccountTransfer.self)
          }
        }
        .eraseToAnyPublisher()
    }

    return Self(
      screenStateDispositionPublisher: screenStateDispositionPublisher
    )
  }
}
