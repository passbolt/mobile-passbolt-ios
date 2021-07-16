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
  public var setBiometricsEnabled: (Bool) -> AnyPublisher<Void, TheError>
  public var accountProfilePublisher: () -> AnyPublisher<AccountProfile, Never>
}

extension AccountSettings: Feature {

  public static func load(
    in environment: Environment,
    using features: FeatureFactory,
    cancellables: Cancellables
  ) -> Self {
    let accountSession: AccountSession = features.instance()
    let accountsDataStore: AccountsDataStore = features.instance()
    let diagnostics: Diagnostics = features.instance()
    let permissions: OSPermissions = features.instance()
    let passphraseCache: PassphraseCache = features.instance()

    func biometricsEnabledPublisher() -> AnyPublisher<Bool, Never> {
      _accountProfilePublisher()
        .map { accountProfile in
          accountProfile.biometricsEnabled
        }
        .replaceError(with: false)
        .eraseToAnyPublisher()
    }

    func setBiometrics(enabled: Bool) -> AnyPublisher<Void, TheError> {
      permissions
        .ensureBiometricsPermission()
        .setFailureType(to: TheError.self)
        .map { permissionGranted -> AnyPublisher<Void, TheError> in
          guard permissionGranted
          else {
            return Fail<Void, TheError>(error: .permissionRequired().appending(context: "biometrics"))
              .eraseToAnyPublisher()
          }
          return
            accountSession
            .statePublisher()
            .first()
            .map { (sessionState: AccountSession.State) -> AnyPublisher<Void, TheError> in
              guard case let .authorized(account) = sessionState
              else {
                accountSession.requestAuthorization()
                return Fail<Void, TheError>(error: .authorizationRequired())
                  .eraseToAnyPublisher()
              }
              if enabled {
                return
                  passphraseCache
                  .passphrasePublisher(account.localID)
                  .first()
                  .map { passphrase -> AnyPublisher<Void, TheError> in
                    if let passphrase: Passphrase = passphrase {
                      let passphraseStoreResult: Result<Void, TheError> =
                        accountsDataStore
                        .storeAccountPassphrase(account.localID, passphrase)
                      switch passphraseStoreResult {
                      case .success:
                        return Just(Void())
                          .setFailureType(to: TheError.self)
                          .eraseToAnyPublisher()
                      case let .failure(error):
                        return Fail<Void, TheError>(error: error)
                          .eraseToAnyPublisher()
                      }
                    }
                    else {
                      #warning("TODO: determine if waiting for authorization could be implemented here")
                      accountSession.requestAuthorization()
                      return Fail<Void, TheError>(error: .authorizationRequired())
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
                  return Just(Void()).setFailureType(to: TheError.self)
                    .eraseToAnyPublisher()
                case let .failure(error):
                  return Fail<Void, TheError>(error: error)
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

    #warning("TODO - find a better solution")
    func _accountProfilePublisher() -> AnyPublisher<AccountProfile, TheError> {
      func accountProfile(accountID: Account.LocalID) -> Result<AccountProfile, TheError> {
        accountsDataStore
          .loadAccountProfile(accountID)
          .mapError { error in
            diagnostics.diagnosticLog("Failed to publish updated account profile")
            diagnostics.debugLog(error.description)
            return error
          }
      }

      return accountSession.statePublisher()
        .compactMap { (sessionState: AccountSession.State) -> AnyPublisher<AccountProfile, TheError>? in
          switch sessionState {
          case let .authorized(account), let .authorizationRequired(account):
            let initialProfilePublisher: AnyPublisher<AccountProfile, TheError>
            switch accountProfile(accountID: account.localID) {
            case let .success(accountProfile):
              initialProfilePublisher = Just(accountProfile)
                .setFailureType(to: TheError.self)
                .eraseToAnyPublisher()
            case let .failure(error):
              initialProfilePublisher = Fail(error: error).eraseToAnyPublisher()
            }

            #warning("TODO - Determine if .multicast could be used here to limit the number of subscriptions")
            return Publishers.Merge(
              accountsDataStore.updatedAccountIDsPublisher()
                .filter { $0 == account.localID }
                .compactMap { (accountID: Account.LocalID) -> AnyPublisher<AccountProfile, TheError> in
                  switch accountProfile(accountID: accountID) {
                  case let .success(accountProfile):
                    return Just(accountProfile)
                      .setFailureType(to: TheError.self)
                      .eraseToAnyPublisher()
                  case let .failure(error):
                    return Fail(error: error).eraseToAnyPublisher()
                  }
                }
                .switchToLatest(),
              initialProfilePublisher
            )
            .eraseToAnyPublisher()
          case .none:
            return nil
          }
        }
        .switchToLatest()
        .eraseToAnyPublisher()
    }

    func accountProfilePublisher() -> AnyPublisher<AccountProfile, Never> {
      _accountProfilePublisher()
        .map { accountProfile -> AccountProfile? in
          accountProfile
        }
        .replaceError(with: nil)
        .compactMap { accountProfile -> AnyPublisher<AccountProfile, Never> in
          switch accountProfile {
          case let .some(profile):
            return Just(profile).eraseToAnyPublisher()
          case .none:
            return Empty().eraseToAnyPublisher()
          }
        }
        .switchToLatest()
        .eraseToAnyPublisher()
    }

    return Self(
      biometricsEnabledPublisher: biometricsEnabledPublisher,
      setBiometricsEnabled: setBiometrics(enabled:),
      accountProfilePublisher: accountProfilePublisher
    )
  }
}

extension AccountSettings {
  #if DEBUG
  public static var placeholder: Self {
    Self(
      biometricsEnabledPublisher: Commons.placeholder("You have to provide mocks for used methods"),
      setBiometricsEnabled: Commons.placeholder("You have to provide mocks for used methods"),
      accountProfilePublisher: Commons.placeholder("You have to provide mocks for used methods")
    )
  }
  #endif
}
