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
internal final class SQLiteConnectionHandle {

  @StorageAccessActor internal static func open(
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
  @StorageAccessActor internal func execute(
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
  @StorageAccessActor internal func fetch(
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

  @inline(__always)
  @StorageAccessActor private func prepareStatement(
    _ statement: String,
    with parameters: Array<SQLiteValue>
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
            .recording(parameters, for: "parameters")
        )
    }

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

    return statementHandle
  }

  @usableFromInline
  @StorageAccessActor internal func withTransaction(
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
  @StorageAccessActor private func lastErrorMessage() -> String {
    sqlite3_errmsg(handle)
      .map(String.init(cString:))
      ?? "Unknown failure reason"
  }
}
