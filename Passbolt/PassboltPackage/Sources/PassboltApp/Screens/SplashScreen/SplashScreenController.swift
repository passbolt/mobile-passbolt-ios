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

import Accounts
import UIComponents

internal struct SplashScreenController {

  internal var navigationDestinationPublisher: () -> AnyPublisher<Destination, Never>
  internal var retryFetchConfiguration: () -> AnyPublisher<Void, TheError>
}

extension SplashScreenController {

  internal enum Destination: Equatable {

    case accountSetup
    case accountSelection(Account?)
    case diagnostics
    case home
    case featureConfigFetchError
  }
}

extension SplashScreenController: UIController {

  internal typealias Context = Void

  internal static func instance(
    in context: Context,
    with features: FeatureFactory,
    cancellables: Cancellables
  ) -> Self {
    let accounts: Accounts = features.instance()
    let accountSession: AccountSession = features.instance()
    let featureFlags: FeatureConfig = features.instance()

    let destinationSubject: CurrentValueSubject<Destination?, Never> = .init(nil)

    func fetchConfiguration() -> AnyPublisher<Void, TheError> {
      featureFlags
        .fetchIfNeeded()
        .eraseToAnyPublisher()
    }

    func retryFetchConfiguration() -> AnyPublisher<Void, TheError> {
      fetchConfiguration()
        .handleEvents(receiveCompletion: { completion in
          guard case .finished = completion
          else { return }
          destinationSubject.send(.home)
        })
        .eraseToAnyPublisher()
    }

    func destinationPublisher() -> AnyPublisher<Destination, Never> {
      return destinationSubject.handleEvents(receiveSubscription: { _ in
        guard case .success = accounts.verifyStorageDataIntegrity()
        else {
          return destinationSubject.send(.diagnostics)
        }
        let storedAccounts: Array<Account> = accounts.storedAccounts()
        if storedAccounts.isEmpty {
          return destinationSubject.send(.accountSetup)
        }
        else {
          return accountSession.statePublisher()
            .first()
            .map { state -> AnyPublisher<Destination, Never> in
              switch state {
              case let .none(lastUsed: .some(lastUsedAccount)):
                return Just(.accountSelection(lastUsedAccount))
                  .eraseToAnyPublisher()

              case .authorized:
                return fetchConfiguration()
                  .map { () -> Destination in
                    .home
                  }
                  .replaceError(with: .featureConfigFetchError)
                  .eraseToAnyPublisher()

              case _:
                return Just(.accountSelection(nil))
                  .eraseToAnyPublisher()
              }
            }
            .switchToLatest()
            .sink { destination in
              destinationSubject.send(destination)
            }
            .store(in: cancellables)
        }
      })
      .filterMapOptional()
      .eraseToAnyPublisher()
    }

    return Self(
      navigationDestinationPublisher: destinationPublisher,
      retryFetchConfiguration: retryFetchConfiguration
    )
  }
}
