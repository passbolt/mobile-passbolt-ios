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

import Database
import XCTest

import struct Foundation.Data
import class Foundation.FileManager
import struct Foundation.URL
import struct Foundation.UUID

// Exercises real SQLCipher encryption on a temporary file: the migration from the legacy
// passphrase derived key to a random raw key has to keep the contents and has to actually
// change the key on disk.
// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class SQLiteDatabaseEncryptionTests: XCTestCase {

  private var databaseURL: URL!

  private let legacyKey: String = String(repeating: "a", count: 128)
  private let rawKey: Data = Data(repeating: 0x2d, count: 32)
  private let otherRawKey: Data = Data(repeating: 0x7e, count: 32)

  override func setUp() {
    super.setUp()
    self.databaseURL =
      FileManager
      .default
      .temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("sqlite")
  }

  override func tearDown() {
    for suffix: String in ["", "-wal", "-shm"] {
      try? FileManager.default.removeItem(atPath: self.databaseURL.path + suffix)
    }
    self.databaseURL = .none
    super.tearDown()
  }

  private func createLegacyDatabase() throws {
    let connection: SQLiteConnection = try SQLiteConnection.open(
      at: self.databaseURL.path,
      key: .passphraseDerived(self.legacyKey)
    )
    try connection.execute(
      .statement("CREATE TABLE items (id INTEGER PRIMARY KEY, value TEXT);")
    )
    try connection.execute(
      .statement("INSERT INTO items (id, value) VALUES (?1, ?2);", arguments: 1, "kept")
    )
  }

  private func storedValue(
    openingWith key: SQLiteConnectionKey
  ) throws -> String? {
    let connection: SQLiteConnection = try SQLiteConnection.open(
      at: self.databaseURL.path,
      key: key
    )
    let rows: Array<SQLiteRow> = try connection.fetch(
      .statement("SELECT value FROM items WHERE id = 1;")
    )
    return rows.first?.value
  }

  func test_rekey_keepsDatabaseContents() throws {
    try createLegacyDatabase()

    let migrated: SQLiteConnection = try SQLiteConnection.open(
      at: self.databaseURL.path,
      key: .passphraseDerived(self.legacyKey),
      rekeyTo: .raw(self.rawKey)
    )
    let rows: Array<SQLiteRow> = try migrated.fetch(
      .statement("SELECT value FROM items WHERE id = 1;")
    )

    XCTAssertEqual(rows.first?.value, "kept")
  }

  func test_rekey_makesDatabaseReadableWithNewKey() throws {
    try createLegacyDatabase()
    _ = try SQLiteConnection.open(
      at: self.databaseURL.path,
      key: .passphraseDerived(self.legacyKey),
      rekeyTo: .raw(self.rawKey)
    )

    XCTAssertEqual(try storedValue(openingWith: .raw(self.rawKey)), "kept")
  }

  func test_rekey_makesLegacyKeyUseless() throws {
    try createLegacyDatabase()
    _ = try SQLiteConnection.open(
      at: self.databaseURL.path,
      key: .passphraseDerived(self.legacyKey),
      rekeyTo: .raw(self.rawKey)
    )

    XCTAssertThrowsError(
      try storedValue(openingWith: .passphraseDerived(self.legacyKey))
    )
  }

  func test_open_failsWithWrongRawKey() throws {
    try createLegacyDatabase()
    _ = try SQLiteConnection.open(
      at: self.databaseURL.path,
      key: .passphraseDerived(self.legacyKey),
      rekeyTo: .raw(self.rawKey)
    )

    XCTAssertThrowsError(
      try storedValue(openingWith: .raw(self.otherRawKey))
    )
  }

  func test_open_reportsKeyIssue_whenRawKeyIsWrong() throws {
    try createLegacyDatabase()
    _ = try SQLiteConnection.open(
      at: self.databaseURL.path,
      key: .passphraseDerived(self.legacyKey),
      rekeyTo: .raw(self.rawKey)
    )

    XCTAssertThrowsError(
      try storedValue(openingWith: .raw(self.otherRawKey))
    ) { error in
      XCTAssertTrue(
        error.isDatabaseKeyIssue,
        "A wrong key has to be reported as a key issue, got \(error)"
      )
    }
  }

  func test_open_reportsKeyIssue_whenLegacyKeyIsWrong() throws {
    try createLegacyDatabase()

    XCTAssertThrowsError(
      try storedValue(openingWith: .passphraseDerived(String(repeating: "b", count: 128)))
    ) { error in
      XCTAssertTrue(
        error.isDatabaseKeyIssue,
        "A wrong key has to be reported as a key issue, got \(error)"
      )
    }
  }

  func test_open_doesNotReportKeyIssue_whenPathIsUnreachable() throws {
    let unreachablePath: String =
      self.databaseURL
      .deletingLastPathComponent()
      .appendingPathComponent("missing-\(UUID().uuidString)")
      .appendingPathComponent("database.sqlite")
      .path

    XCTAssertThrowsError(
      try SQLiteConnection.open(
        at: unreachablePath,
        key: .raw(self.rawKey)
      )
    ) { error in
      XCTAssertFalse(
        error.isDatabaseKeyIssue,
        "An unreachable path must not be mistaken for a wrong key, got \(error)"
      )
    }
  }
}
