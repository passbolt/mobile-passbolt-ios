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
import CommonModels
import Crypto
import Features
import NetworkClient

import struct Foundation.URL

public struct AccountSettings {

  // for current account
  public var biometricsEnabledPublisher: () -> AnyPublisher<Bool, Never>
  // for current account
  public var setBiometricsEnabled: (Bool) -> AnyPublisher<Void, TheErrorLegacy>
  public var setAccountLabel: (String, Account) -> Result<Void, TheErrorLegacy>
  // for current account
  public var setAvatarImageURL: (String) -> AnyPublisher<Void, TheErrorLegacy>
  public var accountWithProfile: (Account) -> AccountWithProfile
  public var updatedAccountIDsPublisher: () -> AnyPublisher<Account.LocalID, Never>
  public var currentAccountProfilePublisher: () -> AnyPublisher<AccountWithProfile, Never>
}

extension AccountSettings: Feature {

  public static func load(
    in environment: AppEnvironment,
    using features: FeatureFactory,
    cancellables: Cancellables
  ) -> Self {
    let accountSession: AccountSession = features.instance()
    let accountsDataStore: AccountsDataStore = features.instance()
    let diagnostics: Diagnostics = features.instance()
    let permissions: OSPermissions = features.instance()
    let networkClient: NetworkClient = features.instance()

    let currentAccountProfileSubject: CurrentValueSubject<AccountWithProfile?, Never> = .init(nil)

    accountSession
      .statePublisher()
      .compactMap { (sessionState: AccountSessionState) -> AnyPublisher<AccountWithProfile?, Never>? in
        switch sessionState {
        case let .authorized(account), let .authorizedMFARequired(account, _), let .authorizationRequired(account):
          let initialProfilePublisher: AnyPublisher<AccountWithProfile?, Never>

          switch accountsDataStore.loadAccountProfile(account.localID) {
          case let .success(accountProfile):
            initialProfilePublisher = Just(.init(account: account, profile: accountProfile))
              .eraseToAnyPublisher()

          case let .failure(error):
            diagnostics.diagnosticLog("Failed to load account profile")
            diagnostics.debugLog(error.description)
            initialProfilePublisher = Just(.none)
              .eraseToAnyPublisher()
          }

          let profileUpdatesPublisher: AnyPublisher<AccountWithProfile?, Never> =
            accountsDataStore
            .updatedAccountIDsPublisher()
            .filter { $0 == account.localID }
            .compactMap { (accountID: Account.LocalID) -> AnyPublisher<AccountWithProfile?, Never> in
              switch accountsDataStore.loadAccountProfile(accountID) {
              case let .success(accountProfile):
                return Just(.init(account: account, profile: accountProfile))
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
    ) -> AnyPublisher<Void, TheErrorLegacy> {
      var updatedProfile: AccountProfile

      let profileLoadResult: Result<AccountProfile, TheErrorLegacy> =
        accountsDataStore
        .loadAccountProfile(accountID)

      switch profileLoadResult {
      case let .success(profile):
        updatedProfile = profile

      case let .failure(error):
        return Fail<Void, TheErrorLegacy>(error: error)
          .eraseToAnyPublisher()
      }

      update(&updatedProfile)

      let profileUpdateResult: Result<Void, TheErrorLegacy> =
        accountsDataStore
        .updateAccountProfile(updatedProfile)

      switch profileUpdateResult {
      case .success:
        return Just(Void())
          .setFailureType(to: TheErrorLegacy.self)
          .eraseToAnyPublisher()

      case let .failure(error):
        return Fail<Void, TheErrorLegacy>(error: error)
          .eraseToAnyPublisher()
      }
    }

    func fetchAccountProfile(
      _ account: Account
    ) -> AnyPublisher<Void, TheErrorLegacy> {
      networkClient
        .userProfileRequest
        .make(using: .init(userID: account.userID.rawValue))
        .mapErrorsToLegacy()
        .map { response -> AnyPublisher<Void, TheErrorLegacy> in
          updateProfile(for: account.localID) { profile in
            profile.firstName = response.body.profile.firstName
            profile.lastName = response.body.profile.lastName
            profile.avatarImageURL = response.body.profile.avatar.url.medium
          }
        }
        .switchToLatest()
        .eraseToAnyPublisher()
    }

    func setBiometrics(enabled: Bool) -> AnyPublisher<Void, TheErrorLegacy> {
      permissions
        .ensureBiometricsPermission()
        .mapErrorsToLegacy()
        .map { permissionGranted -> AnyPublisher<Void, TheErrorLegacy> in
          accountSession
            .storePassphraseWithBiometry(enabled)
            .asPublisher
        }
        .switchToLatest()
        .eraseToAnyPublisher()
    }

    func setAccountLabel(
      _ label: String,
      for account: Account
    ) -> Result<Void, TheErrorLegacy> {
      accountsDataStore
        .loadAccountProfile(account.localID)
        .flatMap { accountProfile in
          var updatedAccountProfile: AccountProfile = accountProfile
          updatedAccountProfile.label = label
          return accountsDataStore.updateAccountProfile(updatedAccountProfile)
        }
    }

    func setAvatarImageURL(
      _ url: String
    ) -> AnyPublisher<Void, TheErrorLegacy> {
      accountSession
        .statePublisher()
        .first()
        .map { (sessionState: AccountSessionState) -> AnyPublisher<Void, TheErrorLegacy> in
          let account: Account
          switch sessionState {
          case let .authorized(currentAccount),
            let .authorizedMFARequired(currentAccount, _):
            account = currentAccount

          case let .authorizationRequired(currentAccount):
            return Fail(
              error:
                SessionAuthorizationRequired
                .error(
                  "Session authorization required for setting avatar",
                  account: currentAccount
                )
                .asLegacy
            )
            .eraseToAnyPublisher()

          case .none:
            return Fail(
              error:
                SessionMissing
                .error("No session provided for setting avatar")
                .asLegacy
            )
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

    let accountProfilePublisher: AnyPublisher<AccountWithProfile, Never> =
      currentAccountProfileSubject
      .filterMapOptional()
      .removeDuplicates()
      .eraseToAnyPublisher()

    return Self(
      biometricsEnabledPublisher: { biometricsEnabledPublisher },
      setBiometricsEnabled: setBiometrics(enabled:),
      setAccountLabel: setAccountLabel(_:for:),
      setAvatarImageURL: setAvatarImageURL(_:),
      accountWithProfile: accountWithProfile(for:),
      updatedAccountIDsPublisher: accountsDataStore
        .updatedAccountIDsPublisher,
      currentAccountProfilePublisher: { accountProfilePublisher }
    )
  }
}

extension AccountSettings {

  public var featureUnload: () -> Bool { { true } }
}

extension AccountSettings {
  #if DEBUG
  public static var placeholder: Self {
    Self(
      biometricsEnabledPublisher: unimplemented("You have to provide mocks for used methods"),
      setBiometricsEnabled: unimplemented("You have to provide mocks for used methods"),
      setAccountLabel: unimplemented("You have to provide mocks for used methods"),
      setAvatarImageURL: unimplemented("You have to provide mocks for used methods"),
      accountWithProfile: unimplemented("You have to provide mocks for used methods"),
      updatedAccountIDsPublisher: unimplemented("You have to provide mocks for used methods"),
      currentAccountProfilePublisher: unimplemented("You have to provide mocks for used methods")
    )
  }
  #endif
}
