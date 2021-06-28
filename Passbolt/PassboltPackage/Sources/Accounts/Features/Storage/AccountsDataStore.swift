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

#warning("TODO: [PAS-82] - database")
// swiftlint:disable file_length
internal struct AccountsDataStore {
  
  internal var verifyDataIntegrity: () -> Result<Void, TheError>
  internal var loadAccounts: () -> Array<Account>
  internal var loadLastUsedAccount: () -> Account?
  internal var storeLastUsedAccount: (Account.LocalID) -> Void
  internal var storeAccount: (Account, AccountProfile, ArmoredPrivateKey) -> Result<Void, TheError>
  internal var loadAccountPrivateKey: (Account.LocalID) -> Result<ArmoredPrivateKey, TheError>
  internal var storeAccountPassphrase: (Account.LocalID, Passphrase) -> Result<Void, TheError>
  internal var loadAccountPassphrase: (Account.LocalID) -> Result<Passphrase, TheError>
  internal var deleteAccountPassphrase: (Account.LocalID) -> Result<Void, TheError>
  internal var loadAccountProfile: (Account.LocalID) -> Result<AccountProfile, TheError>
  internal var updateAccountProfile: (AccountProfile) -> Result<Void, TheError>
  internal var deleteAccount: (Account.LocalID) -> Void
  internal var accountDatabaseConnection: (Account.LocalID) -> Result<DatabaseConnection, TheError>
  internal var storeRefreshToken: (String, Account.LocalID) -> Result<Void, TheError>
  internal var loadRefreshToken: (Account.LocalID) -> Result<String?, TheError>
  internal var deleteRefreshToken: (Account.LocalID) -> Result<Void, TheError>
}

extension AccountsDataStore: Feature {
  
