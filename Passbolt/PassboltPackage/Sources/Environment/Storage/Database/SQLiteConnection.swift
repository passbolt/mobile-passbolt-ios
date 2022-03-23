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
import Dispatch
import SQLCipher

public struct SQLiteConnection {

  public var execute:
    @StorageAccessActor (
      _ statement: SQLiteStatement,
      _ parameters: Array<SQLiteBindable?>
    ) throws -> Void
  public var fetch:
    @StorageAccessActor (
      _ statement: SQLiteStatement,
      _ parameters: Array<SQLiteBindable?>
    ) throws -> Array<SQLiteRow>
  public var beginTransaction: @StorageAccessActor () throws -> Void
  public var rollbackTransaction: @StorageAccessActor () throws -> Void
  public var endTransaction: @StorageAccessActor () throws -> Void
}

extension SQLiteConnection {

  @StorageAccessActor public static func open(
    at path: String = ":memory:",
    key: String? = nil,
    options: Int32 = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE,
    migrations: Array<SQLiteMigration> = .init(),
    openingOperations: Array<SQLiteStatement> = .init()
  ) throws -> SQLiteConnection {
    let connectionHandle: SQLiteConnectionHandle =
      try SQLiteConnectionHandle.open(
        at: path,
        key: key,
        options: options
      )

    @StorageAccessActor func execute(
      statement: SQLiteStatement,
      with parameters: Array<SQLiteBindable?>
    ) throws {
      try connectionHandle.execute(statement, with: parameters)
    }

    @StorageAccessActor func fetch(
      statement: SQLiteStatement,
      with parameters: Array<SQLiteBindable?>
    ) throws -> Array<SQLiteRow> {
      try connectionHandle.fetch(statement, with: parameters)
    }

    @StorageAccessActor func beginTransaction() throws {
      try connectionHandle.execute("BEGIN TRANSACTION;")
    }

    @StorageAccessActor func rollbackTransaction() throws {
      try connectionHandle.execute("ROLLBACK TRANSACTION;")
    }

    @StorageAccessActor func endTransaction() throws {
      try connectionHandle.execute("END TRANSACTION;")
    }

    let connection: SQLiteConnection = .init(
      execute: execute(statement:with:),
      fetch: fetch(statement:with:),
      beginTransaction: beginTransaction,
      rollbackTransaction: rollbackTransaction,
      endTransaction: endTransaction
    )

    try Self.performMigrations(
      migrations,
      using: connection
    )

    try Self.performOpeningOperations(
      openingOperations,
      using: connection
    )

    return connection
  }

  @inlinable
  @StorageAccessActor public func execute(
    _ statement: SQLiteStatement,
    with parameters: SQLiteBindable?...
  ) throws {
    try execute(
      statement,
      parameters
    )
  }

  @inlinable
  @StorageAccessActor public func execute(
    _ statement: SQLiteStatement,
    with parameters: Array<SQLiteBindable?>
  ) throws {
    try execute(
      statement,
      parameters
    )
  }

  @inlinable
  @StorageAccessActor public func fetch(
    _ statement: SQLiteStatement,
    with parameters: SQLiteBindable?...
  ) throws -> Array<SQLiteRow> {
    try fetch(
      statement,
      parameters
    )
  }

  @inline(__always)
  @StorageAccessActor public func fetch<Value>(
    _ statement: SQLiteStatement,
    with parameters: SQLiteBindable?...,
    mapping: (Array<SQLiteRow>) throws -> Value
  ) throws -> Value {
    try mapping(
      fetch(
        statement,
        parameters
      )
    )
  }

  @inline(__always)
  @StorageAccessActor public func fetch<Value>(
    _ statement: SQLiteStatement,
    with parameters: Array<SQLiteBindable?>,
    mapping: (Array<SQLiteRow>) throws -> Value
  ) throws -> Value {
    try mapping(
      fetch(
        statement,
        parameters
      )
    )
  }

  @inlinable
  @StorageAccessActor public func withTransaction<Value>(
    _ transaction: @StorageAccessActor (SQLiteConnection) throws -> Value
  ) throws -> Value {
    try beginTransaction()

    do {
      let value: Value = try transaction(self)
      try endTransaction()
      return value
    }
    catch {
      try rollbackTransaction()
      throw error
    }
  }

  @StorageAccessActor private static func performMigrations(
    _ migrations: Array<SQLiteMigration>,
    using connection: SQLiteConnection
  ) throws {
    let currentSchemaVersion: Int =
      try connection
      .fetch(
        "PRAGMA user_version;",
        mapping: { $0.first?.user_version as Int? }
      )
      ?? 0

    guard currentSchemaVersion < migrations.count
    else {
      if currentSchemaVersion > migrations.count {
        throw
          DatabaseIssue
          .error(
            underlyingError:
              DatabaseConnectionIssue
              .error("Invalid database schema version")
              .recording(currentSchemaVersion, for: "currentSchemaVersion")
              .recording(migrations.count, for: "providedSchemaVersion")
          )
      }
      else {
        return  // no migration needed
      }
    }

    for migration in migrations[currentSchemaVersion...] {
      try connection.withTransaction { conn in
        for step in migration.steps {
          do {
            try conn
              .execute(
                step.statement,
                with: step.parameters
              )
          }
          catch {
            #if DEBUG
            raise(SIGTRAP)
            #endif
            throw error
          }
        }
      }
    }
  }

  @StorageAccessActor private static func performOpeningOperations(
    _ operations: Array<SQLiteStatement>,
    using connection: SQLiteConnection
  ) throws {
    try connection.withTransaction { conn in
      for operation in operations {
        do {
          try conn.execute(operation)
        }
        catch {
          #if DEBUG
          raise(SIGTRAP)
          #endif
          throw error
        }
      }
    }
  }
}

#if DEBUG

extension SQLiteConnection {

  public static var placeholder: Self {
    Self(
      execute: unimplemented("You have to provide mocks for used methods"),
      fetch: unimplemented("You have to provide mocks for used methods"),
      beginTransaction: unimplemented("You have to provide mocks for used methods"),
      rollbackTransaction: unimplemented("You have to provide mocks for used methods"),
      endTransaction: unimplemented("You have to provide mocks for used methods")
    )
  }
}

#endif
