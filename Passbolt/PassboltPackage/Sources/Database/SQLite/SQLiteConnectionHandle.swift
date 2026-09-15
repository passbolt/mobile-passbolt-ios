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
import SQLCipher

@usableFromInline
internal final class SQLiteConnectionHandle: @unchecked Sendable {

  internal static func open(
    at path: String,
    key: SQLiteConnectionKey?,
    options: Int32
  ) throws -> SQLiteConnectionHandle {

    var handle: OpaquePointer?
    let openingStatus: Int32 = sqlite3_open_v2(
      path,
      &handle,
      options,
      nil
    )

    // Checked before the key is applied: `sqlite3_key` on a handle left behind by a failed
    // open reports a decryption failure, which would mask the real cause - a missing directory
    // or a full disk - and send `DatabaseAccess.openConnection` into recreating the database.
    guard openingStatus == SQLITE_OK
    else {
      let errorMessage: String
      if handle != nil {
        errorMessage =
          sqlite3_errmsg(handle)
          .map(String.init(cString:))
          ?? "Unable to open database at: \(path)"
        sqlite3_close(handle)
      }
      else {
        errorMessage = "Unable to open database at: \(path)"
      }
      throw
        DatabaseIssue
        .error(
          underlyingError:
            DatabaseConnectionIssue
            .error("Failed to open database")
            .recording(path, for: "path")
            .recording(openingStatus, for: "openingStatus")
            .recording(errorMessage, for: "errorMessage")
        )
    }

    if let key: SQLiteConnectionKey = key {
      guard sqlite3_key(handle, key.sqlCipherRepresentation, key.sqlCipherByteCount) == SQLITE_OK
      else {
        // Read the message before closing - `sqlite3_errmsg` needs a live handle.
        let errorMessage: String =
          sqlite3_errmsg(handle)
          .map(String.init(cString:))
          ?? "Unknown failure reason"
        // The handle is open here and not wrapped in `SQLiteConnectionHandle` yet, so there is
        // no `deinit` to close it on the way out.
        sqlite3_close(handle)
        throw
          DatabaseIssue
          .error(
            underlyingError:
              DatabaseKeyIssue
              .error("Failed to apply database key")
              .recording(path, for: "path")
              .recording(errorMessage, for: "errorMessage")
          )
      }
    }
    else {
      /* */
    }

    let connectionHandle: SQLiteConnectionHandle = .init(handle)

    // The vendored SQLCipher build pinned these via compile-time defines
    // (SQLITE_MAX_SQL_LENGTH=100000; SQLITE_MAX_VARIABLE_NUMBER defaulted to 32766).
    // The official SQLCipher package ships higher defaults (1e9 and 99999), so re-impose
    // the historical values at runtime — preserving the hardening and keeping the
    // SQLiteBatch chunking assumptions (and the asserts below) valid.
    sqlite3_limit(handle, SQLITE_LIMIT_SQL_LENGTH, Int32(SQLiteBatch.maximumStatementLength))
    sqlite3_limit(handle, SQLITE_LIMIT_VARIABLE_NUMBER, Int32(SQLiteBatch.maximumHostParameters))

    #if DEBUG
    // Guard the hard-coded SQLiteBatch ceilings against a SQLCipher rebuild (newVal < 0 reads the limit).
    assert(
      Int(sqlite3_limit(handle, SQLITE_LIMIT_VARIABLE_NUMBER, -1)) == SQLiteBatch.maximumHostParameters,
      "SQLCipher SQLITE_LIMIT_VARIABLE_NUMBER changed; update SQLiteBatch.maximumHostParameters"
    )
    assert(
      Int(sqlite3_limit(handle, SQLITE_LIMIT_SQL_LENGTH, -1)) == SQLiteBatch.maximumStatementLength,
      "SQLCipher SQLITE_LIMIT_SQL_LENGTH changed; update SQLiteBatch.maximumStatementLength"
    )
    #endif

    do {
      try connectionHandle.execute("PRAGMA foreign_keys = ON;")
      try connectionHandle.execute("PRAGMA journal_mode = WAL;")
      // NORMAL fsyncs at checkpoint instead of every commit — safe under WAL for a re-fetchable cache.
      try connectionHandle.execute("PRAGMA synchronous = NORMAL;")
      // Keep temp tables / transient indexes (bulk-store temp tables, FTS rebuild) in memory.
      try connectionHandle.execute("PRAGMA temp_store = MEMORY;")
      try connectionHandle.execute("PRAGMA recursive_triggers = ON;")
      try connectionHandle.execute("PRAGMA quick_check;")
    }
    catch {
      throw
        connectionHandle
        .classifiedOpeningFailure(
          error,
          at: path
        )
    }

    return connectionHandle
  }