  // swiftlint:disable:next function_body_length
  internal static func load(
    in environment: Environment,
    using features: FeatureFactory,
    cancellables: Cancellables
  ) -> Self {
    let preferences: Preferences = environment.preferences
    let keychain: Keychain = environment.keychain
    let uuidGenerator: UUIDGenerator = environment.uuidGenerator
    
    let diagnostics: Diagnostics = features.instance()
    
    // swiftlint:disable:next cyclomatic_complexity function_body_length cyclomatic_complexity
    func checkDataIntegrity() -> Result<Void, TheError> {
      diagnostics.debugLog("Verifying data integrity...")
      defer { diagnostics.debugLog("...data integrity verification finished") }
      
      // storedAccountsList - user defaults control list
      let storedAccountsList: Array<Account.LocalID> = preferences
        .load(Array<Account.LocalID>.self, for: .accountsList)
      diagnostics.debugLog("Stored accounts list: \(storedAccountsList)")
      
      // storedAccounts - keychain accounts
      let storedAccounts: Array<Account.LocalID>
      switch keychain.loadAll(Account.self, matching: .accountsQuery) {
      // swiftlint:disable:next explicit_type_interface
      case let .success(accounts):
        storedAccounts = accounts.map(\.localID)
      // swiftlint:disable:next explicit_type_interface
      case let .failure(error):
        diagnostics.debugLog(
          "Failed to load keychain accounts data, recovering with empty list"
          + " - status: \(error.osStatus.map(String.init(describing:)) ?? "N/A")"
        )
        storedAccounts = .init()
      }
      diagnostics.debugLog("Stored accounts: \(storedAccounts)")
      
      // storedAccountProfiles - keychain accounts metadata
      let storedAccountsProfiles: Array<Account.LocalID>
      switch keychain.loadAll(AccountProfile.self, matching: .accountsProfilesQuery) {
      // swiftlint:disable:next explicit_type_interface
      case let .success(accounts):
        storedAccountsProfiles = accounts.map(\.accountID)
      // swiftlint:disable:next explicit_type_interface
      case let .failure(error):
        diagnostics.debugLog(
          "Failed to load keychain account profiles data, recovering with empty list"
            + " - status: \(error.osStatus.map(String.init(describing:)) ?? "N/A")"
        )
        storedAccountsProfiles = .init()
      }
      diagnostics.debugLog("Stored account profiles: \(storedAccountsProfiles)")
      
      // storedAccountKeys - keychain accounts private keys
      let storedAccountKeys: Array<Account.LocalID>
      let armoredKeysQuery: KeychainQuery = .init(
        key: "accountArmoredKey",
        tag: nil,
        requiresBiometrics: false
      )
      switch keychain.loadMeta(matching: armoredKeysQuery) {
      // swiftlint:disable:next explicit_type_interface
      case let .success(keysMeta):
        storedAccountKeys = keysMeta
          .compactMap(\.tag)
          .map { tag in
            Account.LocalID(rawValue: tag.rawValue)
          }
      // swiftlint:disable:next explicit_type_interface
      case let .failure(error):
        diagnostics.debugLog(
          "Failed to load keychain armored keys meta, recovering with empty list"
          + " - status: \(error.osStatus.map(String.init(describing:)) ?? "N/A")"
        )
        storedAccountKeys = .init()
      }
      diagnostics.debugLog("Stored account keys: \(storedAccountKeys)")
      
      let updatedAccountsList: Array<Account.LocalID> = storedAccountsList
        .filter {
          storedAccounts.contains($0)
          && storedAccountsProfiles.contains($0)
          && storedAccountKeys.contains($0)
        }
      environment
        .preferences
        .save(updatedAccountsList, for: .accountsList)
      diagnostics.debugLog("Updated accounts list: \(updatedAccountsList)")
      
      let accountsToRemove: Array<Account.LocalID> = storedAccounts
        .filter { !updatedAccountsList.contains($0) }
      
      for accountID in accountsToRemove {
        switch keychain.delete(matching: .accountQuery(for: accountID)) {
        case .success:
          continue
        // swiftlint:disable:next explicit_type_interface
        case let .failure(error):
          diagnostics.debugLog(
            "Failed to delete account for accountID: \(updatedAccountsList)"
            + " - status: \(error.osStatus.map(String.init(describing:)) ?? "N/A")"
          )
          return .failure(error)
        }
      }
      diagnostics.debugLog("Deleted accounts: \(accountsToRemove)")
      
      let accountProfilesToRemove: Array<Account.LocalID> = storedAccountsProfiles
        .filter { !updatedAccountsList.contains($0) }
      
      for accountID in accountProfilesToRemove {
        switch keychain.delete(matching: .accountProfileQuery(for: accountID)) {
        case .success:
          continue
        // swiftlint:disable:next explicit_type_interface
        case let .failure(error):
          diagnostics.debugLog(
            "Failed to delete account profile for accountID: \(accountID)"
              + " - status: \(error.osStatus.map(String.init(describing:)) ?? "N/A")"
          )
          return .failure(error)
        }
      }
      diagnostics.debugLog("Deleted account profiles: \(accountProfilesToRemove)")
      
      let keysToRemove: Array<Account.LocalID> = storedAccountKeys
        .filter { !updatedAccountsList.contains($0) }
      
      for accountID in keysToRemove {
        switch keychain.delete(matching: .accountArmoredKeyQuery(for: accountID)) {
        case .success:
          continue
        // swiftlint:disable:next explicit_type_interface
        case let .failure(error):
          diagnostics.debugLog(
            "Failed to delete account key for accountID: \(updatedAccountsList)"
            + " - status: \(error.osStatus.map(String.init(describing:)) ?? "N/A")"
          )
          return .failure(error)
        }
      }
      diagnostics.debugLog("Deleted account keys: \(keysToRemove)")
      
      if updatedAccountsList.isEmpty {
        diagnostics.debugLog("Deleting stored passphrases")
        switch keychain.delete(matching: .accountPassphraseDeletionQuery()) {
        case .success:
          break
        // swiftlint:disable:next explicit_type_interface
        case let .failure(error):
          diagnostics.debugLog(
            "Failed to delete passphrases: \(updatedAccountsList)"
            + " - status: \(error.osStatus.map(String.init(describing:)) ?? "N/A")"
          )
          return .failure(error)
        }
      } else { /* We can't delete passphrases selectively due to biometrics */ }
      
      #warning("TODO: [PAS-82] Verify database files and remove detached")

      let storedTokens: Array<Account.LocalID>
      
      switch keychain.loadMeta(matching: .refreshTokensQuery()) {
      // swiftlint:disable:next explicit_type_interface
      case let .success(metadata):
        storedTokens = metadata
          .compactMap(\.tag)
          .map { Account.LocalID(rawValue: $0.rawValue) }
        
      // swiftlint:disable:next explicit_type_interface
      case let .failure(error):
        diagnostics.debugLog(
          "Failed to load refresh tokens meta"
          + " - status: \(error.osStatus.map(String.init(describing:)) ?? "N/A")"
        )
        return .failure(error)
      }
      
      let tokensToRemove: Array<Account.LocalID> = storedTokens
        .filter { !updatedAccountsList.contains($0) }
      
      for accountID in tokensToRemove {
        switch keychain.delete(matching: .refreshTokenQuery(for: accountID)) {
        case .success:
          continue
        // swiftlint:disable:next explicit_type_interface
        case let .failure(error):
          diagnostics.debugLog(
            "Failed to delete token for accountID: \(accountID)"
            + " - status: \(error.osStatus.map(String.init(describing:)) ?? "N/A")"
          )
          return .failure(error)
        }
      }
      
      diagnostics.debugLog("Deleted account tokens: \(tokensToRemove)")
      
      return .success
    }
    
    func loadAccounts() -> Array<Account> {
      let keychainLoadResult: Result<Array<Account>, TheError> = environment
        .keychain
        .loadAll(
          Account.self,
          matching: .accountsQuery
        )
      switch keychainLoadResult {
      // swiftlint:disable:next explicit_type_interface
      case let .success(accounts):
        return accounts
      // swiftlint:disable:next explicit_type_interface
      case let .failure(error):
        diagnostics.debugLog(
          "Failed to load accounts"
          + " - status: \(error.osStatus.map(String.init(describing:)) ?? "N/A")"
        )
        return []
      }
    }
    
    func loadLastUsedAccount() -> Account? {
      environment
        .preferences
        .load(
          Account.LocalID.self,
          for: .lastUsedAccount
        )
        .flatMap { accountID in
          let keychainResult: Result<Account?, TheError> = environment
            .keychain
            .loadFirst(
              Account.self,
              matching: .accountQuery(for: accountID)
            )
          switch keychainResult {
          // swiftlint:disable:next explicit_type_interface
          case let .success(account):
            return account
          // swiftlint:disable:next explicit_type_interface
          case let .failure(error):
            diagnostics.debugLog(
              "Failed to load last used account: \(accountID)"
              + " - status: \(error.osStatus.map(String.init(describing:)) ?? "N/A")"
            )
            return nil
          }
        }
    }
    
    func storeLastUsedAccount(_ accountID: Account.LocalID) -> Void {
      preferences.save(accountID, for: .lastUsedAccount)
    }
    
    func store(
      account: Account,
      profile: AccountProfile,
      armoredKey: ArmoredPrivateKey
    ) -> Result<Void, TheError> {
      // data integrity check performs cleanup in case of partial success
      defer { checkDataIntegrity().forceSuccess("Data integrity protection") }
      var accountIdentifiers: Array<Account.LocalID> = environment
        .preferences
        .load(Array<Account.LocalID>.self, for: .accountsList)
      accountIdentifiers.append(account.localID)
      preferences.save(accountIdentifiers, for: .accountsList)
      
      return environment
        .keychain
        .save(profile, for: .accountProfileQuery(for: account.localID))
        .flatMap { _ in
          environment
            .keychain
            .save(account, for: .accountQuery(for: account.localID))
            .flatMap { _ in
              environment
                .keychain
                .save(
                  armoredKey,
                  for: .accountArmoredKeyQuery(for: account.localID)
                )
            }
        }
    }
    
    func loadAccountPrivateKey(
      for accountID: Account.LocalID
    ) -> Result<ArmoredPrivateKey, TheError> {
      environment
        .keychain
        .loadFirst(
          ArmoredPrivateKey.self,
          matching: .accountArmoredKeyQuery(for: accountID)
        )
        .flatMap { key in
          if let key: ArmoredPrivateKey = key {
            return .success(key)
          } else {
            return .failure(.invalidAccount())
          }
        }
    }
    
    func storePassphrase(
      for accountID: Account.LocalID,
      passphrase: Passphrase
    ) -> Result<Void, TheError> {
      environment
        .keychain
        .loadFirst(
          AccountProfile.self,
          matching: .accountProfileQuery(for: accountID)
        )
        .flatMap { accountProfile in
          if var updatedAccountProfile: AccountProfile = accountProfile {
            updatedAccountProfile.biometricsEnabled = true
            return environment
              .keychain
              .save(
                updatedAccountProfile,
                for: .accountProfileQuery(for: accountID)
              )
              .flatMap { _ in
                environment
                  .keychain
                  .save(
                    passphrase,
                    for: .accountPassphraseQuery(for: accountID)
                  )
              }
          } else {
            return .failure(.invalidAccount())
          }
        }
    }
    
    func loadPassphrase(
      for accountID: Account.LocalID
    ) -> Result<Passphrase, TheError> {
      // in case of failure we should change flag biometricsEnabled to false and propagate change
      environment
        .keychain
        .loadFirst(Passphrase.self, matching: .accountPassphraseQuery(for: accountID))
        .flatMap { passphrase in
          if let passphrase: Passphrase = passphrase {
            return .success(passphrase)
          } else {
            return .failure(.invalidPassphrase())
          }
        }
        .mapError { error in
          diagnostics.debugLog(
            "Failed to load passphrase"
            + " - status: \(error.osStatus.map(String.init(describing:)) ?? "N/A")"
          )
          return .biometricsNotAvailable(underlyingError: error)
        }
    }
    
    func deletePassphrase(
      for accountID: Account.LocalID
    ) -> Result<Void, TheError> {
      environment
        .keychain
        .loadFirst(
          AccountProfile.self,
          matching: .accountProfileQuery(for: accountID)
        )
        .flatMap { accountProfile in
          if var updatedAccountProfile: AccountProfile = accountProfile {
            updatedAccountProfile.biometricsEnabled = false
            return environment
              .keychain
              .save(
                updatedAccountProfile,
                for: .accountProfileQuery(for: accountID)
              )
              .flatMap { _ in
                environment
                  .keychain
                  .delete(matching: .accountPassphraseQuery(for: accountID))
              }
          } else {
            return .failure(.invalidAccount())
          }
        }
    }
    
    func loadAccountProfile(
      for accountID: Account.LocalID
    ) -> Result<AccountProfile, TheError> {
      environment
        .keychain
        .loadFirst(AccountProfile.self, matching: .accountProfileQuery(for: accountID))
        .flatMap { profile in
          if let profile: AccountProfile = profile {
            return .success(profile)
          } else {
            return .failure(.invalidAccount())
          }
        }
    }
    
    func update(
      accountProfile: AccountProfile
    ) -> Result<Void, TheError> {
      let accountsList: Array<Account.LocalID> = environment
        .preferences
        .load(Array<Account.LocalID>.self, for: .accountsList)
      guard accountsList.contains(accountProfile.accountID)
      else { return .failure(.invalidAccount()) }
      return environment
        .keychain
        .save(accountProfile, for: .accountProfileQuery(for: accountProfile.accountID))
    }
    
    func deleteAccount(withID accountID: Account.LocalID) {
      // There is a risk of calling this method with valid session for deleted account,
      // we should assert on that or make it impossible")
      
      // data integrity check performs cleanup in case of partial success
      defer { checkDataIntegrity().forceSuccess("Data integrity protection") }
      #warning("TODO: Consider propagating the error outside of this function")
      _ = environment
        .keychain
        .delete(matching: .accountPassphraseQuery(for: accountID))
      _ = environment
        .keychain
        .delete(matching: .accountArmoredKeyQuery(for: accountID))
      _ = environment
        .keychain
        .delete(matching: .refreshTokenQuery(for: accountID))
      _ = environment
        .keychain
        .delete(matching: .accountQuery(for: accountID))
      _ = environment
        .keychain
        .delete(matching: .accountProfileQuery(for: accountID))
      var accountIdentifiers: Array<Account.LocalID> = environment
        .preferences
        .load(Array<Account.LocalID>.self, for: .accountsList)
      accountIdentifiers.removeAll(where: { $0 == accountID })
      preferences.save(accountIdentifiers, for: .accountsList)
      
      #warning("TODO: [PAS-82] remove database files")
    }
    
    func prepareDatabaseConnection(
      forAccountWithID accountID: Account.LocalID
    ) -> Result<DatabaseConnection, TheError> {
      #warning("TODO: [PAS-82] prepare connection and files if needed")
      return .success(DatabaseConnection.placeholder)
    }
    
    func store(
      refreshToken: String,
      accountID: Account.LocalID
    ) -> Result<Void, TheError> {
      keychain.save(refreshToken, for: .refreshTokenQuery(for: accountID))
    }
    
    func loadRefreshToken(
      for accountID: Account.LocalID
    ) -> Result<String?, TheError> {
      keychain.loadFirst(matching: .refreshTokenQuery(for: accountID))
    }
    
    func deleteRefreshToken(
      for accountID: Account.LocalID
    ) -> Result<Void, TheError> {
      keychain.delete(matching: .refreshTokenQuery(for: accountID))
    }
    
    return Self(
      verifyDataIntegrity: checkDataIntegrity,
      loadAccounts: loadAccounts,
      loadLastUsedAccount: loadLastUsedAccount,
      storeLastUsedAccount: storeLastUsedAccount,
      storeAccount: store(account:profile:armoredKey:),
      loadAccountPrivateKey: loadAccountPrivateKey(for:),
      storeAccountPassphrase: storePassphrase(for:passphrase:),
      loadAccountPassphrase: loadPassphrase(for:),
      deleteAccountPassphrase: deletePassphrase(for:),
      loadAccountProfile: loadAccountProfile(for:),
      updateAccountProfile: update(accountProfile:),
      deleteAccount: deleteAccount(withID:),
      accountDatabaseConnection: prepareDatabaseConnection(forAccountWithID:),
      storeRefreshToken: store(refreshToken:accountID:),
      loadRefreshToken: loadRefreshToken(for:),
      deleteRefreshToken: deleteRefreshToken(for:)
    )
  }
  
