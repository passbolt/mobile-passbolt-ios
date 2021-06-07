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

public struct Accounts {
  
  public var verifyStorageDataIntegrity: () -> Result<Void, TheError>
  public var storedAccounts: () -> Array<AccountWithProfile>
  // Saves account data if authorization succeeds and creates session.
  public var transferAccount: (
    _ domain: String,
    _ userID: String,
    _ username: String,
    _ firstName: String,
    _ lastName: String,
    _ avatarImagePath: String,
    _ fingerprint: String,
    _ armoredKey: ArmoredPrivateKey,
    _ passphrase: Passphrase
  ) -> AnyPublisher<Void, TheError>
  public var removeAccount: (Account.LocalID) -> Result<Void, TheError>
}

extension Accounts: Feature {
  
  public typealias Environment = (
    preferences: Preferences,
    keychain: Keychain,
    uuidGenerator: UUIDGenerator
  )
  
  public static func environmentScope(
    _ rootEnvironment: RootEnvironment
  ) -> Environment {
    (
      preferences: rootEnvironment.preferences,
      keychain: rootEnvironment.keychain,
      uuidGenerator: rootEnvironment.uuidGenerator
    )
  }
  
  public static func load(
    in environment: Environment,
    using features: FeatureFactory,
    cancellables: Cancellables
  ) -> Self {
    let diagnostics: Diagnostics = features.instance()
    let session: AccountSession = features.instance()
    let dataStore: AccountsDataStore = features.instance()
    
    func verifyAccountsDataIntegrity() -> Result<Void, TheError> {
      dataStore.verifyDataIntegrity()
    }
    
    func storedAccounts() -> Array<AccountWithProfile> {
      dataStore
        .loadAccounts()
        .compactMap { account -> AccountWithProfile? in
          let profileLoadResult: Result<AccountProfile, TheError> = dataStore
            .loadAccountProfile(account.localID)
          switch profileLoadResult {
          // swiftlint:disable:next explicit_type_interface
          case let .success(profile):
            return AccountWithProfile(
              localID: account.localID,
              domain: account.domain,
              label: profile.label,
              username: profile.username,
              firstName: profile.firstName,
              lastName: profile.lastName,
              avatarImagePath: profile.avatarImagePath,
              biometricsEnabled: profile.biometricsEnabled
            )
          // swiftlint:disable:next explicit_type_interface
          case let .failure(error):
            diagnostics.debugLog(
              "Failed to load account profile: \(account.localID)"
              + " - status: \(error.osStatus.map(String.init(describing:)) ?? "N/A")"
            )
            return nil
          }
        }
    }
    
    func transferAccount(
      domain: String,
      userID: String,
      username: String,
      firstName: String,
      lastName: String,
      avatarImagePath: String,
      fingerprint: String,
      armoredKey: ArmoredPrivateKey,
      passphrase: Passphrase
    ) -> AnyPublisher<Void, TheError> {
      let accountID: Account.LocalID = .init(rawValue: environment.uuidGenerator().uuidString)
      let account: Account = .init(
        localID: accountID,
        domain: domain,
        userID: userID,
        fingerprint: fingerprint
      )
      let accountProfile: AccountProfile = .init(
        accountID: accountID,
        label: "\(firstName) \(lastName)", // initial label
        username: username,
        firstName: firstName,
        lastName: lastName,
        avatarImagePath: avatarImagePath,
        biometricsEnabled: false // it is always disabled initially
      )
      return session
        .authorize(account, .adHoc(passphrase, armoredKey))
        .map { _ -> AnyPublisher<Void, TheError> in
          switch dataStore.storeAccount(account, accountProfile, armoredKey) {
          case .success:
            return Just(Void())
              .setFailureType(to: TheError.self)
              .eraseToAnyPublisher()
          // swiftlint:disable:next explicit_type_interface
          case let .failure(error):
            diagnostics.debugLog(
              "Failed to save account: \(account.localID)"
              + " - status: \(error.osStatus.map(String.init(describing:)) ?? "N/A")"
            )
            session.close() // cleanup session
            return Fail<Void, TheError>(error: error)
              .eraseToAnyPublisher()
          }
        }
        .switchToLatest()
        .eraseToAnyPublisher()
    }
    
    func remove(
      accountWithID accountID: Account.LocalID
    ) -> Result<Void, TheError> {
      dataStore.deleteAccount(accountID)
      _ = session
        .statePublisher()
        .prefix(1)
        .map { sessionState -> Bool in
          switch sessionState {
          case
            // swiftlint:disable:next explicit_type_interface
            let .authorized(account, token: _)
          where account.localID == accountID,
            // swiftlint:disable:next explicit_type_interface
            let .authorizationRequired(account, token: _)
          where account.localID == accountID:
            return true
            
          case .authorized, .authorizationRequired, .none:
            return false
          }
        }
        .sink { signOutRequired in
          if signOutRequired {
            session.close()
          } else { /* */ }
        }
      
      return .success
    }
    
    return Self(
      verifyStorageDataIntegrity: verifyAccountsDataIntegrity,
      storedAccounts: storedAccounts,
      transferAccount: transferAccount(domain:userID:username:firstName:lastName:avatarImagePath:fingerprint:armoredKey:passphrase:),
      removeAccount: remove(accountWithID:)
    )
  }
  
  #if DEBUG
  // placeholder implementation for mocking and testing, unavailable in release
  public static var placeholder: Self {
    Self(
      verifyStorageDataIntegrity: Commons.placeholder("You have to provide mocks for used methods"),
      storedAccounts: Commons.placeholder("You have to provide mocks for used methods"),
      transferAccount: Commons.placeholder("You have to provide mocks for used methods"),
      removeAccount: Commons.placeholder("You have to provide mocks for used methods")
    )
  }
  #endif
}