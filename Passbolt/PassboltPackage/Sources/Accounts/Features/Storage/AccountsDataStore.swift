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

import CommonModels
import Crypto
import Features

import struct Foundation.URL
import let LocalAuthentication.errSecAuthFailed

internal struct AccountsDataStore {

  internal var verifyDataIntegrity: @StorageAccessActor () -> Result<Void, Error>
  internal var loadAccounts: @StorageAccessActor () -> Array<Account>
  internal var loadLastUsedAccount: @StorageAccessActor () -> Account?
  internal var storeLastUsedAccount: @StorageAccessActor (Account.LocalID) -> Void
  internal var storeAccount: @StorageAccessActor (Account, AccountProfile, ArmoredPGPPrivateKey) -> Result<Void, Error>
  internal var loadAccountPrivateKey: @StorageAccessActor (Account.LocalID) -> Result<ArmoredPGPPrivateKey, Error>
  internal var storeAccountPassphrase: @StorageAccessActor (Account.LocalID, Passphrase) -> Result<Void, Error>
  internal var loadAccountPassphrase: @StorageAccessActor (Account.LocalID) -> Result<Passphrase, Error>
  internal var deleteAccountPassphrase: @StorageAccessActor (Account.LocalID) -> Result<Void, Error>
  internal var storeAccountMFAToken: @StorageAccessActor (Account.LocalID, MFAToken) -> Result<Void, Error>
  internal var loadAccountMFAToken: @StorageAccessActor (Account.LocalID) -> Result<MFAToken?, Error>
  internal var deleteAccountMFAToken: @StorageAccessActor (Account.LocalID) -> Result<Void, Error>
  internal var loadAccountProfile: @StorageAccessActor (Account.LocalID) -> Result<AccountProfile, Error>
  internal var updateAccountProfile: @StorageAccessActor (AccountProfile) -> Result<Void, Error>
  internal var deleteAccount: @StorageAccessActor (Account.LocalID) -> Void
  internal var updatedAccountIDsPublisher: () -> AnyPublisher<Account.LocalID, Never>
  internal var accountDatabaseConnection:
    @StorageAccessActor (
      _ accountID: Account.LocalID,
      _ key: String
    ) throws -> SQLiteConnection
  internal var storeServerFingerprint: @StorageAccessActor (Account.LocalID, Fingerprint) -> Result<Void, Error>
  internal var loadServerFingerprint: @StorageAccessActor (Account.LocalID) -> Result<Fingerprint?, Error>
}

extension AccountsDataStore: Feature {

