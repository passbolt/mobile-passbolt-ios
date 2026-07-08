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
    key: String?,
    options: Int32
  ) throws -> SQLiteConnectionHandle {

    var handle: OpaquePointer?
    let openingStatus: Int32 = sqlite3_open_v2(
      path,
      &handle,
      options,
      nil
    )

    if let key: String = key {
      guard sqlite3_key(handle, key, Int32(key.utf8CString.count)) == SQLITE_OK
      else {
        throw
          DatabaseIssue
          .error(
            underlyingError:
              DatabaseConnectionIssue
              .error("Failed to decrypt database")
          )
      }
    }
    else {
      /* */
    }

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

    let connectionHandle: SQLiteConnectionHandle = .init(handle)

    try connectionHandle.execute("PRAGMA key;")
    try connectionHandle.execute("PRAGMA foreign_keys = ON;")
    try connectionHandle.execute("PRAGMA journal_mode = WAL;")
    // NORMAL fsyncs at checkpoint instead of every commit — safe under WAL for a re-fetchable cache.
    try connectionHandle.execute("PRAGMA synchronous = NORMAL;")
    // Keep temp tables / transient indexes (bulk-store temp tables, FTS rebuild) in memory.
    try connectionHandle.execute("PRAGMA temp_store = MEMORY;")
    try connectionHandle.execute("PRAGMA recursive_triggers = ON;")
    try connectionHandle.execute("PRAGMA quick_check;")
    try connectionHandle.execute("PRAGMA SQLITE_DBCONFIG_DEFENSIVE = ON;")

    return connectionHandle
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