  #if DEBUG
  internal static var placeholder: Self {
    Self(
      verifyDataIntegrity: Commons.placeholder("You have to provide mocks for used methods"),
      loadAccounts: Commons.placeholder("You have to provide mocks for used methods"),
      loadLastUsedAccount: Commons.placeholder("You have to provide mocks for used methods"),
      storeLastUsedAccount: Commons.placeholder("You have to provide mocks for used methods"),
      storeAccount: Commons.placeholder("You have to provide mocks for used methods"),
      loadAccountPrivateKey: Commons.placeholder("You have to provide mocks for used methods"),
      storeAccountPassphrase: Commons.placeholder("You have to provide mocks for used methods"),
      loadAccountPassphrase: Commons.placeholder("You have to provide mocks for used methods"),
      deleteAccountPassphrase: Commons.placeholder("You have to provide mocks for used methods"),
      loadAccountProfile: Commons.placeholder("You have to provide mocks for used methods"),
      updateAccountProfile: Commons.placeholder("You have to provide mocks for used methods"),
      deleteAccount: Commons.placeholder("You have to provide mocks for used methods"),
      accountDatabaseConnection: Commons.placeholder("You have to provide mocks for used methods"),
      storeRefreshToken: Commons.placeholder("You have to provide mocks for used methods"),
      loadRefreshToken: Commons.placeholder("You have to provide mocks for used methods"),
      deleteRefreshToken: Commons.placeholder("You have to provide mocks for used methods")
    )
  }
  #endif
}

