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
import CommonModels
import NetworkClient
import UIComponents

internal struct SplashScreenController {

  internal var navigationDestinationPublisher: () -> AnyPublisher<Destination, Never>
  internal var retryFetchConfiguration: () -> AnyPublisher<Void, TheErrorLegacy>
  internal var shouldDisplayUpdateAlert: () async -> Bool
}

extension SplashScreenController {

  internal enum Destination: Equatable {

    case accountSetup
    case accountSelection(Account?, message: DisplayableString?)
    case diagnostics
    case home
    case mfaAuthorization(Array<MFAProvider>)
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
    let updateCheck: UpdateCheck = features.instance()

    let destinationSubject: CurrentValueSubject<Destination?, Never> = .init(nil)

    func fetchConfiguration() -> AnyPublisher<Void, TheErrorLegacy> {
      featureFlags
        .fetchIfNeeded()
        .eraseToAnyPublisher()
    }

    func retryFetchConfiguration() -> AnyPublisher<Void, TheErrorLegacy> {
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
          return
            accountSession
            .statePublisher()
            .first()
            .map { state -> AnyPublisher<Destination, Never> in
              switch state {
              case let .none(lastUsedAccount):
                return Just(
                  .accountSelection(
                    lastUsedAccount,
                    message: nil
                  )
                )
                .eraseToAnyPublisher()

              case .authorized:
                return fetchConfiguration()
                  .map { () -> Destination in
                    .home
                  }
                  .replaceError(with: .featureConfigFetchError)
                  .eraseToAnyPublisher()

              case let .authorizedMFARequired(_, mfaProviders):
                return fetchConfiguration()
                  .map { () -> Destination in
                    .mfaAuthorization(mfaProviders)
                  }
                  .replaceError(with: .featureConfigFetchError)
                  .eraseToAnyPublisher()

              case let .authorizationRequired(account):
                return Just(
                  .accountSelection(
                    account,
                    message: .localized("authorization.prompt.refresh.session.reason")
                  )
                )
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

    func shouldDisplayUpdateAlert() async -> Bool {
      guard await updateCheck.checkRequired()
      else { return false }

      do {
        return try await updateCheck.updateAvailable()
      }
      catch {
        return false
      }
    }

    return Self(
      navigationDestinationPublisher: destinationPublisher,
      retryFetchConfiguration: retryFetchConfiguration,
      shouldDisplayUpdateAlert: shouldDisplayUpdateAlert
    )
  }
}
