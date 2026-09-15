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
import Commons
import Database
import DatabaseOperations
import Features
import OSFeatures
import TestExtensions
import XCTest

import struct Foundation.Data
import class Foundation.FileManager
import class Foundation.JSONDecoder
import class Foundation.JSONEncoder
import struct Foundation.URL
import struct Foundation.UUID

@testable import PassboltDatabaseOperations

// Covers how the database key is provisioned: a random key per account kept in the keychain,
// a one time in place migration of databases still keyed with the passphrase derived key, and
// the rule that a keychain failure must never be answered by wiping the database.
// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class DatabaseAccessTests: LoadableFeatureTestCase<DatabaseAccess>, @unchecked Sendable {

  override class func testedImplementationRegister(
    _ registry: inout FeaturesRegistry
  ) {
    registry.usePassboltDatabaseAccess()
  }

  private nonisolated let mockKeychainStore: CriticalState<Dictionary<String, Data>> = .init(.init())
  private nonisolated let keychainFailure: CriticalState<Bool> = .init(false)
  private nonisolated let keychainSaveFailure: CriticalState<Bool> = .init(false)
  private nonisolated let deletedFiles: CriticalState<Array<URL>> = .init(.init())
  private nonisolated let protectedFiles: CriticalState<Array<URL>> = .init(.init())

  private var directoryURL: URL!

  private static let legacyKey: DatabaseKey = .init(rawValue: String(repeating: "a", count: 128))

  private nonisolated static func identifier(
    of query: OSKeychainQuery
  ) -> String {
    "\(query.key.rawValue)/\(query.tag?.rawValue ?? "")"
  }

  override func prepare() throws {
    // The space mirrors the real `Application Support` directory. It is what makes the
    // `absoluteString` handed to SQLite differ from the `URL.path` that `OSFiles` protects and
    // deletes by, so every test here runs against a path that would expose a mismatch.
    self.directoryURL =
      FileManager
      .default
      .temporaryDirectory
      .appendingPathComponent("Application Support \(UUID().uuidString)")
    try FileManager.default
      .createDirectory(
        at: self.directoryURL,
        withIntermediateDirectories: true
      )

    mockKeychainStore.set(.init())
    keychainFailure.set(false)
    keychainSaveFailure.set(false)
    deletedFiles.set(.init())
    protectedFiles.set(.init())

    patch(
      \OSKeychain.load,
      with: { [unowned self] query in
        if self.keychainFailure.get() {
          return .failure(MockIssue.error())
        }
        else if let data: Data = self.mockKeychainStore.get()[Self.identifier(of: query)] {
          return .success([data])
        }
        else {
          return .success([])
        }
      }
    )
    patch(
      \OSKeychain.save,
      with: { [unowned self] data, query in
        if self.keychainSaveFailure.get() {
          return .failure(MockIssue.error())
        }
        else {
          self.mockKeychainStore.access { store in
            store[Self.identifier(of: query)] = data
          }
          return .success
        }
      }
    )
    patch(
      \OSKeychain.delete,
      with: { [unowned self] query in
        self.mockKeychainStore.access { store in
          store[Self.identifier(of: query)] = .none
        }
        return .success
      }
    )
    let directoryURL: URL = self.directoryURL
    patch(
      \OSFiles.applicationDataDirectory,
      with: always(directoryURL)
    )
    patch(
      \OSFiles.deleteFile,
      with: { [unowned self] url in
        self.deletedFiles.access { deleted in
          deleted.append(url)
        }
        try? FileManager.default.removeItem(at: url)
      }
    )
    patch(
      \OSFiles.protectFile,
      with: { [unowned self] url in
        self.protectedFiles.access { protected in
          protected.append(url)
        }
      }
    )
    patch(
      \OSRandomness.nextValue,
      with: always(0x0123_4567_89ab_cdef)
    )
  }

  override func cleanup() throws {
    try? FileManager.default.removeItem(at: self.directoryURL)
    self.directoryURL = .none
  }

  /// Location built exactly the way `DatabaseAccess` builds it, including the `absoluteString`
  /// form it hands to SQLite - so a database prepared here is the one it will open.
  private func databasePath() -> String {
    self.databaseURL()
      .absoluteString
  }

  private func databaseURL() -> URL {
    self.directoryURL
      .appendingPathComponent(Account.mock_ada.localID.rawValue)
      .appendingPathExtension("sqlite")
  }

  private func createLegacyDatabase() throws {
    let connection: SQLiteConnection = try SQLiteConnection.open(
      at: databasePath(),
      key: .passphraseDerived(Self.legacyKey.rawValue)
    )
    try connection.execute(
      .statement("CREATE TABLE legacy_probe (id INTEGER PRIMARY KEY, value TEXT);")
    )
    try connection.execute(
      .statement("INSERT INTO legacy_probe (id, value) VALUES (?1, ?2);", arguments: 1, "kept")
    )
  }

  private func storedDatabaseKey() -> String? {
    let query: OSKeychainQuery = .accountDatabaseKeyQuery(
      forAccountWithID: Account.mock_ada.localID.rawValue
    )
    guard let data: Data = mockKeychainStore.get()[Self.identifier(of: query)]
    else { return .none }
    return
      try? JSONDecoder.default
      .decode(Dictionary<String, String>.self, from: data)["v"]
  }

  func test_openConnection_storesRandomKeyInKeychain_whenNoneStored() async throws {
    let databaseAccess: DatabaseAccess = try testedInstance()

    _ = try databaseAccess.openConnection(Account.mock_ada.localID, Self.legacyKey)

    // 32 bytes of key, hex encoded.
    XCTAssertEqual(storedDatabaseKey()?.count, 64)
  }

  func test_openConnection_putsFreshDatabaseOnStoredRandomKey() async throws {
    let databaseAccess: DatabaseAccess = try testedInstance()

    _ = try databaseAccess.openConnection(Account.mock_ada.localID, Self.legacyKey)

    let storedKey: String = try XCTUnwrap(storedDatabaseKey())
    // `migrations` has to be passed on both reopens. `SQLiteConnection.open` compares the
    // database's `user_version` against the number of migrations it was handed and rejects a
    // database that is ahead of it - so opening a fully migrated database with no migrations
    // throws "Invalid database schema version" whatever the key is, which would make both
    // assertions below pass or fail for a reason that has nothing to do with encryption.
    XCTAssertNoThrow(
      try SQLiteConnection.open(
        at: databasePath(),
        key: .raw(Data(hexString: storedKey)),
        migrations: SQLiteMigration.allCases
      )
    )
    XCTAssertThrowsError(
      try SQLiteConnection.open(
        at: databasePath(),
        key: .passphraseDerived(Self.legacyKey.rawValue),
        migrations: SQLiteMigration.allCases
      )
    ) { error in
      // Specifically the key, not the schema version check standing in for it.
      XCTAssertTrue(
        error.isDatabaseKeyIssue,
        "The database must be unreadable because of the key, got \(error)"
      )
    }
  }

  func test_openConnection_reusesStoredKey_onSecondOpen() async throws {
    let databaseAccess: DatabaseAccess = try testedInstance()

    _ = try databaseAccess.openConnection(Account.mock_ada.localID, Self.legacyKey)
    let firstKey: String? = storedDatabaseKey()
    _ = try databaseAccess.openConnection(Account.mock_ada.localID, Self.legacyKey)

    XCTAssertEqual(storedDatabaseKey(), firstKey)
  }

  func test_openConnection_migratesLegacyDatabase_keepingItsContents() async throws {
    try createLegacyDatabase()
    let databaseAccess: DatabaseAccess = try testedInstance()

    let connection: SQLiteConnection =
      try databaseAccess
      .openConnection(Account.mock_ada.localID, Self.legacyKey)
    let rows: Array<SQLiteRow> = try connection.fetch(
      .statement("SELECT value FROM legacy_probe WHERE id = 1;")
    )

    XCTAssertEqual(rows.first?.value, "kept")
    XCTAssertEqual(storedDatabaseKey()?.count, 64)
  }

  func test_openConnection_leavesDatabaseIntact_whenKeychainFails() async throws {
    try createLegacyDatabase()
    let databaseAccess: DatabaseAccess = try testedInstance()
    keychainFailure.set(true)

    XCTAssertThrowsError(
      try databaseAccess.openConnection(Account.mock_ada.localID, Self.legacyKey)
    )

    // A keychain outage must not be answered by dropping the only copy of the data.
    XCTAssertTrue(deletedFiles.get().isEmpty)
    keychainFailure.set(false)
    let connection: SQLiteConnection = try SQLiteConnection.open(
      at: databasePath(),
      key: .passphraseDerived(Self.legacyKey.rawValue)
    )
    let rows: Array<SQLiteRow> = try connection.fetch(
      .statement("SELECT value FROM legacy_probe WHERE id = 1;")
    )
    XCTAssertEqual(rows.first?.value, "kept")
  }

  func test_openConnection_leavesDatabaseIntact_whenKeychainWriteFails() async throws {
    try createLegacyDatabase()
    let databaseAccess: DatabaseAccess = try testedInstance()
    keychainSaveFailure.set(true)

    XCTAssertThrowsError(
      try databaseAccess.openConnection(Account.mock_ada.localID, Self.legacyKey)
    )

    // The key is stored before the database is rekeyed, so a failed write leaves the file
    // untouched - still readable with the legacy key, and still there to migrate next time.
    XCTAssertTrue(deletedFiles.get().isEmpty)
    keychainSaveFailure.set(false)
    let connection: SQLiteConnection = try SQLiteConnection.open(
      at: databasePath(),
      key: .passphraseDerived(Self.legacyKey.rawValue)
    )
    let rows: Array<SQLiteRow> = try connection.fetch(
      .statement("SELECT value FROM legacy_probe WHERE id = 1;")
    )
    XCTAssertEqual(rows.first?.value, "kept")
  }

  private func setStoredDatabaseKey(
    _ hexKey: String
  ) throws {
    let query: OSKeychainQuery = .accountDatabaseKeyQuery(
      forAccountWithID: Account.mock_ada.localID.rawValue
    )
    let data: Data = try JSONEncoder.default.encode(["v": hexKey])
    mockKeychainStore.access { store in
      store[Self.identifier(of: query)] = data
    }
  }

  func test_openConnection_migratesLegacyDatabase_ontoKeyStoredByAnotherContainer() async throws {
    // The application and the AutoFill extension have separate database files but one shared
    // keychain entry, so a container can find a key stored by the other one while its own file
    // is still keyed with the legacy passphrase derived key.
    try createLegacyDatabase()
    let otherContainerKey: String = String(repeating: "7e", count: 32)
    try setStoredDatabaseKey(otherContainerKey)
    let databaseAccess: DatabaseAccess = try testedInstance()

    let connection: SQLiteConnection =
      try databaseAccess
      .openConnection(Account.mock_ada.localID, Self.legacyKey)
    let rows: Array<SQLiteRow> = try connection.fetch(
      .statement("SELECT value FROM legacy_probe WHERE id = 1;")
    )

    XCTAssertEqual(rows.first?.value, "kept")
    XCTAssertTrue(deletedFiles.get().isEmpty)
    // Rolling a new key here would lock the other container out of its own database.
    XCTAssertEqual(storedDatabaseKey(), otherContainerKey)
  }

  func test_openConnection_replacesStoredKey_whenItHasUnexpectedLength() async throws {
    // A truncated entry cannot decrypt anything, so it is treated as missing and replaced.
    // This is the one branch that overwrites a key the other container may still be using, so
    // it has to end in the legacy migration - contents kept, nothing deleted - and in a stored
    // key of the right length, not in a wipe.
    try createLegacyDatabase()
    try setStoredDatabaseKey(String(repeating: "ab", count: 8))
    let databaseAccess: DatabaseAccess = try testedInstance()

    let connection: SQLiteConnection =
      try databaseAccess
      .openConnection(Account.mock_ada.localID, Self.legacyKey)
    let rows: Array<SQLiteRow> = try connection.fetch(
      .statement("SELECT value FROM legacy_probe WHERE id = 1;")
    )

    XCTAssertEqual(rows.first?.value, "kept")
    XCTAssertTrue(deletedFiles.get().isEmpty)
    XCTAssertEqual(storedDatabaseKey()?.count, 64)
  }

  func test_openConnection_createsDatabaseWhereOSFilesLooksForIt() async throws {
    // SQLite is handed the `absoluteString` form of the location while `OSFiles` protects and
    // deletes by `URL.path`. The two resolve to one and the same file only while the SQLCipher
    // build keeps URI handling on, and nothing in this repository pins that flag - so it is
    // pinned here. A build without it would leave the space in the directory name percent
    // encoded and put the database somewhere else, leaving every file protection and every
    // deletion silently pointed at nothing.
    let databaseAccess: DatabaseAccess = try testedInstance()

    _ = try databaseAccess.openConnection(Account.mock_ada.localID, Self.legacyKey)

    let expectedURL: URL =
      self.directoryURL
      .appendingPathComponent(Account.mock_ada.localID.rawValue)
      .appendingPathExtension("sqlite")
    XCTAssertTrue(
      FileManager.default.fileExists(atPath: expectedURL.path)
    )
  }

  func test_openConnection_protectsDatabaseAndItsSidecars() async throws {
    // Backup exclusion and the data protection class are the security half of this change, and
    // `protectDatabaseFiles` swallows its own failures on purpose - so without this assertion a
    // regression that stops protecting anything would leave no trace at all.
    let databaseAccess: DatabaseAccess = try testedInstance()

    _ = try databaseAccess.openConnection(Account.mock_ada.localID, Self.legacyKey)

    XCTAssertEqual(
      Set(protectedFiles.get().map(\.lastPathComponent)),
      [
        "\(Account.mock_ada.localID).sqlite",
        "\(Account.mock_ada.localID).sqlite-wal",
        "\(Account.mock_ada.localID).sqlite-shm",
      ]
    )
  }

  func test_openConnection_recreatesDatabase_whenFileIsNotADatabaseAtAll() async throws {
    let storedKey: String = String(repeating: "7e", count: 32)
    try setStoredDatabaseKey(storedKey)
    XCTAssertTrue(
      FileManager.default.createFile(
        atPath: self.databaseURL().path,
        contents: Data("not a database".utf8)
      )
    )
    let databaseAccess: DatabaseAccess = try testedInstance()

    let connection: SQLiteConnection =
      try databaseAccess
      .openConnection(Account.mock_ada.localID, Self.legacyKey)

    // Usable, and still on the key the other container holds.
    _ = try connection.fetch(.statement("SELECT count(*) FROM sqlite_master;"))
    XCTAssertEqual(storedDatabaseKey(), storedKey)
    XCTAssertFalse(deletedFiles.get().isEmpty)
  }

  func test_openConnection_failsWithoutDeletingAnything_whenDirectoryIsUnreachable() async throws {
    let directoryURL: URL = self.directoryURL
    patch(
      \OSFiles.applicationDataDirectory,
      with: always(
        directoryURL
          .appendingPathComponent("missing-\(UUID().uuidString)")
      )
    )
    let databaseAccess: DatabaseAccess = try testedInstance()

    XCTAssertThrowsError(
      try databaseAccess.openConnection(Account.mock_ada.localID, Self.legacyKey)
    ) { error in
      XCTAssertFalse(
        error.isDatabaseKeyIssue,
        "An unreachable directory must not be reported as a key issue, got \(error)"
      )
    }

    XCTAssertTrue(
      deletedFiles.get().isEmpty,
      "A database must not be deleted over a failure that says nothing about its contents"
    )
  }

  func test_delete_removesDatabaseFilesAndStoredKey() async throws {
    let databaseAccess: DatabaseAccess = try testedInstance()
    _ = try databaseAccess.openConnection(Account.mock_ada.localID, Self.legacyKey)

    try databaseAccess.delete(Account.mock_ada.localID)

    XCTAssertNil(storedDatabaseKey())
    XCTAssertEqual(
      Set(deletedFiles.get().map(\.lastPathComponent)),
      [
        "\(Account.mock_ada.localID).sqlite",
        "\(Account.mock_ada.localID).sqlite-wal",
        "\(Account.mock_ada.localID).sqlite-shm",
      ]
    )
  }
}