extension Preferences.Key {
  
  fileprivate static var accountsList: Self { "accountsList" }
  fileprivate static var lastUsedAccount: Self { "lastUsedAccount" }
}

extension KeychainQuery {
  
  fileprivate static var accountsQuery: Self {
    Self(
      key: "account",
      tag: nil,
      requiresBiometrics: false
    )
  }
  
  fileprivate static func accountQuery(
    for identifier: Account.LocalID
  ) -> Self {
    assert(
      !identifier.rawValue.isEmpty,
      "Cannot use empty account identifiers for account keychain operations"
    )
    return Self(
      key: "account",
      tag: .init(rawValue: identifier.rawValue),
      requiresBiometrics: false
    )
  }
  
  fileprivate static var accountsProfilesQuery: Self {
    Self(
      key: "accountProfile",
      tag: nil,
      requiresBiometrics: false
    )
  }
  
  fileprivate static func accountProfileQuery(
    for identifier: Account.LocalID
  ) -> Self {
    assert(
      !identifier.rawValue.isEmpty,
      "Cannot use empty account identifiers for account keychain operations"
    )
    return Self(
      key: "accountProfile",
      tag: .init(rawValue: identifier.rawValue),
      requiresBiometrics: false
    )
  }
  
  fileprivate static func accountArmoredKeyQuery(
    for identifier: Account.LocalID
  ) -> Self {
    assert(
      !identifier.rawValue.isEmpty,
      "Cannot use empty account identifiers for private key keychain operations"
    )
    return Self(
      key: "accountArmoredKey",
      tag: .init(rawValue: identifier.rawValue),
      requiresBiometrics: false
    )
  }
  
  fileprivate static func accountPassphraseDeletionQuery() -> Self {
    Self(
      key: "accountPassphrase",
      tag: nil,
      // all passphrases has to be stored with biometrics, but it is not required to delete them
      requiresBiometrics: false
    )
  }
  
  fileprivate static func accountPassphraseQuery(
    for identifier: Account.LocalID
  ) -> Self {
    assert(
      !identifier.rawValue.isEmpty,
      "Cannot use empty account identifiers for passphrase keychain operations"
    )
    return Self(
      key: "accountPassphrase",
      tag: .init(rawValue: identifier.rawValue),
      requiresBiometrics: true
    )
  }
  
  fileprivate static func refreshTokensQuery() -> Self {
    Self(
      key: "refreshToken",
      tag: nil,
      requiresBiometrics: false
    )
  }
  
  fileprivate static func refreshTokenQuery(
    for identifier: Account.LocalID
  ) -> Self {
    assert(
      !identifier.rawValue.isEmpty,
      "Cannot use empty account identifiers for refresh token keychain operations"
    )
    return Self(
      key: "refreshToken",
      tag: .init(rawValue: identifier.rawValue),
      requiresBiometrics: false
    )
  }
}
