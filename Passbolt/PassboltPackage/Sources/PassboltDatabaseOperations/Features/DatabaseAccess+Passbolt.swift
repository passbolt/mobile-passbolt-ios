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

import Commons
import Database
import DatabaseOperations
import OSFeatures

import struct Foundation.Data
import struct Foundation.URL

// MARK: - Implementation

extension DatabaseAccess {

  @MainActor fileprivate static func load(
    features: Features
  ) throws -> Self {

    let osFiles: OSFiles = features.instance()
    let keychain: OSKeychain = features.instance()
    let randomness: OSRandomness = features.instance()

    /// Length of the raw database key, in bytes.
    let databaseKeyByteCount: Int = 32

    @Sendable
    nonisolated func databaseLocation(
      for accountID: Account.LocalID
    ) throws -> URL {
      do {
        let databaseURL: URL =
          try osFiles
          .applicationDataDirectory()
          .appendingPathComponent(accountID.rawValue)
          .appendingPathExtension("sqlite")
        return databaseURL
      }
      catch {
        throw DatabaseIssue.error(
          underlyingError:
            error
            .asUnidentified()
            .pushing(.message("Cannot access database file"))
        )
      }
    }

    /// The database file plus the WAL sidecar files SQLite keeps next to it.
    /// All three have to be removed together — leaving `-wal`/`-shm` behind lets a stale
    /// journal be replayed into a freshly created database.
    @Sendable
    nonisolated func databaseFileLocations(
      for accountID: Account.LocalID
    ) throws -> Array<URL> {
      let databaseURL: URL = try databaseLocation(for: accountID)
      let directoryURL: URL = databaseURL.deletingLastPathComponent()
      let fileName: String = databaseURL.lastPathComponent
      return [
        databaseURL,
        directoryURL.appendingPathComponent(fileName + "-wal"),
        directoryURL.appendingPathComponent(fileName + "-shm"),
      ]
    }

    @Sendable
    nonisolated func deleteDatabaseFiles(
      for accountID: Account.LocalID
    ) throws {
      for location: URL in try databaseFileLocations(for: accountID) {
        try osFiles.deleteFile(location)
      }
    }

    /// Keeps the database and its WAL sidecars out of device backups and raises their data
    /// protection class. Called after every open, because SQLite recreates `-wal` / `-shm`.
    @Sendable
    nonisolated func protectDatabaseFiles(
      for accountID: Account.LocalID
    ) {
      do {
        for location: URL in try databaseFileLocations(for: accountID) {
          try osFiles.protectFile(location)
        }
      }
      catch {
        // Protection is defense in depth - failing to apply it must not deny access to the data.
        error.logged(
          info: .message("Failed to apply database file protection")
        )
      }
    }

    /// Fresh 256 bit database key taken from the system random number generator.
    @Sendable
    nonisolated func generateDatabaseKey() -> Data {
      var generator: OSRandomness = randomness
      let keyBytes: Array<UInt8> = (0 ..< databaseKeyByteCount)
        .map { _ in
          UInt8.random(in: UInt8.min ... UInt8.max, using: &generator)
        }
      return Data(keyBytes)
    }

    /// Returns `nil` only when there is no usable key stored. A keychain failure is
    /// rethrown rather than reported as "no key": treating it as missing would send an already
    /// migrated database down the legacy path and end in a needless wipe.
    @Sendable
    nonisolated func storedDatabaseKey(
      for accountID: Account.LocalID
    ) throws -> Data? {
      switch keychain
        .loadFirst(
          String.self,
          matching: .accountDatabaseKeyQuery(forAccountWithID: accountID.rawValue)
        )
      {
      case .success(.some(let hexKey)):
        let keyData: Data = .init(hexString: hexKey)
        guard keyData.count == databaseKeyByteCount
        else {
          // Truncated or corrupted entry - treat it as missing, which provisions a fresh key and
          // takes the legacy open path; the database is only recreated if that open fails too.
          //
          // Logged through the release logger rather than `Diagnostics.debug`, which compiles
          // away outside of DEBUG: the fresh key overwrites the entry shared with the other
          // container, which then rebuilds its cache from the server. That has to leave a trace.
          Diagnostics.logger.error("Stored database key has unexpected length, treating it as missing")
          return .none
        }
        return keyData

      case .success(.none):
        return .none

      case .failure(let error):
        throw
          error
          .asTheError()
          .pushing(.message("Failed to load database key"))
      }
    }

    @Sendable
    nonisolated func storeDatabaseKey(
      _ key: Data,
      for accountID: Account.LocalID
    ) throws {
      try keychain
        .save(
          key.bytesToHexString(uppercased: false),
          for: .accountDatabaseKeyQuery(forAccountWithID: accountID.rawValue)
        )
        .get()
    }

    @Sendable
    nonisolated func deleteDatabaseKey(
      for accountID: Account.LocalID
    ) throws {
      try keychain
        .delete(matching: .accountDatabaseKeyQuery(forAccountWithID: accountID.rawValue))
        .get()
    }

    @Sendable
    nonisolated func newConnection(
      _ location: URL,
      key: SQLiteConnectionKey,
      rekeyTo newKey: SQLiteConnectionKey? = .none
    ) throws -> SQLiteConnection {
      try SQLiteConnection
        .open(
          at: location.absoluteString,
          key: key,
          rekeyTo: newKey,
          options: SQLITE_OPEN_CREATE
            | SQLITE_OPEN_READWRITE
            | SQLITE_OPEN_WAL
            | SQLITE_OPEN_PRIVATECACHE,
          migrations: SQLiteMigration.allCases,
          openingOperations: SQLiteOpeningOperations.all
        )
    }

    /// Drops whatever is on disk and creates an empty database under the already stored `key`.
    /// The database only caches data that can be fetched again from the server.
    ///
    /// Reuses the stored key instead of rolling a new one: the application and the AutoFill
    /// extension have separate database files but share a single keychain entry, so replacing
    /// the key here would make the other container unable to open its own file.
    @Sendable
    nonisolated func recreateDatabase(
      _ accountID: Account.LocalID,
      at location: URL,
      keepingKey key: Data
    ) throws -> SQLiteConnection {
      try deleteDatabaseFiles(for: accountID)
      let connection: SQLiteConnection = try newConnection(location, key: .raw(key))
      protectDatabaseFiles(for: accountID)
      return connection
    }

    /// Key this container has to use for the account, provisioning one when there is none yet.
    ///
    /// Always called before anything touches the database file, and deliberately outside of the
    /// recovery in `openConnection`: a keychain failure has to surface as a failure to open,
    /// never as a reason to delete the data.
    @Sendable
    nonisolated func provisionDatabaseKey(
      for accountID: Account.LocalID,
      storedKey: Data?
    ) throws -> Data {
      if let storedKey: Data = storedKey {
        return storedKey
      }
      else {
        // Stored before the database is created or rekeyed, never after: a keychain write
        // failing once the file is already re-encrypted would leave a database nobody holds
        // the key to.
        //
        // The application and the AutoFill extension write to the very same keychain entry, so
        // two containers provisioning a key at the same moment end in last writer wins - the
        // keychain save overwrites unconditionally. The loser finds its own file unreadable with
        // the stored key on the next open and migrates or recreates it; the database only ever
        // caches data that can be fetched again from the server, so that costs a rebuild, not
        // the data. Reading the entry back here would not detect the race, only hide it.
        let generatedKey: Data = generateDatabaseKey()
        try storeDatabaseKey(generatedKey, for: accountID)
        return generatedKey
      }
    }

    @Sendable
    nonisolated func openConnection(
      _ accountID: Account.LocalID,
      passphraseDerivedKey: DatabaseKey
    ) throws -> SQLiteConnection {
      let location: URL = try databaseLocation(for: accountID)
      // Both deliberately outside of the recovery below - a keychain failure must not wipe data.
      let storedKey: Data? = try storedDatabaseKey(for: accountID)
      let databaseKey: Data = try provisionDatabaseKey(for: accountID, storedKey: storedKey)

      let databaseConnection: SQLiteConnection
      do {
        do {
          // Attempt to open database with key from Keychain
          databaseConnection = try newConnection(location, key: .raw(databaseKey))
        }
        catch let error where error.isDatabaseKeyIssue {
          // The file is there but the random key does not open it, so it was written by a build
          // that keyed it with the passphrase derived one. Migrate it in place.
          error.logged(
            info: .message("Database not readable with the stored key, trying the legacy one")
          )
          databaseConnection = try newConnection(
            location,
            key: .passphraseDerived(passphraseDerivedKey.rawValue),
            rekeyTo: .raw(databaseKey)
          )
        }
      }
      catch let error where error.isDatabaseConnectionIssue {
        // The file could not be reached or read at all. Recreating cannot succeed here (the fresh open
        // would fail for the very same reason) and would throw away a database that is most
        // likely still perfectly good once the fault passes.
        throw
          error
          .asTheError()
          .pushing(.message("Failed to open database"))
      }
      catch {
        // What is left says the database itself is unusable: neither key decrypts it, or it is
        // corrupted, or a migration could not be applied.
        error.logged(
          info: .message("Failed to open database, cleaning up...")
        )
        // single retry after deleting previous database, fail if it fails
        return try recreateDatabase(accountID, at: location, keepingKey: databaseKey)
      }

      protectDatabaseFiles(for: accountID)
      return databaseConnection
    }

    @Sendable
    nonisolated func delete(
      _ accountID: Account.LocalID
    ) throws {
      try deleteDatabaseFiles(for: accountID)
      try deleteDatabaseKey(for: accountID)
    }

    return Self(
      openConnection: openConnection(_:passphraseDerivedKey:),
      delete: delete(_:)
    )
  }
}

extension FeaturesRegistry {

  internal mutating func usePassboltDatabaseAccess() {
    self.use(
      .lazyLoaded(
        DatabaseAccess.self,
        load: DatabaseAccess
          .load(features:)
      )
    )
  }
}
