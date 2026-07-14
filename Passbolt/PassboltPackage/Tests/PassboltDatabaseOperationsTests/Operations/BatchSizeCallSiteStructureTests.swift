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
import CoreTest
import DatabaseOperations
import FeatureScopes
import Foundation
import Session
import TestExtensions
import XCTest

@testable import Database
@testable import PassboltDatabaseOperations

/// Structural guard for the `SQLiteBatch.maxRows(perRowBindings:)` call sites.
///
/// Instead of hoping a batch overflows a hard limit at runtime (which the sizing headroom can mask),
/// this runs each store operation against a fake connection that RECORDS the SQL it builds, then
/// inspects every multi-row `INSERT`: it reads the real number of `?` placeholders per row and the
/// chunk's row count straight from the generated statement and asserts
/// `rows <= SQLiteBatch.maxRows(perRowBindings: measuredBindings)`.
///
/// That is headroom-independent: if a table gains a column (an extra `?`) but the `perRowBindings`
/// literal at the call site is not bumped, the chunk is sized for too few bindings, so it holds more
/// rows than the *measured* binding count permits and the assertion fails — exactly the "added a
/// column, forgot to bump the count" regression. It also asserts the generated text and parameter
/// count stay under the hard limits.
final internal class BatchSizeCallSiteStructureTests: DatabaseOperationsTestCase {

  private let recorder: StatementRecorder = .init()

  override public func commonPrepare() async throws {
    try await super.commonPrepare()
    // Replace the real in-memory connection with a recording fake. The store operations resolve the
    // connection lazily (in the test body), so this last-wins patch is what they use. Nothing is
    // executed against a real database, so no foreign-key/schema setup is required.
    let connection: SQLiteConnection = makeRecordingConnection(self.recorder)
    patch(
      \SessionDatabase.connection,
      with: { connection }
    )
  }

  // users upsert: 8 host parameters/row.
  internal func test_usersStore_chunksMatchActualBindings() async throws {
    let count: Int = SQLiteBatch.maxRows(perRowBindings: 8) + 1
    let users: Array<UserDSO> = (0 ..< count)
      .map { (index: Int) in
        var user: UserDSO = self.currentUser
        user.id = .init()
        user.username = "batch-user-\(index)@passbolt.test"
        return user
      }

    try await self.storeUsers(users)

    self.assertRecordedBatchesRespectLimits()
  }

  // resourceFolders upsert: 4 host parameters/row.
  internal func test_foldersStore_chunksMatchActualBindings() async throws {
    let count: Int = SQLiteBatch.maxRows(perRowBindings: 4) + 1
    let folders: Array<ResourceFolderDTO> = (0 ..< count)
      .map { (index: Int) in
        .init(id: .init(), parentID: .none, name: "batch-folder-\(index)", permission: .owner, permissions: [])
      }

    try await self.storeFolders(folders)

    self.assertRecordedBatchesRespectLimits()
  }

  // userGroups upsert + usersGroups membership: both 2 host parameters/row.
  internal func test_userGroupsStore_chunksMatchActualBindings() async throws {
    let count: Int = SQLiteBatch.maxRows(perRowBindings: 2) + 1
    let groups: Array<UserGroupDTO> = (0 ..< count)
      .map { (index: Int) in
        .init(id: .init(), name: "batch-group-\(index)", userReferences: [.init(id: self.currentUser.id)])
      }

    try await self.storeUserGroups(groups)

    self.assertRecordedBatchesRespectLimits()
  }

  // Widest resources upserts: resources (10/row) and resourceMetadata (8/row). Sizing for 8/row fills
  // both chunks.
  internal func test_resourcesStore_chunksMatchActualBindings() async throws {
    let count: Int = SQLiteBatch.maxRows(perRowBindings: 8) + 1
    let resources: Array<ResourceDTO> = (0 ..< count)
      .map { (index: Int) in
        .create(resourceTypeId: self.testResourceType.id, name: "batch-resource-\(index)")
      }

    try await self.storeResources(resources)

    self.assertRecordedBatchesRespectLimits()
  }

  // MARK: - Assertions

