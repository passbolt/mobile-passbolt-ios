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

#warning("TODO: [PAS-82] Replace with proper type")
internal typealias DatabaseConnection = Void

#warning("TODO: [PAS-82] - database")
#warning("TODO: [PAS-69] - session")
internal struct AccountsDataStore {
  
  internal var verifyDataIntegrity: () -> Result<Void, TheError>
  internal var loadAccounts: () -> Array<Account>
  internal var storeAccount: (Account, ArmoredPrivateKey) -> Result<Void, TheError>
  internal var deleteAccount: (Account) -> Void
  internal var databaseConnection: (Account) -> Result<DatabaseConnection, TheError>
}

extension AccountsDataStore: Feature {
  
  internal typealias Environment = (
    preferences: Preferences,
    keychain: Keychain
  )
  
  internal static func environmentScope(
    _ rootEnvironment: RootEnvironment
  ) -> Environment {
    (
      preferences: rootEnvironment.preferences,
      keychain: rootEnvironment.keychain
    )
  }
  
  // swiftlint:disable:next function_body_length
  internal static func load(
    in environment: Environment,
    using features: FeatureFactory,
    cancellables: inout Array<AnyCancellable>
  ) -> Self {
    let diagnostics: Diagnostics = features.instance()
    
    // swiftlint:disable:next cyclomatic_complexity
    func checkDataIntegrity() -> Result<Void, TheError> {
      diagnostics.debugLog("Verifying data integrity...")
      defer { diagnostics.debugLog("...data integrity verification finished") }
      
      // storedAccountsList - user defaults control list
      let storedAccountsList: Array<Account.LocalID> = environment
        .preferences
        .load(Array<Account.LocalID>.self, for: .accountsList)
      diagnostics.debugLog("Stored accounts list: \(storedAccountsList)")
      
      // storedAccounts - keychain accounts metadata
      let storedAccounts: Array<Account.LocalID>
      switch environment.keychain.loadAll(Account.self, matching: .accountsQuery) {
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
      
      // storedAccountKeys - keychain accounts private keys
      let storedAccountKeys: Array<Account.LocalID>
      let armoredKeysQuery: KeychainQuery = .init(
        key: "accountArmoredKey",
        tag: nil,
        requiresBiometrics: false
      )
      switch environment.keychain.loadMeta(matching: armoredKeysQuery) {
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
          && storedAccountKeys.contains($0)
        }
      environment
        .preferences
        .save(updatedAccountsList, for: .accountsList)
      diagnostics.debugLog("Updated accounts list: \(updatedAccountsList)")
      
      let accountsToRemove: Array<Account.LocalID> = storedAccounts
        .filter { !updatedAccountsList.contains($0) }
      
      for accountID in accountsToRemove {
        switch environment.keychain.delete(matching: .accountQuery(for: accountID)) {
        case .success:
          continue
        // swiftlint:disable:next explicit_type_interface
        case let .failure(error):
          diagnostics.debugLog(
            "Failed to delete account data for accountID: \(updatedAccountsList)"
            + " - status: \(error.osStatus.map(String.init(describing:)) ?? "N/A")"
          )
          return .failure(error)
        }
      }
      diagnostics.debugLog("Deleted accounts: \(accountsToRemove)")
      
      let keysToRemove: Array<Account.LocalID> = storedAccountKeys
        .filter { !updatedAccountsList.contains($0) }
      
      for accountID in keysToRemove {
        switch environment.keychain.delete(matching: .accountArmoredKeyQuery(for: accountID)) {
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
        switch environment.keychain.delete(matching: .accountPassphraseDeletionQuery()) {
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
      } else { /* */ }
      #warning(
        "[PAS-69] Verify stored passphrase? We can't verify stored passphrase keychain items due to biometrics requirement"
      )
      
      #warning("TODO: [PAS-82] Verify database files (remove detached)")
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
        diagnostics.log(
          "Failed to load keychain data - status: \(error.osStatus.map(String.init(describing:)) ?? "N/A")"
        )
        return []
      }
    }
    
    func store(
      account: Account,
      with key: ArmoredPrivateKey
    ) -> Result<Void, TheError> {
      // data integrity check performs cleanup in case of partial success
      defer { checkDataIntegrity().forceSuccess("Data integrity protection") }
      var accountIdentifiers: Array<Account.LocalID> = environment
        .preferences
        .load(Array<Account.LocalID>.self, for: .accountsList)
      accountIdentifiers.append(account.localID)
      environment.preferences.save(accountIdentifiers, for: .accountsList)
      #warning("TODO: [PAS-82] create database if needed")
      return environment
        .keychain
        .save(account, for: .accountQuery(for: account.localID))
        .flatMap { _ in
          environment
            .keychain
            .save(key, for: .accountArmoredKeyQuery(for: account.localID))
        }
    }
    
    func delete(account: Account) {
      // data integrity check performs cleanup in case of partial success
      defer { checkDataIntegrity().forceSuccess("Data integrity protection") }
      _ = environment
        .keychain
        .delete(matching: .accountPassphraseDeletionQuery(for: account.localID))
      _ = environment
        .keychain
        .delete(matching: .accountArmoredKeyQuery(for: account.localID))
      _ = environment
        .keychain
        .delete(matching: .accountQuery(for: account.localID))
      var accountIdentifiers: Array<Account.LocalID> = environment
        .preferences
        .load(Array<Account.LocalID>.self, for: "")
      accountIdentifiers.removeAll(where: { $0 == account.localID })
      environment.preferences.save(accountIdentifiers, for: .accountsList)
      
      #warning("TODO: [PAS-82] remove database files")
    }
    
    func prepareDatabaseConnection(
      for account: Account
    ) -> Result<DatabaseConnection, TheError> {
      #warning("TODO: [PAS-82]")
      // this should be the place where we manage access to database files
      // and provide connections if needed (it might be covered by higher level API)
      Commons.placeholder("TODO: database")
    }
    
    return Self(
      verifyDataIntegrity: checkDataIntegrity,
      loadAccounts: loadAccounts,
      storeAccount: store(account:with:),
      deleteAccount: delete(account:),
      databaseConnection: prepareDatabaseConnection(for:)
    )
  }
  
  #if DEBUG
  internal static var placeholder: Self {
    Self(
      verifyDataIntegrity: Commons.placeholder("You have to provide mocks for used methods"),
      loadAccounts: Commons.placeholder("You have to provide mocks for used methods"),
      storeAccount: Commons.placeholder("You have to provide mocks for used methods"),
      deleteAccount: Commons.placeholder("You have to provide mocks for used methods"),
      databaseConnection: Commons.placeholder("You have to provide mocks for used methods")
    )
  }
  #endif
}

extension Preferences.Key {
  
