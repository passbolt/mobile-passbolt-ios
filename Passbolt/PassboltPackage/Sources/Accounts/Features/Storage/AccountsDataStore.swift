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

import class Foundation.NSRecursiveLock
import struct Foundation.URL

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
  internal var updatedAccountIDsPublisher: () -> AnyPublisher<Account.LocalID, Never>
  internal var accountDatabaseConnection:
    (
      _ accountID: Account.LocalID,
      _ key: String
    ) -> Result<SQLiteConnection, TheError>
}

extension AccountsDataStore: Feature {

  internal static func load(
    in environment: Environment,
    using features: FeatureFactory,
    cancellables: Cancellables
  ) -> Self {
    let files: Files = environment.files
    let preferences: Preferences = environment.preferences
    let keychain: Keychain = environment.keychain
    let database: Database = environment.database

    let diagnostics: Diagnostics = features.instance()

    let lock: NSRecursiveLock = .init()

    let updatedAccountIDSubject: PassthroughSubject<Account.LocalID, Never> = .init()

    func forceDelete(matching query: KeychainQuery) {
      diagnostics.debugLog("Purging data for \(query.key)")
      switch keychain.delete(matching: query) {
      case .success:
        break
      case let .failure(error):
        fatalError(error.description)
      }
    }
    func ensureDataIntegrity() -> Result<Void, TheError> {
      let timeMeasurement: Diagnostics.TimeMeasurement = diagnostics.measurePerformance("Data integrity check")
      lock.lock()
      diagnostics.diagnosticLog("Verifying data integrity...")
      defer {
        diagnostics.diagnosticLog("...data integrity verification finished")
        lock.unlock()
      }

      timeMeasurement.event("Begin")
      // storedAccountsList - user defaults control list
      let storedAccountsList: Array<Account.LocalID> =
        preferences
        .load(Array<Account.LocalID>.self, for: .accountsList)
      diagnostics.debugLog("Stored accounts list: \(storedAccountsList)")

      // storedAccounts - keychain accounts
      let storedAccounts: Array<Account.LocalID>
      switch keychain.loadAll(Account.self, matching: .accountsQuery) {
      case let .success(accounts):
        storedAccounts = accounts.map(\.localID)
      case let .failure(error):
        diagnostics.diagnosticLog(
          "Failed to load accounts data, recovering with empty list"
        )
        diagnostics.debugLog(error.description)
        forceDelete(matching: .accountsQuery)
        storedAccounts = .init()
      }
      diagnostics.debugLog("Stored accounts: \(storedAccounts)")
      timeMeasurement.event("Accounts loaded")

      // storedAccountProfiles - keychain accounts metadata
      let storedAccountsProfiles: Array<Account.LocalID>
      switch keychain.loadAll(AccountProfile.self, matching: .accountsProfilesQuery) {
      case let .success(accounts):
        storedAccountsProfiles = accounts.map(\.accountID)
      case let .failure(error):
        diagnostics.diagnosticLog(
          "Failed to load account profiles data, recovering with empty list"
        )
        diagnostics.debugLog(error.description)
        forceDelete(matching: .accountsProfilesQuery)
        storedAccountsProfiles = .init()
      }
      diagnostics.debugLog("Stored account profiles: \(storedAccountsProfiles)")
      timeMeasurement.event("Account profiles loaded")

      // storedAccountKeys - keychain accounts private keys
      let storedAccountKeys: Array<Account.LocalID>
      let armoredKeysQuery: KeychainQuery = .init(
        key: "accountArmoredKey",
        tag: nil,
        requiresBiometrics: false
      )
      switch keychain.loadMeta(matching: armoredKeysQuery) {
      case let .success(keysMeta):
        storedAccountKeys =
          keysMeta
          .compactMap(\.tag)
          .map { tag in
            Account.LocalID(rawValue: tag.rawValue)
          }
      case let .failure(error):
        diagnostics.diagnosticLog(
          "Failed to load armored keys metadata, recovering with empty list"
        )
        diagnostics.debugLog(error.description)
        forceDelete(matching: armoredKeysQuery)
        storedAccountKeys = .init()
      }
      diagnostics.debugLog("Stored account keys: \(storedAccountKeys)")
      timeMeasurement.event("Account keys loaded")

      let updatedAccountsList: Array<Account.LocalID> =
        storedAccountsList
        .filter {
          storedAccounts.contains($0)
            && storedAccountsProfiles.contains($0)
            && storedAccountKeys.contains($0)
        }
      environment
        .preferences
        .save(updatedAccountsList, for: .accountsList)
      diagnostics.debugLog("Updated accounts list: \(updatedAccountsList)")

      let accountsToRemove: Array<Account.LocalID> =
        storedAccounts
        .filter { !updatedAccountsList.contains($0) }

      for accountID in accountsToRemove {
        switch keychain.delete(matching: .accountQuery(for: accountID)) {
        case .success:
          continue
        case let .failure(error):
          diagnostics.diagnosticLog(
            "Failed to delete account"
          )
          diagnostics.debugLog(error.description)
          return .failure(error)
        }
      }
      diagnostics.debugLog("Deleted accounts: \(accountsToRemove)")
      timeMeasurement.event("Accounts cleaned")

      let accountProfilesToRemove: Array<Account.LocalID> =
        storedAccountsProfiles
        .filter { !updatedAccountsList.contains($0) }

      for accountID in accountProfilesToRemove {
        switch keychain.delete(matching: .accountProfileQuery(for: accountID)) {
        case .success:
          continue
        case let .failure(error):
          diagnostics.diagnosticLog(
            "Failed to delete account profile"
          )
          diagnostics.debugLog(error.description)
          return .failure(error)
        }
      }
      diagnostics.debugLog("Deleted account profiles: \(accountProfilesToRemove)")
      timeMeasurement.event("Account profiles cleaned")

      let keysToRemove: Array<Account.LocalID> =
        storedAccountKeys
        .filter { !updatedAccountsList.contains($0) }

      for accountID in keysToRemove {
        switch keychain.delete(matching: .accountArmoredKeyQuery(for: accountID)) {
        case .success:
          continue
        case let .failure(error):
          diagnostics.diagnosticLog(
            "Failed to delete account private key"
          )
          diagnostics.debugLog(error.description)
          return .failure(error)
        }
      }
      diagnostics.debugLog("Deleted account private keys: \(keysToRemove)")
      timeMeasurement.event("Account keys cleaned")

      if updatedAccountsList.isEmpty {
        diagnostics.debugLog("Deleting stored passphrases")
        switch keychain.delete(matching: .accountPassphraseDeletionQuery()) {
        case .success:
          break
        case let .failure(error):
          diagnostics.diagnosticLog(
            "Failed to delete stored passphrases"
          )
          diagnostics.debugLog(error.description)
          return .failure(error)
        }
      }
      else {
        /* We can't delete passphrases selectively due to biometrics */
      }
      timeMeasurement.event("Account passphrases cleaned")

      let applicationDataDirectory: URL
      switch files.applicationDataDirectory() {
      case let .success(url):
        applicationDataDirectory = url

      case let .failure(error):
        diagnostics.diagnosticLog(
          "Failed to access application data directory"
        )
        diagnostics.debugLog(error.description)
        return .failure(error)
      }

      let storedDatabasesResult: Result<Array<Account.LocalID>, TheError> =
        files
        .contentsOfDirectory(applicationDataDirectory)
        .map { contents -> Array<Account.LocalID> in
          contents
            .filter { fileName in
              fileName.hasSuffix(".sqlite")
            }
            .map { fileName -> Account.LocalID in
              var fileName = fileName
              fileName.removeLast(".sqlite".count)
              return .init(rawValue: fileName)
            }
        }

      let storedDatabases: Array<Account.LocalID>
      switch storedDatabasesResult {
      case let .success(databases):
        storedDatabases = databases

      case let .failure(error):
        diagnostics.diagnosticLog(
          "Failed to check database files"
        )
        diagnostics.debugLog(error.description)
        return .failure(error)
      }
      diagnostics.debugLog("Stored databases: \(storedDatabases)")
      timeMeasurement.event("Account databases loaded")

      let databasesToRemove: Array<Account.LocalID> =
        storedDatabases
        .filter { !updatedAccountsList.contains($0) }

      for accountID in databasesToRemove {
        let fileDeletionResult: Result<Void, TheError> = _databaseURL(
          forAccountWithID: accountID
        )
        .flatMap { url in
          files.deleteFile(url)
        }
        switch fileDeletionResult {
        case .success:
          break
        case let .failure(error):
          diagnostics.diagnosticLog(
            "Failed to delete database"
          )
          diagnostics.debugLog(error.description)
          return .failure(error)
        }
      }

      diagnostics.debugLog("Deleted account databases: \(databasesToRemove)")
      timeMeasurement.event("Account databases cleaned")

      let deleted: Set<Account.LocalID> = .init(
        accountsToRemove + accountProfilesToRemove + keysToRemove + databasesToRemove
      )

      diagnostics.debugLog(
        "Deleted accounts: \(deleted)"
      )

      deleted.forEach { accountID in
        updatedAccountIDSubject.send(accountID)
      }

      timeMeasurement.end()
      return .success
    }

    func loadAccounts() -> Array<Account> {
      lock.lock()
      defer { lock.unlock() }

      let keychainLoadResult: Result<Array<Account>, TheError> = environment
        .keychain
        .loadAll(
          Account.self,
          matching: .accountsQuery
        )
      switch keychainLoadResult {
      case let .success(accounts):
        return accounts
      case let .failure(error):
        diagnostics.debugLog(
          "Failed to load accounts"
            + " - status: \(error.osStatus.map(String.init(describing:)) ?? "N/A")"
        )
        return []
      }
    }

    func loadLastUsedAccount() -> Account? {
      lock.lock()
      defer { lock.unlock() }

      return environment
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
          case let .success(account):
            return account
          case let .failure(error):
            diagnostics.debugLog(
              "Failed to load last used account: \(accountID)"
                + " - status: \(error.osStatus.map(String.init(describing:)) ?? "N/A")"
            )
            return nil
          }
        }
    }

    func storeLastUsedAccount(_ accountID: Account.LocalID) {
      lock.lock()
      defer { lock.unlock() }

      preferences.save(accountID, for: .lastUsedAccount)
    }

    func store(
      account: Account,
      profile: AccountProfile,
      armoredKey: ArmoredPrivateKey
    ) -> Result<Void, TheError> {
      // data integrity check performs cleanup in case of partial success
      lock.lock()
      defer {
        ensureDataIntegrity().forceSuccess("Data integrity protection")
        lock.unlock()
        updatedAccountIDSubject.send(account.localID)
      }
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
      lock.lock()
      defer { lock.unlock() }

      return environment
        .keychain
        .loadFirst(
          ArmoredPrivateKey.self,
          matching: .accountArmoredKeyQuery(for: accountID)
        )
        .flatMap { key in
          if let key: ArmoredPrivateKey = key {
            return .success(key)
          }
          else {
            return .failure(.invalidAccount())
          }
        }
    }

    func storePassphrase(
      for accountID: Account.LocalID,
      passphrase: Passphrase
    ) -> Result<Void, TheError> {
      lock.lock()
      defer { lock.unlock() }

      return environment
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
                passphrase,
                for: .accountPassphraseQuery(for: accountID)
              )
              .flatMap { _ in
                environment
                  .keychain
                  .save(
                    updatedAccountProfile,
                    for: .accountProfileQuery(for: accountID)
                  )
              }
              .map {
                updatedAccountIDSubject.send(accountID)
              }
              .mapError { error in
                diagnostics.debugLog(error.appending(context: "Failed to store passphrase").description)
                return error
              }
          }
          else {
            return .failure(.invalidAccount())
          }
        }
    }

    func loadPassphrase(
      for accountID: Account.LocalID
    ) -> Result<Passphrase, TheError> {
      // in case of failure we should change flag biometricsEnabled to false and propagate change
      lock.lock()
      defer { lock.unlock() }

      return environment
        .keychain
        .loadFirst(Passphrase.self, matching: .accountPassphraseQuery(for: accountID))
        .flatMap { passphrase in
          if let passphrase: Passphrase = passphrase {
            return .success(passphrase)
          }
          else {
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
      lock.lock()
      defer { lock.unlock() }

      return environment
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
              .delete(matching: .accountPassphraseDeleteQuery(for: accountID))
              .flatMap { _ in
                environment
                  .keychain
                  .save(
                    updatedAccountProfile,
                    for: .accountProfileQuery(for: accountID)
                  )
              }
              .map {
                updatedAccountIDSubject.send(accountID)
              }
          }
          else {
            return .failure(.invalidAccount())
          }
        }
    }

    func loadAccountProfile(
      for accountID: Account.LocalID
    ) -> Result<AccountProfile, TheError> {
      lock.lock()
      defer { lock.unlock() }

      return environment
        .keychain
        .loadFirst(AccountProfile.self, matching: .accountProfileQuery(for: accountID))
        .flatMap { profile in
          if let profile: AccountProfile = profile {
            return .success(profile)
          }
          else {
            return .failure(.invalidAccount())
          }
        }
    }

    func update(
      accountProfile: AccountProfile
    ) -> Result<Void, TheError> {
      lock.lock()

      let accountsList: Array<Account.LocalID> = environment
        .preferences
        .load(Array<Account.LocalID>.self, for: .accountsList)
      guard accountsList.contains(accountProfile.accountID)
      else { return .failure(.invalidAccount()) }
      return environment
        .keychain
        .save(accountProfile, for: .accountProfileQuery(for: accountProfile.accountID))
        .map {
          lock.unlock()
          updatedAccountIDSubject.send(accountProfile.accountID)
        }
        .mapError { error in
          lock.unlock()
          return error
        }
    }

    func deleteAccount(withID accountID: Account.LocalID) {
      // There is a risk of calling this method with valid session for deleted account,
      // we should assert on that or make it impossible")

      lock.lock()
      // data integrity check performs cleanup in case of partial success
      defer {
        ensureDataIntegrity().forceSuccess("Data integrity protection")
        lock.unlock()
        updatedAccountIDSubject.send(accountID)
      }

      var accountIdentifiers: Array<Account.LocalID> = environment
        .preferences
        .load(Array<Account.LocalID>.self, for: .accountsList)

      accountIdentifiers.removeAll(where: { $0 == accountID })
      preferences.save(accountIdentifiers, for: .accountsList)
      let lastUsedAccount: Account.LocalID? = environment
        .preferences
        .load(
          Account.LocalID.self,
          for: .lastUsedAccount
        )
      if lastUsedAccount == accountID {
        environment
          .preferences
          .deleteValue(
            for: .lastUsedAccount
          )
      }
      else {
        /* */
      }

      var results: Array<Result<Void, TheError>> = .init()
      results.append(
        environment
          .keychain
          .delete(matching: .accountPassphraseQuery(for: accountID))
      )
      results.append(
        environment
          .keychain
          .delete(matching: .accountArmoredKeyQuery(for: accountID))
      )
      results.append(
        environment
          .keychain
          .delete(matching: .accountQuery(for: accountID))
      )
      results.append(
        environment
          .keychain
          .delete(matching: .accountProfileQuery(for: accountID))
      )
      results.append(
        _databaseURL(
          forAccountWithID: accountID
        )
        .flatMap { databaseURL in
          files
            .deleteFile(databaseURL)
        }
      )

      do {
        #warning("TODO: Consider propagating errors outside of this function")
        try results.forEach { try $0.get() }
      }
      catch {
        diagnostics.diagnosticLog("Failed to properly delete account")
        diagnostics.debugLog("\(error)")
      }
    }

    func _databaseURL(
      forAccountWithID accountID: Account.LocalID
    ) -> Result<URL, TheError> {
      files.applicationDataDirectory()
        .map { dir in
          dir
            .appendingPathComponent(accountID.rawValue)
            .appendingPathExtension("sqlite")
        }
        .mapError { error in
          TheError.databaseConnectionError(
            underlyingError: error,
            databaseErrorMessage: "Cannot access database file"
          )
        }
    }

    func prepareDatabaseConnection(
      forAccountWithID accountID: Account.LocalID,
      key: String
    ) -> Result<SQLiteConnection, TheError> {
      let databaseURL: URL
      switch _databaseURL(forAccountWithID: accountID) {
      case let .success(path):
        databaseURL = path

      case let .failure(error):
        return .failure(error)
      }

      return
        database
        .openConnection(
          databaseURL.absoluteString,
          key,
          SQLiteMigration.allCases
        )
        .flatMapError { error in
          diagnostics.diagnosticLog("Failed to open database for accountID, cleaning up...")
          diagnostics.debugLog(error.description)
          _ = files.deleteFile(databaseURL)
          // single retry after deleting previous database, fail if it fails
          return
            database
            .openConnection(
              databaseURL.absoluteString,
              key,
              SQLiteMigration.allCases
            )
        }
    }

    return Self(
      verifyDataIntegrity: ensureDataIntegrity,
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
      updatedAccountIDsPublisher: updatedAccountIDSubject.eraseToAnyPublisher,
      accountDatabaseConnection: prepareDatabaseConnection(forAccountWithID:key:)
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
      updatedAccountIDsPublisher: Commons.placeholder("You have to provide mocks for used methods"),
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

  fileprivate static func accountPassphraseDeleteQuery(
    for identifier: Account.LocalID
  ) -> Self {
    assert(
      !identifier.rawValue.isEmpty,
      "Cannot use empty account identifiers for passphrase keychain operations"
    )
    return Self(
      key: "accountPassphrase",
      tag: .init(rawValue: identifier.rawValue),
      requiresBiometrics: false
    )
  }
}
