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

import Combine
import CommonDataModels
import Crypto
import Features
import NetworkClient

import struct Foundation.URL

public struct AccountSettings {

  public var biometricsEnabledPublisher: () -> AnyPublisher<Bool, Never>
  public var setBiometricsEnabled: (Bool) -> AnyPublisher<Void, TheError>
  public var setAvatarImageURL: (String) -> AnyPublisher<Void, TheError>
  public var accountWithProfile: (Account) -> AccountWithProfile
  public var updatedAccountIDsPublisher: () -> AnyPublisher<Account.LocalID, Never>
  public var currentAccountProfilePublisher: () -> AnyPublisher<AccountProfile, Never>
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
    let networkClient: NetworkClient = features.instance()

    let currentAccountProfileSubject: CurrentValueSubject<AccountProfile?, Never> = .init(nil)

    accountSession
      .statePublisher()
      .compactMap { (sessionState: AccountSession.State) -> AnyPublisher<AccountProfile?, Never>? in
        switch sessionState {
        case let .authorized(account), let .authorizedMFARequired(account, _), let .authorizationRequired(account):
          let initialProfilePublisher: AnyPublisher<AccountProfile?, Never>

          switch accountsDataStore.loadAccountProfile(account.localID) {
          case let .success(accountProfile):
            initialProfilePublisher = Just(accountProfile)
              .eraseToAnyPublisher()

          case let .failure(error):
            diagnostics.diagnosticLog("Failed to load account profile")
            diagnostics.debugLog(error.description)
            initialProfilePublisher = Just(.none)
              .eraseToAnyPublisher()
          }

          let profileUpdatesPublisher: AnyPublisher<AccountProfile?, Never> =
            accountsDataStore
            .updatedAccountIDsPublisher()
            .filter { $0 == account.localID }
            .compactMap { (accountID: Account.LocalID) -> AnyPublisher<AccountProfile?, Never> in
              switch accountsDataStore.loadAccountProfile(accountID) {
              case let .success(accountProfile):
                return Just(accountProfile)
                  .eraseToAnyPublisher()

              case let .failure(error):
                diagnostics.diagnosticLog("Failed to load account profile")
                diagnostics.debugLog(error.description)
                return Just(.none)
                  .eraseToAnyPublisher()
              }
            }
            .switchToLatest()
            .eraseToAnyPublisher()

          return Publishers.Merge(
            initialProfilePublisher,
            profileUpdatesPublisher
          )
          .eraseToAnyPublisher()
        case .none:
          return nil
        }
      }
      .switchToLatest()
      .removeDuplicates()
      .sink { accountProfile in
        currentAccountProfileSubject.send(accountProfile)
      }
      .store(in: cancellables)

    let biometricsEnabledPublisher: AnyPublisher<Bool, Never> =
      currentAccountProfileSubject
      .map { accountProfile in
        accountProfile?.biometricsEnabled ?? false
      }
      .removeDuplicates()
      .eraseToAnyPublisher()

    accountSession
      .statePublisher()
      .scan(
        (
          last: Optional<Account>.none,
          current: Optional<Account>.none
        )
      ) { changes, sessionState in
        switch sessionState {
        case let .authorized(account):
          return (last: changes.current, current: account)

        case let .authorizedMFARequired(account, _) where account == changes.current:
          return (last: changes.current, current: account)

        case let .authorizationRequired(account) where account == changes.current:
          return (last: changes.current, current: account)

        case .authorizationRequired, .authorizedMFARequired, .none:
          return (last: changes.current, current: nil)
        }
      }
      .filter { $0.last != $0.current }
      .compactMap { $0.current }
      .map { account in
        fetchAccountProfile(account)
          .replaceError(with: Void())
      }
      .switchToLatest()
      .sinkDrop()
      .store(in: cancellables)

    func updateProfile(
      for accountID: Account.LocalID,
      _ update: (inout AccountProfile) -> Void
    ) -> AnyPublisher<Void, TheError> {
      var updatedProfile: AccountProfile

      let profileLoadResult: Result<AccountProfile, TheError> =
        accountsDataStore
        .loadAccountProfile(accountID)

      switch profileLoadResult {
      case let .success(profile):
        updatedProfile = profile

      case let .failure(error):
        return Fail<Void, TheError>(error: error)
          .eraseToAnyPublisher()
      }

      update(&updatedProfile)

      let profileUpdateResult: Result<Void, TheError> =
        accountsDataStore
        .updateAccountProfile(updatedProfile)

      switch profileUpdateResult {
      case .success:
        return Just(Void())
          .setFailureType(to: TheError.self)
          .eraseToAnyPublisher()

      case let .failure(error):
        return Fail<Void, TheError>(error: error)
          .eraseToAnyPublisher()
      }
    }

