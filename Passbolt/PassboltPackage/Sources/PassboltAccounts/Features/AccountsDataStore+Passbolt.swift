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

import Accounts
import OSFeatures

import struct Foundation.Data
import struct Foundation.URL

// MARK: - Implementation (Legacy)

extension AccountsDataStore {

  @MainActor fileprivate static func load(
    features: Features,
    cancellables: Cancellables
  ) throws -> Self {
    let keychain: OSKeychain = features.instance()
    let files: OSFiles = features.instance()
    let preferences: OSPreferences = features.instance()

    @Sendable func forceDelete(matching query: OSKeychainQuery) {
      Diagnostics.debugLog("Purging data for \(query.key)")
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

    @Sendable func ensureDataIntegrity() throws {
      Diagnostics.log(diagnostic: "Verifying data integrity...")
      defer {
        Diagnostics.log(diagnostic: "...data integrity verification finished")
      }

      // storedAccountsList - user defaults control list
      let storedAccountsList: Array<Account.LocalID> =
        preferences
        .load(Array<Account.LocalID>.self, for: .accountsList)
      Diagnostics.debugLog("Stored accounts list: \(storedAccountsList)")

      // storedAccounts - keychain accounts
      let storedAccounts: Array<Account.LocalID>
      switch keychain.loadAll(Account.self, matching: .accountsQuery) {
      case let .success(accounts):
        storedAccounts = accounts.map(\.localID)
      case let .failure(error):
        Diagnostics.log(
          diagnostic:
            "Failed to load accounts data, recovering with empty list"
        )
        Diagnostics.log(error: error)
        forceDelete(matching: .accountsQuery)
        storedAccounts = .init()
      }
      Diagnostics.debugLog("Stored accounts: \(storedAccounts)")

      // storedAccountProfiles - keychain accounts metadata
      let storedAccountsProfiles: Array<Account.LocalID>
      switch keychain.loadAll(AccountProfile.self, matching: .accountsProfilesQuery) {
      case let .success(accounts):
        storedAccountsProfiles = accounts.map(\.accountID)
      case let .failure(error):
        Diagnostics.log(
          diagnostic:
            "Failed to load account profiles data, recovering with empty list"
        )
        Diagnostics.log(error: error)
        forceDelete(matching: .accountsProfilesQuery)
        storedAccountsProfiles = .init()
      }
      Diagnostics.debugLog("Stored account profiles: \(storedAccountsProfiles)")

      // storedAccountMFATokens - keychain accounts mfa tokens
      let storedAccountMFATokens: Array<Account.LocalID>
      switch keychain.loadMeta(matching: .accountMFATokenQuery()) {
      case let .success(accounts):
        storedAccountMFATokens =
          accounts
          .compactMap(\.tag?.rawValue)
          .map(Account.LocalID.init(rawValue:))
      case let .failure(error):
        Diagnostics.log(
          diagnostic:
            "Failed to load account mfa tokens data, recovering with empty list"
        )
        Diagnostics.log(error: error)
        forceDelete(matching: .accountsProfilesQuery)
        storedAccountMFATokens = .init()
      }
      Diagnostics.debugLog("Stored account mfa tokens: \(storedAccountMFATokens)")

      // storedServerFingerprints - keychain accounts server fingerprints
      let storedServerFingerprints: Array<Account.LocalID>
      switch keychain.loadMeta(matching: .serverFingerprintQuery()) {
      case let .success(accounts):
        storedServerFingerprints =
          accounts
          .compactMap(\.tag?.rawValue)
          .map(Account.LocalID.init(rawValue:))
      case let .failure(error):
        Diagnostics.log(
          diagnostic:
            "Failed to load account server fingerprint data, recovering with empty list"
        )
        Diagnostics.log(error: error)
        forceDelete(matching: .accountsProfilesQuery)
        storedServerFingerprints = .init()
      }
      Diagnostics.debugLog("Stored server fingerprints: \(storedServerFingerprints)")

      // storedAccountKeys - keychain accounts private keys
      let storedAccountKeys: Array<Account.LocalID>
      let armoredKeysQuery: OSKeychainQuery = .init(
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
        Diagnostics.log(
          diagnostic:
            "Failed to load armored keys metadata, recovering with empty list"
        )
        Diagnostics.log(error: error)
        forceDelete(matching: armoredKeysQuery)
        storedAccountKeys = .init()
      }
      Diagnostics.debugLog("Stored account keys: \(storedAccountKeys)")

      let updatedAccountsList: Array<Account.LocalID> =
        storedAccountsList
        .filter {
          storedAccounts.contains($0)
            && storedAccountsProfiles.contains($0)
            && storedAccountKeys.contains($0)
        }
      preferences
        .save(updatedAccountsList, for: .accountsList)
      Diagnostics.debugLog("Updated accounts list: \(updatedAccountsList)")

      let accountsToRemove: Array<Account.LocalID> =
        storedAccounts
        .filter { !updatedAccountsList.contains($0) }

      for accountID in accountsToRemove {
        switch keychain.delete(matching: .accountQuery(for: accountID)) {
        case .success:
          continue
        case let .failure(error):
          Diagnostics.log(diagnostic: "Failed to delete account")
          throw
            error
            .asTheError()
            .pushing(.message("Failed to delete account"))
            .recording(accountID, for: "accountID")
        }
      }
      Diagnostics.debugLog("Deleted accounts: \(accountsToRemove)")

      let accountProfilesToRemove: Array<Account.LocalID> =
        storedAccountsProfiles
        .filter { !updatedAccountsList.contains($0) }

      for accountID in accountProfilesToRemove {
        switch keychain.delete(matching: .accountProfileQuery(for: accountID)) {
        case .success:
          continue
        case let .failure(error):
          Diagnostics.log(diagnostic: "Failed to delete account profile")
          throw
            error
            .asTheError()
            .pushing(.message("Failed to delete account profile"))
            .recording(accountID, for: "accountID")
        }
      }
      Diagnostics.debugLog("Deleted account profiles: \(accountProfilesToRemove)")

      let mfaTokensToRemove: Array<Account.LocalID> =
        storedAccountMFATokens
        .filter { !updatedAccountsList.contains($0) }

      for accountID in mfaTokensToRemove {
        switch keychain.delete(matching: .accountMFATokenQuery(for: accountID)) {
        case .success:
          continue
        case let .failure(error):
          Diagnostics.log(
            diagnostic:
              "Failed to delete account mfa token"
          )
          throw error
        }
      }
      Diagnostics.debugLog("Deleted account mfa tokens: \(mfaTokensToRemove)")

      let serverFingerprintsToRemove: Array<Account.LocalID> =
        storedServerFingerprints
        .filter { !updatedAccountsList.contains($0) }

      for accountID in serverFingerprintsToRemove {
        switch keychain.delete(matching: .serverFingerprintQuery(for: accountID)) {
        case .success:
          continue
        case let .failure(error):
          Diagnostics.log(diagnostic: "Failed to delete server fingerprint")
          throw
            error
            .asTheError()
            .pushing(.message("Failed to delete server fingerpring"))
            .recording(accountID, for: "accountID")
        }
      }
      Diagnostics.debugLog("Deleted server fingerprints: \(serverFingerprintsToRemove)")

      let keysToRemove: Array<Account.LocalID> =
        storedAccountKeys
        .filter { !updatedAccountsList.contains($0) }

      for accountID in keysToRemove {
        switch keychain.delete(matching: .accountArmoredKeyQuery(for: accountID)) {
        case .success:
          continue
        case let .failure(error):
          Diagnostics.log(diagnostic: "Failed to delete account private key")
          throw
            error
            .asTheError()
            .pushing(.message("Failed to delete account private key"))
            .recording(accountID, for: "accountID")
        }
      }
      Diagnostics.debugLog("Deleted account private keys: \(keysToRemove)")

      if updatedAccountsList.isEmpty {
        Diagnostics.debugLog("Deleting stored passphrases")
        switch keychain.delete(matching: .accountPassphraseDeletionQuery()) {
        case .success:
          break
        case let .failure(error):
          Diagnostics.log(diagnostic: "Failed to delete stored passphrases")
          throw
            error
            .asTheError()
            .pushing(.message("Failed to delete stored passphrases"))
        }
      }
      else {
        /* We can't delete passphrases selectively due to biometrics */
      }

      let applicationDataDirectory: URL = try files.applicationDataDirectory()

      let storedDatabases: Array<Account.LocalID> =
        try files
        .contentsOfDirectory(applicationDataDirectory)
        .filter { fileName in
          fileName.hasSuffix(".sqlite")
        }
        .map { fileName -> Account.LocalID in
          var fileName = fileName
          fileName.removeLast(".sqlite".count)
          return .init(rawValue: fileName)
        }

      Diagnostics.debugLog("Stored databases: \(storedDatabases)")

      let databasesToRemove: Array<Account.LocalID> =
        storedDatabases
        .filter { !updatedAccountsList.contains($0) }

      for accountID in databasesToRemove {
        try files.deleteFile(
          files
            .applicationDataDirectory()
            .appendingPathComponent(accountID.rawValue)
            .appendingPathExtension("sqlite")
        )
      }

      Diagnostics.debugLog("Deleted account databases: \(databasesToRemove)")

      let deleted: Set<Account.LocalID> = .init(
        accountsToRemove + accountProfilesToRemove + keysToRemove + databasesToRemove
      )

      Diagnostics.debugLog("Deleted accounts: \(deleted)")
    }

    @Sendable func loadAccounts() -> Array<Account> {
      let keychainLoadResult: Result<Array<Account>, Error> =
        keychain
        .loadAll(
          Account.self,
          matching: .accountsQuery
        )
      switch keychainLoadResult {
      case let .success(accounts):
        return accounts
      case let .failure(error):
        Diagnostics
          .log(
            error: error,
            info: .message("Failed to load accounts")
          )
        return []
      }
    }

    @Sendable func loadLastUsedAccount() -> Account? {
      return
        preferences
        .load(
          Account.LocalID.self,
          for: .lastUsedAccount
        )
        .flatMap { accountID in
          guard !accountID.rawValue.isEmpty else { return .none }
          let keychainResult: Result<Account?, Error> =
            keychain
            .loadFirst(
              Account.self,
              matching: .accountQuery(for: accountID)
            )
          switch keychainResult {
          case let .success(account):
            return account
          case let .failure(error):
            Diagnostics
              .log(
                error: error,
                info: .message("Failed to load last used account")
              )
            return nil
          }
        }
    }

    @Sendable func storeLastUsedAccount(_ accountID: Account.LocalID) {
      preferences.save(accountID, for: .lastUsedAccount)
    }

    @Sendable func store(
      account: Account,
      profile: AccountProfile,
      armoredKey: ArmoredPGPPrivateKey
    ) throws {
      // data integrity check performs cleanup in case of partial success
      defer {
        do {
          try ensureDataIntegrity()
        }
        catch {
          error
            .asTheError()
            .asFatalError(message: "Data integrity protection")
        }
      }

      try keychain
        .save(profile, for: .accountProfileQuery(for: account.localID))
        .get()
      try keychain
        .save(account, for: .accountQuery(for: account.localID))
        .get()
      try keychain
        .save(
          armoredKey,
          for: .accountArmoredKeyQuery(for: account.localID)
        )
        .get()
      var accountIdentifiers: Array<Account.LocalID> =
        preferences
        .load(Array<Account.LocalID>.self, for: .accountsList)
      accountIdentifiers.append(account.localID)
      preferences.save(accountIdentifiers, for: .accountsList)
      preferences.save(account.localID, for: .lastUsedAccount)
      // workaround to ensure that AccountInitialSetup is set up properly for new account
      // it should be changed when refactoring AccountsDataStore
      preferences.save(AccountInitialSetup.SetupElement.allCases, for: "unfinishedSetup-\(account.localID)")
    }

    @Sendable func loadAccountPrivateKey(
      for accountID: Account.LocalID
    ) throws -> ArmoredPGPPrivateKey {
      guard
        let key: ArmoredPGPPrivateKey =
          try keychain
          .loadFirst(
            ArmoredPGPPrivateKey.self,
            matching: .accountArmoredKeyQuery(for: accountID)
          )
          .get()
      else {
        throw
          AccountPrivateKeyMissing
          .error()
          .recording(accountID, for: "accountID")
      }

      return key
    }

    @Sendable nonisolated func isPassphraseStored(
      for accountID: Account.LocalID
    ) -> Bool {
      keychain
        .checkIfExists(
          matching: .accountPassphraseQuery(for: accountID)
        )
    }

    @Sendable nonisolated func storePassphrase(
      for accountID: Account.LocalID,
      passphrase: Passphrase
    ) throws {
      try keychain
        .save(
          passphrase,
          for: .accountPassphraseQuery(for: accountID)
        )
        .get()
    }

    @Sendable nonisolated func loadPassphrase(
      for accountID: Account.LocalID
    ) throws -> Passphrase {
      // in case of failure we should change flag biometricsEnabled to false and propagate change
      do {
        guard
          let passphrase: Passphrase =
            try keychain
            .loadFirst(
              Passphrase.self,
              matching: .accountPassphraseQuery(for: accountID)
            )
            .get()
        else {
          throw
            AccountBiometryDataChanged
            .error()
            .pushing(.message("Failed to load account passphrase"))
            .recording(accountID, for: "accountID")
        }
        return passphrase
      }
      catch let error as AccountBiometryDataChanged {
        throw error
      }
      catch {
        throw
          error
          .asTheError()
          .pushing(.message("Failed to load account passphrase"))
          .recording(accountID, for: "accountID")
      }
    }

    @Sendable nonisolated func deletePassphrase(
      for accountID: Account.LocalID
    ) throws {
      try keychain
        .delete(matching: .accountPassphraseDeleteQuery(for: accountID))
        .get()
    }

    @Sendable func storeAccountMFAToken(
      accountID: Account.LocalID,
      token: String
    ) throws {
      try keychain
        .save(token, for: .accountMFATokenQuery(for: accountID))
        .get()
    }

    @Sendable func loadAccountMFAToken(
      accountID: Account.LocalID
    ) throws -> String? {
      try keychain
        .loadFirst(matching: .accountMFATokenQuery(for: accountID))
        .get()
    }

    @Sendable func deleteAccountMFAToken(
      accountID: Account.LocalID
    ) throws {
      try keychain
        .delete(matching: .accountMFATokenQuery(for: accountID))
        .get()
    }

    @Sendable func loadAccountProfile(
      for accountID: Account.LocalID
    ) throws -> AccountProfile {
      guard
        let profile: AccountProfile =
          try keychain
          .loadFirst(AccountProfile.self, matching: .accountProfileQuery(for: accountID))
          .get()
      else {
        throw
          AccountProfileDataMissing
          .error("Failed to load account profile")
          .recording(accountID, for: "accountID")
      }

      return profile
    }

    @Sendable func update(
      accountProfile: AccountProfile
    ) throws {
      let accountsList: Array<Account.LocalID> =
        preferences
        .load(Array<Account.LocalID>.self, for: .accountsList)
      guard accountsList.contains(accountProfile.accountID)
      else {
        throw
          AccountDataMissing
          .error("Failed to update account profile")
          .recording(accountProfile.accountID, for: "accountID")
      }
      try keychain
        .save(accountProfile, for: .accountProfileQuery(for: accountProfile.accountID))
        .get()
    }

    @Sendable func deleteAccount(withID accountID: Account.LocalID) {
      // There is a risk of calling this method with valid session for deleted account,
      // we should assert on that or make it impossible")

      // data integrity check performs cleanup in case of partial success
      defer {
        do {
          try ensureDataIntegrity()
        }
        catch {
          error
            .asTheError()
            .asFatalError(message: "Data integrity protection")
        }
      }

      var accountIdentifiers: Array<Account.LocalID> =
        preferences
        .load(Array<Account.LocalID>.self, for: .accountsList)

      accountIdentifiers.removeAll(where: { $0 == accountID })
      preferences.save(accountIdentifiers, for: .accountsList)
      let lastUsedAccount: Account.LocalID? =
        preferences
        .load(
          Account.LocalID.self,
          for: .lastUsedAccount
        )

      if lastUsedAccount == accountID {
        preferences
          .deleteValue(
            for: .lastUsedAccount
          )
      }
      else {
        /* */
      }
      do {
        try keychain
          .delete(matching: .accountPassphraseQuery(for: accountID))
          .get()

        try keychain
          .delete(matching: .accountArmoredKeyQuery(for: accountID))
          .get()

        try keychain
          .delete(matching: .accountMFATokenQuery(for: accountID))
          .get()

        try keychain
          .delete(matching: .accountQuery(for: accountID))
          .get()

        try keychain
          .delete(matching: .accountProfileQuery(for: accountID))
          .get()

        _ = try files.deleteFile(
          _databaseURL(
            forAccountWithID: accountID
          )
        )

        #warning("TODO: Consider propagating errors outside of this function")
      }
      catch {
        Diagnostics.log(diagnostic: "Failed to properly delete account")
        Diagnostics.log(
          error: error,
          info: .message("Failed to properly delete account")
        )
      }
    }

    // swift-format-ignore: NoLeadingUnderscores
    @Sendable func _databaseURL(
      forAccountWithID accountID: Account.LocalID
    ) throws -> URL {
      try files
        .applicationDataDirectory().appendingPathComponent(accountID.rawValue)
        .appendingPathExtension("sqlite")
    }

    @Sendable func storeServerFingerprint(
      accountID: Account.LocalID,
      fingerprint: Fingerprint
    ) throws {
      try keychain
        .save(fingerprint, for: .serverFingerprintQuery(for: accountID))
        .get()
    }

    @Sendable func loadServerFingerprint(accountID: Account.LocalID) throws -> Fingerprint? {
      try keychain
        .loadFirst(Fingerprint.self, matching: .serverFingerprintQuery(for: accountID))
        .get()
    }

    return Self(
      verifyDataIntegrity: ensureDataIntegrity,
      loadAccounts: loadAccounts,
      loadLastUsedAccount: loadLastUsedAccount,
      storeLastUsedAccount: storeLastUsedAccount(_:),
      storeAccount: store(account:profile:armoredKey:),
      loadAccountPrivateKey: loadAccountPrivateKey(for:),
      isAccountPassphraseStored: isPassphraseStored(for:),
      storeAccountPassphrase: storePassphrase(for:passphrase:),
      loadAccountPassphrase: loadPassphrase(for:),
      deleteAccountPassphrase: deletePassphrase(for:),
      storeAccountMFAToken: storeAccountMFAToken(accountID:token:),
      loadAccountMFAToken: loadAccountMFAToken(accountID:),
      deleteAccountMFAToken: deleteAccountMFAToken(accountID:),
      loadAccountProfile: loadAccountProfile(for:),
      updateAccountProfile: update(accountProfile:),
      deleteAccount: deleteAccount(withID:),
      storeServerFingerprint: storeServerFingerprint(accountID:fingerprint:),
      loadServerFingerprint: loadServerFingerprint(accountID:)
    )
  }
}

extension OSPreferences.Key {

  fileprivate static var accountsList: Self { "accountsList" }
  fileprivate static var lastUsedAccount: Self { "lastUsedAccount" }
}

extension OSKeychainQuery {

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
      tag: (identifier?.rawValue).map(OSKeychainQuery.Tag.init(rawValue:)),
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
      tag: (identifier?.rawValue).map(OSKeychainQuery.Tag.init(rawValue:)),
      requiresBiometrics: false
    )
  }
}

extension FeaturesRegistry {

  public mutating func usePassboltAccountsDataStore() {
    self.use(
      .lazyLoaded(
        AccountsDataStore.self,
        load: AccountsDataStore.load(features:cancellables:)
      )
    )
  }
}