  private func assertRecordedBatchesRespectLimits(
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    let batches: Array<RecordedBatch> = self.recorder.recorded.compactMap(Self.recordedBatch(from:))

    XCTAssertFalse(
      batches.isEmpty,
      "No multi-row VALUES statement was captured — the operation did not exercise SQLiteBatch chunking.",
      file: file,
      line: line
    )

    var sawFullChunk: Bool = false
    for batch: RecordedBatch in batches {
      let maxRowsForBindings: Int = SQLiteBatch.maxRows(perRowBindings: batch.bindings)
      XCTAssertLessThanOrEqual(
        batch.rows,
        maxRowsForBindings,
        """
        A chunk holds \(batch.rows) rows of \(batch.bindings) bindings each, but \
        maxRows(perRowBindings: \(batch.bindings)) is \(maxRowsForBindings). A `maxRows(perRowBindings:)` \
        call site is sized for fewer bindings than the row actually contains — bump its perRowBindings.
        """,
        file: file,
        line: line
      )
      XCTAssertLessThanOrEqual(
        batch.rows * batch.bindings,
        SQLiteBatch.maximumHostParameters,
        "A chunk exceeds the SQLite host-parameter limit.",
        file: file,
        line: line
      )
      XCTAssertLessThanOrEqual(
        batch.sqlLength,
        SQLiteBatch.maximumStatementLength,
        "A chunk's SQL text exceeds SQLITE_MAX_SQL_LENGTH.",
        file: file,
        line: line
      )
      if batch.rows == maxRowsForBindings {
        sawFullChunk = true
      }
    }

    XCTAssertTrue(
      sawFullChunk,
      "No full-size chunk was captured — feed more rows so the limit is actually exercised.",
      file: file,
      line: line
    )
  }

  private struct RecordedBatch {
    fileprivate var bindings: Int
    fileprivate var rows: Int
    fileprivate var sqlLength: Int
  }

  /// Reads the per-row binding count and row count of a multi-row `INSERT ... VALUES ( ... ), ( ... )`
  /// statement straight from its generated SQL. Returns `nil` for statements that are not multi-row
  /// VALUES inserts (e.g. `IN (...)` deletes or parameterless DDL), which are not SQLiteBatch chunks.
  private static func recordedBatch(from statement: SQLiteStatement) -> RecordedBatch? {
    let sql: String = statement.rawString
    let totalArguments: Int = statement.arguments.arguments.count
    guard totalArguments > 0,
      let valuesRange: Range<String.Index> = sql.range(of: "VALUES")
    else { return nil }

    let afterValues: Substring = sql[valuesRange.upperBound...]
    guard let open: String.Index = afterValues.firstIndex(of: "("),
      let close: String.Index = afterValues[afterValues.index(after: open)...].firstIndex(of: ")")
    else { return nil }

    let firstTuple: Substring = afterValues[open ... close]
    let bindings: Int = firstTuple.filter { (character: Character) in character == "?" }.count
    guard bindings > 0, totalArguments % bindings == 0
    else { return nil }

    return RecordedBatch(
      bindings: bindings,
      rows: totalArguments / bindings,
      sqlLength: sql.utf8.count
    )
  }
}

/// Thread-safe sink for the SQL statements a store operation builds.
private final class StatementRecorder: @unchecked Sendable {

  private let lock: NSLock = .init()
  private var storage: Array<SQLiteStatement> = .init()

  fileprivate func record(_ statement: SQLiteStatement) {
    self.lock.lock()
    defer { self.lock.unlock() }
    self.storage.append(statement)
  }

  fileprivate var recorded: Array<SQLiteStatement> {
    self.lock.lock()
    defer { self.lock.unlock() }
    return self.storage
  }
}

/// A `SQLiteConnection` that records every executed statement instead of touching a database. `fetch`
/// returns no rows, which is all the store operations need from their in-transaction reads.
private func makeRecordingConnection(_ recorder: StatementRecorder) -> SQLiteConnection {
  var connection: SQLiteConnection = .placeholder
  connection.execute = { (statement: SQLiteStatement) in recorder.record(statement) }
  connection.fetch = { (_: SQLiteStatement) in Array<SQLiteRow>() }
  connection.beginTransaction = {}
  connection.endTransaction = {}
  connection.rollbackTransaction = {}
  connection.executeReusing = { (statement: SQLiteStatement, _: PreparedStatementCache) in
    recorder.record(statement)
  }
  return connection
}