  internal static func load(
    in environment: AppEnvironment,
    using features: FeatureFactory,
    cancellables: Cancellables
  ) async throws -> Self {
    let files: Files = environment.files
    let preferences: Preferences = environment.preferences
    let keychain: Keychain = environment.keychain
    let database: Database = environment.database

    let diagnostics: Diagnostics = try await features.instance()

    let updatedAccountIDSubject: PassthroughSubject<Account.LocalID, Never> = .init()

    @StorageAccessActor func forceDelete(matching query: KeychainQuery) {
      diagnostics.debugLog("Purging data for \(query.key)")
      switch keychain.delete(matching: query) {
      case .success:
        break
      case let .failure(error):
        error
          .asTheError()
          .pushing(.message("Keychain data force delete failed"))
          .recording(query, for: "query")
          .asFatalError()
      }
    }

    @StorageAccessActor func ensureDataIntegrity() -> Result<Void, Error> {
      let timeMeasurement: Diagnostics.TimeMeasurement = diagnostics.measurePerformance("Data integrity check")
      diagnostics.diagnosticLog("Verifying data integrity...")
      defer {
        diagnostics.diagnosticLog("...data integrity verification finished")
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
        diagnostics.log(error)
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
        diagnostics.log(error)
        forceDelete(matching: .accountsProfilesQuery)
        storedAccountsProfiles = .init()
      }
      diagnostics.debugLog("Stored account profiles: \(storedAccountsProfiles)")
      timeMeasurement.event("Account profiles loaded")

      // storedAccountMFATokens - keychain accounts mfa tokens
      let storedAccountMFATokens: Array<Account.LocalID>
      switch keychain.loadMeta(matching: .accountMFATokenQuery()) {
      case let .success(accounts):
        storedAccountMFATokens =
          accounts
          .compactMap(\.tag?.rawValue)
          .map(Account.LocalID.init(rawValue:))
      case let .failure(error):
        diagnostics.diagnosticLog(
          "Failed to load account mfa tokens data, recovering with empty list"
        )
        diagnostics.log(error)
        forceDelete(matching: .accountsProfilesQuery)
        storedAccountMFATokens = .init()
      }
      diagnostics.debugLog("Stored account mfa tokens: \(storedAccountMFATokens)")
      timeMeasurement.event("Account mfa tokens loaded")

      // storedServerFingerprints - keychain accounts server fingerprints
      let storedServerFingerprints: Array<Account.LocalID>
      switch keychain.loadMeta(matching: .serverFingerprintQuery()) {
      case let .success(accounts):
        storedServerFingerprints =
          accounts
          .compactMap(\.tag?.rawValue)
          .map(Account.LocalID.init(rawValue:))
      case let .failure(error):
        diagnostics.diagnosticLog(
          "Failed to load account server fingerprint data, recovering with empty list"
        )
        diagnostics.log(error)
        forceDelete(matching: .accountsProfilesQuery)
        storedServerFingerprints = .init()
      }
      diagnostics.debugLog("Stored server fingerprints: \(storedServerFingerprints)")
      timeMeasurement.event("Account server fingerprints")

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
        diagnostics.log(error)
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
          diagnostics.diagnosticLog("Failed to delete account")
          return .failure(
            error
              .asTheError()
              .pushing(.message("Failed to delete account"))
              .recording(accountID, for: "accountID")
          )
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
          diagnostics.diagnosticLog("Failed to delete account profile")
          return .failure(
            error
              .asTheError()
              .pushing(.message("Failed to delete account profile"))
              .recording(accountID, for: "accountID")
          )
        }
      }
      diagnostics.debugLog("Deleted account profiles: \(accountProfilesToRemove)")
      timeMeasurement.event("Account profiles cleaned")

      let mfaTokensToRemove: Array<Account.LocalID> =
        storedAccountMFATokens
        .filter { !updatedAccountsList.contains($0) }

      for accountID in mfaTokensToRemove {
        switch keychain.delete(matching: .accountMFATokenQuery(for: accountID)) {
        case .success:
          continue
        case let .failure(error):
          diagnostics.diagnosticLog(
            "Failed to delete account mfa token"
          )
          return .failure(error)
        }
      }
      diagnostics.debugLog("Deleted account mfa tokens: \(mfaTokensToRemove)")
      timeMeasurement.event("Account mfa tokens cleaned")

      let serverFingerprintsToRemove: Array<Account.LocalID> =
        storedServerFingerprints
        .filter { !updatedAccountsList.contains($0) }

      for accountID in serverFingerprintsToRemove {
        switch keychain.delete(matching: .serverFingerprintQuery(for: accountID)) {
        case .success:
          continue
        case let .failure(error):
          diagnostics.diagnosticLog("Failed to delete server fingerprint")
          return .failure(
            error
              .asTheError()
              .pushing(.message("Failed to delete server fingerpring"))
              .recording(accountID, for: "accountID")
          )
        }
      }
      diagnostics.debugLog("Deleted server fingerprints: \(serverFingerprintsToRemove)")
      timeMeasurement.event("Account server fingerprints cleaned")

      let keysToRemove: Array<Account.LocalID> =
        storedAccountKeys
        .filter { !updatedAccountsList.contains($0) }

