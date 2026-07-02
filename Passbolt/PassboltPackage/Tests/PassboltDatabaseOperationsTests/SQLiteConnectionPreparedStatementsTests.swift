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

// Validates `SQLiteConnection.withPreparedStatements`, which reuses compiled statements across a
// batch (used by the resource store). Behavior must match plain `execute`.
// swift-format-ignore: AlwaysUseLowerCamelCase
final class SQLiteConnectionPreparedStatementsTests: XCTestCase {

  private func makeConnection() throws -> SQLiteConnection {
    let connection: SQLiteConnection = try SQLiteConnection.open()
    try connection.execute(
      .statement("CREATE TABLE items (id INTEGER PRIMARY KEY, value TEXT);")
    )
    return connection
  }

  func test_withPreparedStatements_insertsAllRows_whenReusingSameStatement() throws {
    let connection: SQLiteConnection = try makeConnection()

    try connection.withTransaction { conn in
      try conn.withPreparedStatements { prepared in
        for index: Int in 1 ... 100 {
          try prepared.execute(
            .statement(
              "INSERT INTO items (id, value) VALUES (?1, ?2);",
              arguments: index,
              "value-\(index)"
            )
          )
        }
      }
    }

    let rows: Array<SQLiteRow> = try connection.fetch(
      .statement("SELECT id, value FROM items ORDER BY id;")
    )
    XCTAssertEqual(rows.count, 100)
    guard let first: SQLiteRow = rows.first, let last: SQLiteRow = rows.last
    else { return XCTFail("Missing rows") }
    let firstID: Int? = first.id
    let lastValue: String? = last.value
    XCTAssertEqual(firstID, 1)
    XCTAssertEqual(lastValue, "value-100")
  }

  func test_withPreparedStatements_supportsMultipleDistinctStatementsInterleaved() throws {
    let connection: SQLiteConnection = try makeConnection()

    try connection.withPreparedStatements { prepared in
      try prepared.execute(.statement("INSERT INTO items (id, value) VALUES (?1, ?2);", arguments: 1, "a"))
      try prepared.execute(.statement("UPDATE items SET value = ?2 WHERE id = ?1;", arguments: 1, "b"))
      try prepared.execute(.statement("INSERT INTO items (id, value) VALUES (?1, ?2);", arguments: 2, "c"))
    }

    let rows: Array<SQLiteRow> = try connection.fetch(.statement("SELECT value FROM items ORDER BY id;"))
    let values: Array<String> = rows.compactMap { (row: SQLiteRow) -> String? in row.value }
    XCTAssertEqual(values, ["b", "c"])
  }

  func test_withPreparedStatements_rollbackDiscardsChanges() throws {
    let connection: SQLiteConnection = try makeConnection()

    do {
      try connection.withTransaction { conn in
        try conn.withPreparedStatements { prepared in
          for index: Int in 1 ... 10 {
            try prepared.execute(
              .statement("INSERT INTO items (id, value) VALUES (?1, ?2);", arguments: index, "v")
            )
          }
        }
        throw PreparedStatementsTestError.forcedRollback
      }
      XCTFail("Expected to throw")
    }
    catch is PreparedStatementsTestError {
      // expected
    }

    let rows: Array<SQLiteRow> = try connection.fetch(.statement("SELECT id FROM items;"))
    XCTAssertTrue(rows.isEmpty)
  }

  func test_nonTransactionalExecuteAndFetch_stillWork() throws {
    let connection: SQLiteConnection = try makeConnection()
    try connection.execute(
      .statement("INSERT INTO items (id, value) VALUES (?1, ?2);", arguments: 42, "x")
    )
    let rows: Array<SQLiteRow> = try connection.fetch(
      .statement("SELECT value FROM items WHERE id = ?1;", arguments: 42)
    )
    guard let row: SQLiteRow = rows.first
    else { return XCTFail("Missing row") }
    let value: String? = row.value
    XCTAssertEqual(value, "x")
  }
}

private enum PreparedStatementsTestError: Error {
  case forcedRollback
}
