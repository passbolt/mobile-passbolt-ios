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
#warning("TODO: [PAS-131] - session")
// swiftlint:disable file_length
internal struct AccountsDataStore {
  
  internal var verifyDataIntegrity: () -> Result<Void, TheError>
  internal var loadAccounts: () -> Array<Account>
  internal var loadLastUsedAccount: () -> Account?
  internal var storeLastUsedAccount: (Account.LocalID) -> Void
  internal var storeAccount: (Account, AccountDetails, ArmoredPrivateKey) -> Result<Void, TheError>
  internal var loadAccountPrivateKey: (Account.LocalID) -> Result<ArmoredPrivateKey, TheError>
  internal var storeAccountPassphrase: (Account.LocalID, Passphrase) -> Result<Void, TheError>
  internal var loadAccountPassphrase: (Account.LocalID) -> Result<Passphrase, TheError>
  internal var deleteAccountPassphrase: (Account.LocalID) -> Result<Void, TheError>
  internal var loadAccountDetails: (Account.LocalID) -> Result<AccountDetails, TheError>
  internal var updateAccountDetails: (AccountDetails) -> Result<Void, TheError>
  internal var deleteAccount: (Account.LocalID) -> Void
  internal var accountDatabaseConnection: (Account.LocalID) -> Result<DatabaseConnection, TheError>
}

extension AccountsDataStore: Feature {
  
  internal typealias Environment = (
    preferences: Preferences,
    keychain: Keychain,
    uuidGenerator: UUIDGenerator
  )
  
  internal static func environmentScope(
    _ rootEnvironment: RootEnvironment
  ) -> Environment {
    (
      preferences: rootEnvironment.preferences,
      keychain: rootEnvironment.keychain,
      uuidGenerator: rootEnvironment.uuidGenerator
    )
  }
  