      for accountID in keysToRemove {
        switch keychain.delete(matching: .accountArmoredKeyQuery(for: accountID)) {
        case .success:
          continue
        case let .failure(error):
          diagnostics.diagnosticLog("Failed to delete account private key")
          return .failure(
            error
              .asTheError()
              .pushing(.message("Failed to delete account private key"))
              .recording(accountID, for: "accountID")
          )
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
          diagnostics.diagnosticLog("Failed to delete stored passphrases")
          return .failure(
            error
              .pushing(.message("Failed to delete stored passphrases"))
          )
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
        diagnostics.diagnosticLog("Failed to access application data directory")
        return .failure(error)
      }

      let storedDatabasesResult: Result<Array<Account.LocalID>, Error> =
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
        return .failure(error)
      }
      diagnostics.debugLog("Stored databases: \(storedDatabases)")
      timeMeasurement.event("Account databases loaded")

      let databasesToRemove: Array<Account.LocalID> =
        storedDatabases
        .filter { !updatedAccountsList.contains($0) }

      for accountID in databasesToRemove {
        let fileDeletionResult: Result<Void, Error> =
          Result {
            try _databaseURL(
              forAccountWithID: accountID
            )
          }
          .flatMap(files.deleteFile)

        switch fileDeletionResult {
        case .success:
          break
        case let .failure(error):
          diagnostics.diagnosticLog("Failed to delete database")
          return .failure(
            error
              .asTheError()
              .pushing(.message("Failed to delete accoiunt database"))
              .recording(accountID, for: "accountID")
          )
        }
      }

      diagnostics.debugLog("Deleted account databases: \(databasesToRemove)")
      timeMeasurement.event("Account databases cleaned")

      let deleted: Set<Account.LocalID> = .init(
        accountsToRemove + accountProfilesToRemove + keysToRemove + databasesToRemove
      )

      diagnostics.debugLog("Deleted accounts: \(deleted)")

      deleted.forEach { accountID in
        updatedAccountIDSubject.send(accountID)
      }