    func fetchAccountProfile(
      _ account: Account
    ) -> AnyPublisher<Void, TheError> {
      networkClient
        .userProfileRequest
        .make(using: .init(userID: account.userID.rawValue))
        .map { response -> AnyPublisher<Void, TheError> in
          updateProfile(for: account.localID) { profile in
            profile.firstName = response.body.profile.firstName
            profile.lastName = response.body.profile.lastName
            profile.avatarImageURL = response.body.profile.avatar.url.medium
          }
        }
        .switchToLatest()
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
              let account: Account

              switch sessionState {
              case let .authorized(theAccount):
                account = theAccount
              case let .authorizedMFARequired(theAccount, _):
                account = theAccount
              case _:
                accountSession.requestAuthorizationPrompt(
                  .init(key: "authorization.prompt.biometrics.set.reason", bundle: .main)
                )

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
                      accountSession.requestAuthorizationPrompt(
                        .init(key: "authorization.prompt.biometrics.set.reason", bundle: .main)
                      )
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

    func setAvatarImageURL(
      _ url: String
    ) -> AnyPublisher<Void, TheError> {
      accountSession
        .statePublisher()
        .first()
        .map { (sessionState: AccountSession.State) -> AnyPublisher<Void, TheError> in
          let account: Account
          switch sessionState {
          case let .authorized(currentAccount),
            let .authorizedMFARequired(currentAccount, _):
            account = currentAccount

          case .authorizationRequired, .none:
            return Fail<Void, TheError>(error: .authorizationRequired())
              .eraseToAnyPublisher()
          }

          return updateProfile(for: account.localID) { profile in
            profile.avatarImageURL = url
          }
        }
        .switchToLatest()
        .eraseToAnyPublisher()
    }

    func accountWithProfile(
      for account: Account
    ) -> AccountWithProfile {
      switch accountsDataStore.loadAccountProfile(account.localID) {
      case let .success(accountProfile):
        return AccountWithProfile(
          localID: account.localID,
          userID: account.userID,
          domain: account.domain,
          label: accountProfile.label,
          username: accountProfile.username,
          firstName: accountProfile.firstName,
          lastName: accountProfile.lastName,
          avatarImageURL: accountProfile.avatarImageURL,
          fingerprint: account.fingerprint,
          biometricsEnabled: accountProfile.biometricsEnabled
        )

      case let .failure(error):
        diagnostics.diagnosticLog("Failed to load account profile")
        diagnostics.debugLog(error.description)
        fatalError("Internal inconsistency - invalid data storage state")
      }
    }

    let accountProfilePublisher: AnyPublisher<AccountProfile, Never> =
      currentAccountProfileSubject
      .filterMapOptional()
      .removeDuplicates()
      .eraseToAnyPublisher()

    return Self(
      biometricsEnabledPublisher: { biometricsEnabledPublisher },
      setBiometricsEnabled: setBiometrics(enabled:),
      setAvatarImageURL: setAvatarImageURL(_:),
      accountWithProfile: accountWithProfile(for:),
      updatedAccountIDsPublisher: accountsDataStore
        .updatedAccountIDsPublisher,
      currentAccountProfilePublisher: { accountProfilePublisher }
    )
  }
}

extension AccountSettings {
  #if DEBUG
  public static var placeholder: Self {
    Self(
      biometricsEnabledPublisher: Commons.placeholder("You have to provide mocks for used methods"),
      setBiometricsEnabled: Commons.placeholder("You have to provide mocks for used methods"),
      setAvatarImageURL: Commons.placeholder("You have to provide mocks for used methods"),
      accountWithProfile: Commons.placeholder("You have to provide mocks for used methods"),
      updatedAccountIDsPublisher: Commons.placeholder("You have to provide mocks for used methods"),
      currentAccountProfilePublisher: Commons.placeholder("You have to provide mocks for used methods")
    )
  }
  #endif
}
