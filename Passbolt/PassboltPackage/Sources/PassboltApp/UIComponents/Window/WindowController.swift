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

    case useInitialScreenState(for: Account.LocalID?)
    case useCachedScreenState(for: Account.LocalID)
    case authorize(Account.LocalID)
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
        .map { promptedAccountID -> ScreenStateDisposition in
          .authorize(promptedAccountID)
        },
      accountSession
        .statePublisher()
        .removeDuplicates()
        .dropFirst()
        .compactMap { sessionState -> ScreenStateDisposition? in
          switch (sessionState, screenStateDispositionSubject.value) {
          // signed in
          case let (.authorized(account), .authorize(promptedAccountID))
          where promptedAccountID == account.localID:
            return .useCachedScreenState(for: account.localID)

          case let (.authorized(account), .useInitialScreenState(accountID))
          where accountID == account.localID:
            return .useInitialScreenState(for: accountID)

          case let (.authorized(account), .useInitialScreenState),
            let (.authorized(account), .authorize):
            return .useInitialScreenState(for: account.localID)

          case let (.authorized(account), .useCachedScreenState(accountID))
          where account.localID == accountID:
            return .useInitialScreenState(for: accountID)

          case (.authorized, .useCachedScreenState):
            return .none

          case (.authorizationRequired, _):
            return .none

          case (.none, .authorize), (.none, .useInitialScreenState(.none)):
            return .none

          case (.none, .useInitialScreenState(.some)),
            (.none, .useCachedScreenState):
            return .useInitialScreenState(for: .none)
          }
        }
    )
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
    .subscribe(screenStateDispositionSubject)
    .store(in: cancellables)

    func screenStateDispositionPublisher() -> AnyPublisher<ScreenStateDisposition, Never> {
      screenStateDispositionSubject
        .eraseToAnyPublisher()
    }

    return Self(
      screenStateDispositionPublisher: screenStateDispositionPublisher
    )
  }
}