      timeMeasurement.end()
      return .success
    }

    @StorageAccessActor func loadAccounts() -> Array<Account> {
      let keychainLoadResult: Result<Array<Account>, Error> = environment
        .keychain
        .loadAll(
          Account.self,
          matching: .accountsQuery
        )
      switch keychainLoadResult {
      case let .success(accounts):
        return accounts
      case let .failure(error):
        diagnostics
          .log(
            error,
            info: .message("Failed to load accounts")
          )
        return []
      }
    }

    @StorageAccessActor func loadLastUsedAccount() -> Account? {
      return environment
        .preferences
        .load(
          Account.LocalID.self,
          for: .lastUsedAccount
        )
        .flatMap { accountID in
          let keychainResult: Result<Account?, Error> = environment
            .keychain
            .loadFirst(
              Account.self,
              matching: .accountQuery(for: accountID)
            )
          switch keychainResult {
          case let .success(account):
            return account
          case let .failure(error):
            diagnostics
              .log(
                error,
                info: .message("Failed to load last used account")
              )
            return nil
          }
        }
    }

    @StorageAccessActor func storeLastUsedAccount(_ accountID: Account.LocalID) {
      preferences.save(accountID, for: .lastUsedAccount)
    }

    @StorageAccessActor func store(
      account: Account,
      profile: AccountProfile,
      armoredKey: ArmoredPGPPrivateKey
    ) -> Result<Void, Error> {
      // data integrity check performs cleanup in case of partial success
      defer {
        ensureDataIntegrity().forceSuccess("Data integrity protection")
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

    @StorageAccessActor func loadAccountPrivateKey(
      for accountID: Account.LocalID
    ) -> Result<ArmoredPGPPrivateKey, Error> {
      return environment
        .keychain
        .loadFirst(
          ArmoredPGPPrivateKey.self,
          matching: .accountArmoredKeyQuery(for: accountID)
        )
        .flatMap { key in
          if let key: ArmoredPGPPrivateKey = key {
            return .success(key)
          }
          else {
            return .failure(
              AccountPrivateKeyMissing
                .error()
                .recording(accountID, for: "accountID")
            )
          }
        }
    }

    @StorageAccessActor func storePassphrase(
      for accountID: Account.LocalID,
      passphrase: Passphrase
    ) -> Result<Void, Error> {
      return environment
        .keychain
        .loadFirst(
          AccountProfile.self,
          matching: .accountProfileQuery(for: accountID)
        )
        .flatMap { accountProfile in
          if var updatedAccountProfile: AccountProfile = accountProfile {
            guard !updatedAccountProfile.biometricsEnabled
            else { return .success }
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
                error
                  .asTheError()
                  .pushing(.message("Failed to store account passphrase"))
                  .recording(accountID, for: "accountID")
              }
          }
          else {
            return .failure(
              AccountProfileDataMissing
                .error("Failed to store account passphrase")
                .recording(accountID, for: "accountID")
            )
          }
        }
    }

    @StorageAccessActor func loadPassphrase(
      for accountID: Account.LocalID
    ) -> Result<Passphrase, Error> {
      // in case of failure we should change flag biometricsEnabled to false and propagate change
      return environment
        .keychain
        .loadFirst(
          Passphrase.self,
          matching: .accountPassphraseQuery(for: accountID)
        )
        .flatMap { passphrase in
          if let passphrase: Passphrase = passphrase {
            return .success(passphrase)
          }
          else {
            return .failure(
              AccountPassphraseMissing
                .error("Failed to load account passphrase")
                .recording(accountID, for: "accountID")
            )
          }
        }
        .mapError { error -> Error in
          diagnostics.diagnosticLog("...failed to load passphrase from keychain...")
          if error is AccountPassphraseMissing {
            // Ensure that account profile has biometrics disabled
            // when passphrase is unavailable
            _ = environment
              .keychain
              .loadFirst(
                AccountProfile.self,
                matching: .accountProfileQuery(for: accountID)
              )
              .flatMap { (accountProfile: AccountProfile?) -> Result<Void, Error> in
                if var updatedAccountProfile: AccountProfile = accountProfile {
                  guard updatedAccountProfile.biometricsEnabled
                  else { return .success }
                  updatedAccountProfile.biometricsEnabled = false
                  return environment
                    .keychain
                    .save(
                      updatedAccountProfile,
                      for: .accountProfileQuery(for: accountID)
                    )
                    .map {
                      updatedAccountIDSubject.send(accountID)
                    }
                }
                else {
                  return .failure(
                    AccountProfileDataMissing
                      .error()
                      .pushing(.message("Failed to load account passphrase"))
                      .recording(accountID, for: "accountID")
                  )
                }
              }

            return
              AccountBiometryDataChanged
              .error()
              .pushing(.message("Failed to load account passphrase"))
              .recording(accountID, for: "accountID")
          }
          else if error is Cancelled {
            return error
          }
          else {
            return error
          }
        }
    }

    @StorageAccessActor func deletePassphrase(
      for accountID: Account.LocalID
    ) -> Result<Void, Error> {
      return environment
        .keychain
        .loadFirst(
          AccountProfile.self,
          matching: .accountProfileQuery(for: accountID)
        )
        .flatMap { accountProfile in
          if var updatedAccountProfile: AccountProfile = accountProfile {
            guard updatedAccountProfile.biometricsEnabled
            else { return .success }
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
            return .failure(
              AccountProfileDataMissing
                .error("Failed to delete account passphrase")
                .recording(accountID, for: "accountID")
            )
          }
        }
    }

    @StorageAccessActor func storeAccountMFAToken(
      accountID: Account.LocalID,
      token: MFAToken
    ) -> Result<Void, Error> {
      environment
        .keychain
        .save(token, for: .accountMFATokenQuery(for: accountID))
    }

    @StorageAccessActor func loadAccountMFAToken(
      accountID: Account.LocalID
    ) -> Result<MFAToken?, Error> {
      environment
        .keychain
        .loadFirst(matching: .accountMFATokenQuery(for: accountID))
    }

    @StorageAccessActor func deleteAccountMFAToken(
      accountID: Account.LocalID
    ) -> Result<Void, Error> {
      environment
        .keychain
        .delete(matching: .accountMFATokenQuery(for: accountID))
    }

    @StorageAccessActor func loadAccountProfile(
      for accountID: Account.LocalID
    ) -> Result<AccountProfile, Error> {
      return environment
        .keychain
        .loadFirst(AccountProfile.self, matching: .accountProfileQuery(for: accountID))
        .flatMap { profile in
          if let profile: AccountProfile = profile {
            return .success(profile)
          }
          else {
            return .failure(
              AccountProfileDataMissing
                .error("Failed to load account profile")
                .recording(accountID, for: "accountID")
            )
          }
        }
    }

    @StorageAccessActor func update(
      accountProfile: AccountProfile
    ) -> Result<Void, Error> {
      let accountsList: Array<Account.LocalID> = environment
        .preferences
        .load(Array<Account.LocalID>.self, for: .accountsList)
      guard accountsList.contains(accountProfile.accountID)
      else {
        return .failure(
          AccountDataMissing
            .error("Failed to update account profile")
            .recording(accountProfile.accountID, for: "accountID")
        )
      }
      return environment
        .keychain
        .save(accountProfile, for: .accountProfileQuery(for: accountProfile.accountID))
        .map {
          updatedAccountIDSubject.send(accountProfile.accountID)
        }
        .mapError { error -> Error in
          return
            error
            .asTheError()
            .recording(accountProfile.accountID, for: "accountID")
        }
    }

    @StorageAccessActor func deleteAccount(withID accountID: Account.LocalID) {
      // There is a risk of calling this method with valid session for deleted account,
      // we should assert on that or make it impossible")

      // data integrity check performs cleanup in case of partial success
      defer {
        ensureDataIntegrity().forceSuccess("Data integrity protection")
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

      var results: Array<Result<Void, Error>> = .init()
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
          .delete(matching: .accountMFATokenQuery(for: accountID))
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
        Result {
          try _databaseURL(
            forAccountWithID: accountID
          )
        }
        .flatMap(files.deleteFile)
      )

      do {
        #warning("TODO: Consider propagating errors outside of this function")
        try results.forEach { try $0.get() }
      }
      catch {
        diagnostics.diagnosticLog("Failed to properly delete account")
        diagnostics.log(
          error,
          info: .message("Failed to properly delete account")
        )
      }
    }

    // swift-format-ignore: NoLeadingUnderscores
    @StorageAccessActor func _databaseURL(
      forAccountWithID accountID: Account.LocalID
    ) throws -> URL {
      try files
        .applicationDataDirectory()
        .map { dir in
          dir
            .appendingPathComponent(accountID.rawValue)
            .appendingPathExtension("sqlite")
        }
        .mapError { error in
          DatabaseIssue.error(
            underlyingError:
              error
              .asUnidentified()
              .pushing(.message("Cannot access database file"))
          )
        }
        .get()
    }

    @StorageAccessActor func prepareDatabaseConnection(
      forAccountWithID accountID: Account.LocalID,
      key: String
    ) throws -> SQLiteConnection {
      let databaseURL: URL = try _databaseURL(forAccountWithID: accountID)

      let databaseConnection: SQLiteConnection
      do {
        databaseConnection =
          try database
          .openConnection(
            databaseURL.absoluteString,
            key,
            SQLiteMigration.allCases,
            SQLiteOpeningOperations.all
          )
      }
      catch {
        diagnostics.diagnosticLog("Failed to open database for accountID, cleaning up...")
        _ = files.deleteFile(databaseURL)
        // single retry after deleting previous database, fail if it fails
        databaseConnection =
          try database
          .openConnection(
            databaseURL.absoluteString,
            key,
            SQLiteMigration.allCases,
            SQLiteOpeningOperations.all
          )
      }

      return databaseConnection
    }

    @StorageAccessActor func storeServerFingerprint(accountID: Account.LocalID, fingerprint: Fingerprint) -> Result<
      Void, Error
    > {
      keychain
        .save(fingerprint, for: .serverFingerprintQuery(for: accountID))
    }

    @StorageAccessActor func loadServerFingerprint(accountID: Account.LocalID) -> Result<Fingerprint?, Error> {
      keychain
        .loadFirst(Fingerprint.self, matching: .serverFingerprintQuery(for: accountID))
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
      storeAccountMFAToken: storeAccountMFAToken(accountID:token:),
      loadAccountMFAToken: loadAccountMFAToken(accountID:),
      deleteAccountMFAToken: deleteAccountMFAToken(accountID:),
      loadAccountProfile: loadAccountProfile(for:),
      updateAccountProfile: update(accountProfile:),
      deleteAccount: deleteAccount(withID:),
      updatedAccountIDsPublisher: updatedAccountIDSubject.eraseToAnyPublisher,
      accountDatabaseConnection: prepareDatabaseConnection(forAccountWithID:key:),
      storeServerFingerprint: storeServerFingerprint(accountID:fingerprint:),
      loadServerFingerprint: loadServerFingerprint(accountID:)
    )
  }

  #if DEBUG
  internal static var placeholder: Self {
    Self(
      verifyDataIntegrity: unimplemented("You have to provide mocks for used methods"),
      loadAccounts: unimplemented("You have to provide mocks for used methods"),
      loadLastUsedAccount: unimplemented("You have to provide mocks for used methods"),
      storeLastUsedAccount: unimplemented("You have to provide mocks for used methods"),
      storeAccount: unimplemented("You have to provide mocks for used methods"),
      loadAccountPrivateKey: unimplemented("You have to provide mocks for used methods"),
      storeAccountPassphrase: unimplemented("You have to provide mocks for used methods"),
      loadAccountPassphrase: unimplemented("You have to provide mocks for used methods"),
      deleteAccountPassphrase: unimplemented("You have to provide mocks for used methods"),
      storeAccountMFAToken: unimplemented("You have to provide mocks for used methods"),
      loadAccountMFAToken: unimplemented("You have to provide mocks for used methods"),
      deleteAccountMFAToken: unimplemented("You have to provide mocks for used methods"),
      loadAccountProfile: unimplemented("You have to provide mocks for used methods"),
      updateAccountProfile: unimplemented("You have to provide mocks for used methods"),
      deleteAccount: unimplemented("You have to provide mocks for used methods"),
      updatedAccountIDsPublisher: unimplemented("You have to provide mocks for used methods"),
      accountDatabaseConnection: unimplemented("You have to provide mocks for used methods"),
      storeServerFingerprint: unimplemented("You have to provide mocks for used methods"),
      loadServerFingerprint: unimplemented("You have to provide mocks for used methods")
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

  fileprivate static func accountMFATokenQuery(
    for identifier: Account.LocalID? = nil
  ) -> Self {
    assert(
      identifier == nil || !(identifier?.rawValue.isEmpty ?? false),
      "Cannot use empty account identifiers for database operations"
    )
    return Self(
      key: "accountMFAToken",
      tag: (identifier?.rawValue).map(KeychainQuery.Tag.init(rawValue:)),
      requiresBiometrics: false
    )
  }

  fileprivate static func serverFingerprintQuery(
    for identifier: Account.LocalID? = nil
  ) -> Self {
    assert(
      identifier == nil || !(identifier?.rawValue.isEmpty ?? false),
      "Cannot use empty account identifiers for database operations"
    )
    return Self(
      key: "serverFingerprint",
      tag: (identifier?.rawValue).map(KeychainQuery.Tag.init(rawValue:)),
      requiresBiometrics: false
    )
  }
}