  /// Turns a failure of the statements run while opening into either a key failure or a
  /// connection failure.
  ///
  /// SQLCipher accepts any key in `sqlite3_key` without touching the file - it only fails once
  /// the first page is read and its decrypted header does not check out. That read is one of the
  /// opening statements, so without this a wrong key is indistinguishable from a full disk or a
  /// corrupted file, and `DatabaseAccess` decides between re-keying the database and deleting it
  /// on exactly that distinction.
  ///
  /// Deliberately classifies an error that already happened instead of probing for one: any
  /// read issued before the opening statements would reach page one of a database being created
  /// ahead of the first write, which leaves `sqlite3_rekey` with no pages to re-encrypt and
  /// silently keeps the database on the key it was opened with.
  private func classifiedOpeningFailure(
    _ error: Error,
    at path: String
  ) -> Error {
    let status: Int32 = sqlite3_errcode(self.handle)
    let errorMessage: String = lastErrorMessage()

    let isKeyFailure: Bool =
      status == SQLITE_NOTADB
      || errorMessage.contains("not a database")

    guard isKeyFailure
    else { return error }

    return
      DatabaseIssue
      .error(
        underlyingError:
          DatabaseKeyIssue
          .error("Failed to decrypt database")
          .recording(path, for: "path")
          .recording(status, for: "status")
          .recording(errorMessage, for: "errorMessage")
      )
  }

  /// Re-encrypts the whole database with `key`, replacing the key it was opened with.
  /// Has to be called on a connection that already decrypts (the opening statements fail first
  /// if it does not) and outside of any transaction.
  ///
  /// Only for a database that already holds data. `sqlite3_rekey` re-encrypts the pages that are
  /// there, so on an empty database it succeeds while changing nothing, and the database quietly
  /// stays on the key it was opened with. Create such a database under the key it should have
  /// instead - see `DatabaseAccess.openConnection`.
  @usableFromInline
  internal func rekey(
    to key: SQLiteConnectionKey
  ) throws {
    guard sqlite3_rekey(self.handle, key.sqlCipherRepresentation, key.sqlCipherByteCount) == SQLITE_OK
    else {
      throw
        DatabaseIssue
        .error(
          underlyingError:
            DatabaseConnectionIssue
            .error("Failed to rekey database")
            .recording(lastErrorMessage(), for: "errorMessage")
        )
    }
  }

  private let handle: OpaquePointer?

  private init(
    _ handle: OpaquePointer?
  ) {
    self.handle = handle
  }

  deinit {
    sqlite3_close(handle)
  }

  @usableFromInline
  internal func execute(
    _ statement: String,
    with parameters: Array<SQLiteValue> = .init()
  ) throws {
    let statementHandle: OpaquePointer? =
      try prepareStatement(
        statement,
        with: parameters
      )

    defer { sqlite3_finalize(statementHandle) }

    var stepResult: Int32 = sqlite3_step(
      statementHandle
    )

    while stepResult == SQLITE_ROW {
      stepResult = sqlite3_step(
        statementHandle
      )
    }

    guard stepResult == SQLITE_DONE
    else {
      throw
        DatabaseIssue
        .error(
          underlyingError:
            DatabaseStatementExecutionFailure
            .error()
            .recording(lastErrorMessage(), for: "errorMessage")
            .recording(statement, for: "statement")
            .recording(parameters, for: "parameters")
        )
    }
  }

  @usableFromInline
  internal func fetch(
    _ statement: String,
    with parameters: Array<SQLiteValue> = .init()
  ) throws -> Array<SQLiteRow> {
    let statementHandle: OpaquePointer? =
      try prepareStatement(
        statement,
        with: parameters
      )

    defer { sqlite3_finalize(statementHandle) }

    var rows: Array<SQLiteRow> = []
    var stepResult: Int32 = sqlite3_step(
      statementHandle
    )

    while stepResult == SQLITE_ROW {
      rows
        .append(
          SQLiteRow(
            statementHandle
          )
        )
      stepResult = sqlite3_step(
        statementHandle
      )
    }

    guard stepResult == SQLITE_DONE
    else {
      throw
        DatabaseIssue
        .error(
          underlyingError:
            DatabaseStatementExecutionFailure
            .error()
            .recording(lastErrorMessage(), for: "errorMessage")
            .recording(statement, for: "statement")
            .recording(parameters, for: "parameters")
        )
    }

    return rows
  }

