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

import struct Foundation.Data
import struct Foundation.URL

public struct AccountSettings {

  // for current account
  public var biometricsEnabledPublisher: () -> AnyPublisher<Bool, Never>
  // for current account
  public var setBiometricsEnabled: @StorageAccessActor (Bool) -> AnyPublisher<Void, Error>
  public var setAccountLabel: @StorageAccessActor (String, Account) -> Result<Void, Error>
  // for current account
  public var setAvatarImageURL: @StorageAccessActor (String) -> AnyPublisher<Void, Error>
  public var accountWithProfile: @StorageAccessActor (Account) throws -> AccountWithProfile
  public var updatedAccountIDsPublisher: () -> AnyPublisher<Account.LocalID, Never>
  public var currentAccountProfilePublisher: () -> AnyPublisher<AccountWithProfile, Never>
  public var currentAccountAvatarPublisher: () -> AnyPublisher<Data?, Never>
}

extension AccountSettings: Feature {

  public static func load(
    in environment: AppEnvironment,
    using features: FeatureFactory,
    cancellables: Cancellables
  ) async throws -> Self {
    let accountSession: AccountSession = try await features.instance()
    let accountsDataStore: AccountsDataStore = try await features.instance()
    let diagnostics: Diagnostics = try await features.instance()
    let permissions: OSPermissions = try await features.instance()
    let networkClient: NetworkClient = try await features.instance()

    let currentAccountProfileSubject: CurrentValueSubject<AccountWithProfile?, Never> = .init(nil)

    accountSession
      .statePublisher()
      .asyncMap { (sessionState: AccountSessionState) -> AnyPublisher<AccountWithProfile?, Never>? in
        switch sessionState {
        case let .authorized(account), let .authorizedMFARequired(account, _), let .authorizationRequired(account):
          let initialProfilePublisher: AnyPublisher<AccountWithProfile?, Never>

          switch await accountsDataStore.loadAccountProfile(account.localID) {
          case let .success(accountProfile):
            initialProfilePublisher = Just(.init(account: account, profile: accountProfile))
              .eraseToAnyPublisher()

          case let .failure(error):
            diagnostics.diagnosticLog("Failed to load account profile")
            diagnostics.log(error)
            initialProfilePublisher = Just(.none)
              .eraseToAnyPublisher()
          }

          let profileUpdatesPublisher: AnyPublisher<AccountWithProfile?, Never> =
            accountsDataStore
            .updatedAccountIDsPublisher()
            .filter { $0 == account.localID }
            .asyncMap { (accountID: Account.LocalID) -> AnyPublisher<AccountWithProfile?, Never> in
              switch await accountsDataStore.loadAccountProfile(accountID) {
              case let .success(accountProfile):
                return Just(.init(account: account, profile: accountProfile))
                  .eraseToAnyPublisher()

              case let .failure(error):
                diagnostics.diagnosticLog("Failed to load account profile")
                diagnostics.log(error)
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
      .filterMapOptional()
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
      .eraseErrorType()
      .asyncMap { account in
        await fetchAccountProfile(account)
          .replaceError(with: Void())
      }
      .sinkDrop()
      .store(in: cancellables)

    @StorageAccessActor func updateProfile(
      for accountID: Account.LocalID,
      _ update: (inout AccountProfile) -> Void
    ) -> AnyPublisher<Void, Error> {
      var updatedProfile: AccountProfile

      let profileLoadResult: Result<AccountProfile, Error> =
        accountsDataStore
        .loadAccountProfile(accountID)

      switch profileLoadResult {
      case let .success(profile):
        updatedProfile = profile

      case let .failure(error):
        return Fail<Void, Error>(error: error)
          .eraseToAnyPublisher()
      }

      update(&updatedProfile)

      let profileUpdateResult: Result<Void, Error> =
        accountsDataStore
        .updateAccountProfile(updatedProfile)

      switch profileUpdateResult {
      case .success:
        return Just(Void())
          .eraseErrorType()
          .eraseToAnyPublisher()

      case let .failure(error):
        return Fail<Void, Error>(error: error)
          .eraseToAnyPublisher()
      }
    }

    @StorageAccessActor func fetchAccountProfile(
      _ account: Account
    ) -> AnyPublisher<Void, Error> {
      networkClient
        .userProfileRequest
        .make(using: .init(userID: account.userID.rawValue))
        .eraseErrorType()
        .map { response -> AnyPublisher<Void, Error> in
          updateProfile(for: account.localID) { profile in
            profile.firstName = response.body.profile.firstName
            profile.lastName = response.body.profile.lastName
            profile.avatarImageURL = response.body.profile.avatar.url.medium
          }
        }
        .switchToLatest()
        .eraseToAnyPublisher()
    }

    @StorageAccessActor func setBiometrics(enabled: Bool) -> AnyPublisher<Void, Error> {
      permissions
        .ensureBiometricsPermission()
        .first()
        .eraseErrorType()
        .asyncMap { permissionGranted in
          try await accountSession
            .storePassphraseWithBiometry(enabled)
        }
        .eraseToAnyPublisher()
    }

    @StorageAccessActor func setAccountLabel(
      _ label: String,
      for account: Account
    ) -> Result<Void, Error> {
      accountsDataStore
        .loadAccountProfile(account.localID)
        .flatMap { accountProfile in
          var updatedAccountProfile: AccountProfile = accountProfile
          updatedAccountProfile.label = label
          return accountsDataStore.updateAccountProfile(updatedAccountProfile)
        }
    }

    @StorageAccessActor func setAvatarImageURL(
      _ url: String
    ) -> AnyPublisher<Void, Error> {
      accountSession
        .statePublisher()
        .first()
        .map { (sessionState: AccountSessionState) -> AnyPublisher<Void, Error> in
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
            )
            .eraseToAnyPublisher()

          case .none:
            return Fail(
              error:
                SessionMissing
                .error("No session provided for setting avatar")
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

    @StorageAccessActor func accountWithProfile(
      for account: Account
    ) throws -> AccountWithProfile {
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
        diagnostics.log(error)
        throw error
      }
    }

    let accountProfilePublisher: AnyPublisher<AccountWithProfile, Never> =
      currentAccountProfileSubject
      .filterMapOptional()
      .removeDuplicates()
      .eraseToAnyPublisher()

    nonisolated func currentAccountAvatarPublisher() -> AnyPublisher<Data?, Never> {
      accountProfilePublisher
        .first()
        .map(\.avatarImageURL)
        .asyncMap { avatarImageURL -> Data? in
          try? await networkClient
            .mediaDownload
            .makeAsync(
              using: .init(urlString: avatarImageURL)
            )
        }
        .eraseToAnyPublisher()
    }

    return Self(
      biometricsEnabledPublisher: { biometricsEnabledPublisher },
      setBiometricsEnabled: setBiometrics(enabled:),
      setAccountLabel: setAccountLabel(_:for:),
      setAvatarImageURL: setAvatarImageURL(_:),
      accountWithProfile: accountWithProfile(for:),
      updatedAccountIDsPublisher: accountsDataStore
        .updatedAccountIDsPublisher,
      currentAccountProfilePublisher: { accountProfilePublisher },
      currentAccountAvatarPublisher: currentAccountAvatarPublisher
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
      currentAccountProfilePublisher: unimplemented("You have to provide mocks for used methods"),
      currentAccountAvatarPublisher: unimplemented("You have to provide mocks for used methods")
    )
  }
  #endif
}
