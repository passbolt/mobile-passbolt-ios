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

import Crypto
import Features

public struct AccountSettings {

  public var biometricsEnabledPublisher: () -> AnyPublisher<Bool, Never>
  public var setBiometricsEnabled: (Bool) -> AnyPublisher<Never, TheError>
}

extension AccountSettings: Feature {

  public static func load(
    in environment: Environment,
    using features: FeatureFactory,
    cancellables: Cancellables
  ) -> Self {
    let accountSession: AccountSession = features.instance()
    let accountsDataStore: AccountsDataStore = features.instance()
    let permissions: OSPermissions = features.instance()
    let passphraseCache: PassphraseCache = features.instance()

    let biometricsEnabledSubject: CurrentValueSubject<Bool, Never> = .init(false)

    accountSession
      .statePublisher()
      .map { (sessionState: AccountSession.State) -> Bool in
        switch sessionState {
        case let .authorized(account), let .authorizationRequired(account):
          let profileLoadResult: Result<AccountProfile, TheError> =
            accountsDataStore
            .loadAccountProfile(account.localID)
          switch profileLoadResult {
          case let .success(profile):
            return profile.biometricsEnabled

          case .failure:
            return false
          }

        case .none:
          return false
        }
      }
      .sink { enabled in
        biometricsEnabledSubject.send(enabled)
      }
      .store(in: cancellables)

    func biometricsEnabledPublisher() -> AnyPublisher<Bool, Never> {
      biometricsEnabledSubject.eraseToAnyPublisher()
    }

    func setBiometrics(enabled: Bool) -> AnyPublisher<Never, TheError> {
      permissions
        .ensureBiometricsPermission()
        .setFailureType(to: TheError.self)
        .map { permissionGranted -> AnyPublisher<Never, TheError> in
          guard permissionGranted
          else {
            return Fail<Never, TheError>(error: .permissionRequired().appending(context: "biometrics"))
              .eraseToAnyPublisher()
          }
          return
            accountSession
            .statePublisher()
            .first()
            .map { (sessionState: AccountSession.State) -> AnyPublisher<Never, TheError> in
              guard case let .authorized(account) = sessionState
              else {
                return Fail<Never, TheError>(error: .authorizationRequired())
                  .eraseToAnyPublisher()
              }
              if enabled {
                return
                  passphraseCache
                  .passphrasePublisher(account.localID)
                  .first()
                  .map { passphrase -> AnyPublisher<Never, TheError> in
                    if let passphrase: Passphrase = passphrase {
                      let passphraseStoreResult: Result<Void, TheError> =
                        accountsDataStore
                        .storeAccountPassphrase(account.localID, passphrase)
                      switch passphraseStoreResult {
                      case .success:
                        biometricsEnabledSubject.send(true)
                        return Empty<Never, TheError>()
                          .eraseToAnyPublisher()
                      case let .failure(error):
                        return Fail<Never, TheError>(error: error)
                          .eraseToAnyPublisher()
                      }
                    }
                    else {
                      return Fail<Never, TheError>(error: .authorizationRequired())
                        .eraseToAnyPublisher()
                    }
                  }
                  .switchToLatest()
                  .eraseToAnyPublisher()
              }
              else {
                let passphraseDeleteResult: Result<Void, TheError> =
                  accountsDataStore
                  .deleteAccountPassphrase(account.localID)
                switch passphraseDeleteResult {
                case .success:
                  biometricsEnabledSubject.send(false)
                  return Empty<Never, TheError>()
                    .eraseToAnyPublisher()
                case let .failure(error):
                  return Fail<Never, TheError>(error: error)
                    .eraseToAnyPublisher()
                }
              }
            }
            .switchToLatest()
            .eraseToAnyPublisher()
        }
        .switchToLatest()
        .eraseToAnyPublisher()
    }

    return Self(
      biometricsEnabledPublisher: biometricsEnabledPublisher,
      setBiometricsEnabled: setBiometrics(enabled:)
    )
  }
}

extension AccountSettings {
  #if DEBUG
  public static var placeholder: Self {
    Self(
      biometricsEnabledPublisher: Commons.placeholder("You have to provide mocks for used methods"),
      setBiometricsEnabled: Commons.placeholder("You have to provide mocks for used methods")
    )
  }
  #endif
}