  /// Execute a non-row-returning statement reusing a compiled `sqlite3_stmt` held by `cache`.
  /// The first call for a given SQL string compiles and stores it; subsequent calls reset and
  /// rebind it, avoiding repeated `sqlite3_prepare_v2`. The cache must be finalized by its owner
  /// (see `SQLiteConnection.withPreparedStatements`); statements are never finalized here.
  /// Safe only when the cache is used by a single thread (e.g. inside one synchronous transaction).
  @usableFromInline
  internal func executeReusing(
    _ statement: String,
    with parameters: Array<SQLiteValue> = .init(),
    cache: PreparedStatementCache
  ) throws {
    let statementHandle: OpaquePointer?
    if let cached: OpaquePointer = cache.handle(for: statement) {
      statementHandle = cached
      sqlite3_reset(statementHandle)
      sqlite3_clear_bindings(statementHandle)
    }
    else {
      statementHandle = try compileStatement(statement)
      cache.store(statementHandle, for: statement)
    }

    try bindParameters(parameters, to: statementHandle, statement: statement)

    var stepResult: Int32 = sqlite3_step(statementHandle)
    while stepResult == SQLITE_ROW {
      stepResult = sqlite3_step(statementHandle)
    }

    guard stepResult == SQLITE_DONE
    else {
      sqlite3_reset(statementHandle)
      throw
        DatabaseIssue
        .error(
          underlyingError:
            DatabaseStatementExecutionFailure
            .error()
            .recording(lastErrorMessage(), for: "errorMessage")
            .recording(statement, for: "statement")
            .recording(parameters, for: "parameters")
        )
    }
  }

  @inline(__always)
  private func prepareStatement(
    _ statement: String,
    with parameters: Array<SQLiteValue>
  ) throws -> OpaquePointer? {
    let statementHandle: OpaquePointer? = try compileStatement(statement)
    try bindParameters(parameters, to: statementHandle, statement: statement)
    return statementHandle
  }

  @inline(__always)
  private func compileStatement(
    _ statement: String
  ) throws -> OpaquePointer? {
    var statementHandle: OpaquePointer?

    let statementPreparationResult: Int32 = sqlite3_prepare_v2(
      handle,
      statement,
      -1,
      &statementHandle,
      nil
    )

    guard statementPreparationResult == SQLITE_OK
    else {
      throw
        DatabaseIssue
        .error(
          underlyingError:
            DatabaseStatementInvalid
            .error()
            .recording(lastErrorMessage(), for: "errorMessage")
            .recording(statement, for: "statement")
        )
    }

    return statementHandle
  }

  @inline(__always)
  private func bindParameters(
    _ parameters: Array<SQLiteValue>,
    to statementHandle: OpaquePointer?,
    statement: String
  ) throws {
    guard sqlite3_bind_parameter_count(statementHandle) == parameters.count
    else {
      throw
        DatabaseIssue
        .error(
          underlyingError:
            DatabaseBindingInvalid
            .error()
            .recording("Bindings count does not match parameters count", for: "errorMessage")
            .recording(parameters.count, for: "parameters count")
            .recording(sqlite3_bind_parameter_count(statementHandle), for: "binding parameters count")
            .recording(statement, for: "statement")
            .recording(parameters, for: "parameters")
        )
    }

    for (idx, parameter) in parameters.enumerated() {
      guard
        parameter
          .bind(
            statementHandle,
            at: Int32(idx + 1)
          )
      else {
        throw
          DatabaseIssue
          .error(
            underlyingError:
              DatabaseBindingInvalid
              .error()
              .recording(lastErrorMessage(), for: "errorMessage")
              .recording(statement, for: "statement")
              .recording(parameters, for: "parameters")
          )
      }
    }
  }

  @usableFromInline
  internal func withTransaction(
    _ transaction: (SQLiteConnectionHandle) throws -> Void
  ) throws {
    try self.execute("BEGIN TRANSACTION;")

    do {
      try transaction(self)
      try self.execute("END TRANSACTION;")
    }
    catch {
      try self.execute("ROLLBACK TRANSACTION;")
      throw error
    }
  }

  @inline(__always)
  private func lastErrorMessage() -> String {
    sqlite3_errmsg(handle)
      .map(String.init(cString:))
      ?? "Unknown failure reason"
  }
}

/// Holds compiled `sqlite3_stmt` handles keyed by their SQL text so they can be reused across
/// many executions (avoiding repeated compilation). Intended to live for the duration of a single
/// synchronous transaction and be finalized at its end via `finalizeAll()`. Not safe for concurrent
/// use across threads — it is owned by the single thread running the transaction body.
@usableFromInline
internal final class PreparedStatementCache: @unchecked Sendable {

  private var handles: Dictionary<String, OpaquePointer> = .init()

  @usableFromInline
  internal init() {}

  @inline(__always)
  internal func handle(for statement: String) -> OpaquePointer? {
    self.handles[statement]
  }

  @inline(__always)
  internal func store(_ handle: OpaquePointer?, for statement: String) {
    guard let handle: OpaquePointer = handle else { return }
    self.handles[statement] = handle
  }

  @usableFromInline
  internal func finalizeAll() {
    for handle: OpaquePointer in self.handles.values {
      sqlite3_finalize(handle)
    }
    self.handles.removeAll()
  }
}