  fileprivate static var accountsList: Self { "accountsList" }
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
  
  #warning("TODO: [PAS-131] Specify file name in Safety containing this query")
  // Safety contains another, private copy of this query
  // if you are modyfying it make sure to modify both.
  // We made so to hide access to armored key as much as possible
  // to avoid getting it from any unwanted place.
  // It can only be stored, deleted and loaded for specific cryptograhic operation.
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
  
  #warning("TODO: [PAS-131] Specify file name in Safety containing this query")
  // Safety contains another, private counterpart of this query
  // if you are modyfying it make sure to modify both.
  // We made so to hide access to passphrase as much as possible
  // to avoid getting it from any unwanted place.
  // It can only be stored, deleted and loaded for specific cryptograhic operation.
  fileprivate static func accountPassphraseDeletionQuery() -> Self {
    Self(
      key: "accountPassphrase",
      tag: nil,
      // all passphrases has to be stored with biometrics, but it is not required to delete them
      requiresBiometrics: false
    )
  }
  
  #warning("TODO: [PAS-131] Specify file name in Safety containing this query")
  // Safety contains another, private counterpart of this query
  // if you are modyfying it make sure to modify both.
  // We made so to hide access to passphrase as much as possible
  // to avoid getting it from any unwanted place.
  // It can only be stored, deleted and loaded for specific cryptograhic operation.
  fileprivate static func accountPassphraseDeletionQuery(
    for identifier: Account.LocalID
  ) -> Self {
    assert(
      !identifier.rawValue.isEmpty,
      "Cannot use empty account identifiers for passphrase keychain operations"
    )
    return Self(
      key: "accountPassphrase",
      tag: .init(rawValue: identifier.rawValue),
      // all passphrases have to be stored with biometrics, but it is not required to delete them
      requiresBiometrics: false
    )
  }
}