  // swiftlint:disable:next function_body_length
  internal static func load(
    in environment: Environment,
    using features: FeatureFactory,
    cancellables: inout Array<AnyCancellable>
  ) -> Self {
    let diagnostics: Diagnostics = features.instance()
    
    // swiftlint:disable:next cyclomatic_complexity function_body_length cyclomatic_complexity
    func checkDataIntegrity() -> Result<Void, TheError> {
      diagnostics.debugLog("Verifying data integrity...")
      defer { diagnostics.debugLog("...data integrity verification finished") }
      
      // storedAccountsList - user defaults control list
      let storedAccountsList: Array<Account.LocalID> = environment
        .preferences
        .load(Array<Account.LocalID>.self, for: .accountsList)
      diagnostics.debugLog("Stored accounts list: \(storedAccountsList)")
      
      // storedAccounts - keychain accounts
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
      
      // storedAccountsDetails - keychain accounts metadata
      let storedAccountsDetails: Array<Account.LocalID>
      switch environment.keychain.loadAll(AccountDetails.self, matching: .accountsDetailsQuery) {
      // swiftlint:disable:next explicit_type_interface
      case let .success(accounts):
        storedAccountsDetails = accounts.map(\.accountID)
      // swiftlint:disable:next explicit_type_interface
      case let .failure(error):
        diagnostics.debugLog(
          "Failed to load keychain accounts details data, recovering with empty list"
            + " - status: \(error.osStatus.map(String.init(describing:)) ?? "N/A")"
        )
        storedAccountsDetails = .init()
      }
      diagnostics.debugLog("Stored accounts details: \(storedAccountsDetails)")
      
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
          && storedAccountsDetails.contains($0)
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
            "Failed to delete account for accountID: \(updatedAccountsList)"
            + " - status: \(error.osStatus.map(String.init(describing:)) ?? "N/A")"
          )
          return .failure(error)
        }
      }
      diagnostics.debugLog("Deleted accounts: \(accountsToRemove)")
      
      let accountsDetailsToRemove: Array<Account.LocalID> = storedAccountsDetails
        .filter { !updatedAccountsList.contains($0) }
      
      for accountID in accountsDetailsToRemove {
        switch environment.keychain.delete(matching: .accountDetailsQuery(for: accountID)) {
        case .success:
          continue
        // swiftlint:disable:next explicit_type_interface
        case let .failure(error):
          diagnostics.debugLog(
            "Failed to delete account details for accountID: \(updatedAccountsList)"
              + " - status: \(error.osStatus.map(String.init(describing:)) ?? "N/A")"
          )
          return .failure(error)
        }
      }
      diagnostics.debugLog("Deleted accounts details: \(accountsDetailsToRemove)")
      
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
      } else { /* We can't delete passphrases selectively due to biometrics */ }
      
      #warning("TODO: [PAS-82] Verify database files and remove detached")
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
      environment.preferences.save(accountID, for: .lastUsedAccount)
    }
    
    func store(
      account: Account,
      details: AccountDetails,
      armoredKey: ArmoredPrivateKey
    ) -> Result<Void, TheError> {
      // data integrity check performs cleanup in case of partial success
      defer { checkDataIntegrity().forceSuccess("Data integrity protection") }
      var accountIdentifiers: Array<Account.LocalID> = environment
        .preferences
        .load(Array<Account.LocalID>.self, for: .accountsList)
      accountIdentifiers.append(account.localID)
      environment.preferences.save(accountIdentifiers, for: .accountsList)
      
      return environment
        .keychain
        .save(details, for: .accountDetailsQuery(for: account.localID))
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
          AccountDetails.self,
          matching: .accountDetailsQuery(for: accountID)
        )
        .flatMap { accountDetails in
          if var updatedAccountDetails: AccountDetails = accountDetails {
            updatedAccountDetails.biometricsEnabled = true
            return environment
              .keychain
              .save(
                updatedAccountDetails,
                for: .accountDetailsQuery(for: accountID)
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
          AccountDetails.self,
          matching: .accountDetailsQuery(for: accountID)
        )
        .flatMap { accountDetails in
          if var updatedAccountDetails: AccountDetails = accountDetails {
            updatedAccountDetails.biometricsEnabled = false
            return environment
              .keychain
              .save(
                updatedAccountDetails,
                for: .accountDetailsQuery(for: accountID)
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
    
    func loadAccountDetails(
      for accountID: Account.LocalID
    ) -> Result<AccountDetails, TheError> {
      environment
        .keychain
        .loadFirst(AccountDetails.self, matching: .accountDetailsQuery(for: accountID))
        .flatMap { details in
          if let details: AccountDetails = details {
            return .success(details)
          } else {
            return .failure(.invalidAccount())
          }
        }
    }
    
    func update(
      accountDetails: AccountDetails
    ) -> Result<Void, TheError> {
      let accountsList: Array<Account.LocalID> = environment
        .preferences
        .load(Array<Account.LocalID>.self, for: .accountsList)
      guard accountsList.contains(accountDetails.accountID)
      else { return .failure(.invalidAccount()) }
      return environment
        .keychain
        .save(accountDetails, for: .accountDetailsQuery(for: accountDetails.accountID))
    }
    
    func deleteAccount(withID accountID: Account.LocalID) {
      // There is a risk of calling this method with valid session for deleted account,
      // we should assert on that or make it impossible")
      
      // data integrity check performs cleanup in case of partial success
      defer { checkDataIntegrity().forceSuccess("Data integrity protection") }
      _ = environment
        .keychain
        .delete(matching: .accountPassphraseQuery(for: accountID))
      _ = environment
        .keychain
        .delete(matching: .accountArmoredKeyQuery(for: accountID))
      _ = environment
        .keychain
        .delete(matching: .accountQuery(for: accountID))
      var accountIdentifiers: Array<Account.LocalID> = environment
        .preferences
        .load(Array<Account.LocalID>.self, for: .accountsList)
      accountIdentifiers.removeAll(where: { $0 == accountID })
      environment.preferences.save(accountIdentifiers, for: .accountsList)
      #warning("TODO: [PAS-82] remove database files")
    }
    
    func prepareDatabaseConnection(
      forAccountWithID accountID: Account.LocalID
    ) -> Result<DatabaseConnection, TheError> {
      #warning("TODO: [PAS-82] prepare connection and files if needed")
      return .success(DatabaseConnection.placeholder)
    }
    
    return Self(
      verifyDataIntegrity: checkDataIntegrity,
      loadAccounts: loadAccounts,
      loadLastUsedAccount: loadLastUsedAccount,
      storeLastUsedAccount: storeLastUsedAccount,
      storeAccount: store(account:details:armoredKey:),
      loadAccountPrivateKey: loadAccountPrivateKey(for:),
      storeAccountPassphrase: storePassphrase(for:passphrase:),
      loadAccountPassphrase: loadPassphrase(for:),
      deleteAccountPassphrase: deletePassphrase(for:),
      loadAccountDetails: loadAccountDetails(for:),
      updateAccountDetails: update(accountDetails:),
      deleteAccount: deleteAccount(withID:),
      accountDatabaseConnection: prepareDatabaseConnection(forAccountWithID:)
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
      loadAccountDetails: Commons.placeholder("You have to provide mocks for used methods"),
      updateAccountDetails: Commons.placeholder("You have to provide mocks for used methods"),
      deleteAccount: Commons.placeholder("You have to provide mocks for used methods"),
      accountDatabaseConnection: Commons.placeholder("You have to provide mocks for used methods")
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
  
  fileprivate static var accountsDetailsQuery: Self {
    Self(
      key: "accountDetails",
      tag: nil,
      requiresBiometrics: false
    )
  }
  
  fileprivate static func accountDetailsQuery(
    for identifier: Account.LocalID
  ) -> Self {
    assert(
      !identifier.rawValue.isEmpty,
      "Cannot use empty account identifiers for account keychain operations"
    )
    return Self(
      key: "accountDetails",
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
      // all passphrases have to be stored with biometrics, but it is not required to delete them
      requiresBiometrics: false
    )
  }
}
