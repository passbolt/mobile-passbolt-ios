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
import Dispatch
import SQLCipher

public struct SQLiteConnection {

  public var execute:
    (
      _ statement: SQLiteStatement,
      _ parameters: Array<SQLiteBindable?>
    ) -> Result<Void, TheErrorLegacy>
  public var fetch:
    (
      _ statement: SQLiteStatement,
      _ parameters: Array<SQLiteBindable?>
    ) -> Result<Array<SQLiteRow>, TheErrorLegacy>
  public var beginTransaction: () -> Result<Void, TheErrorLegacy>
  public var rollbackTransaction: () -> Result<Void, TheErrorLegacy>
  public var endTransaction: () -> Result<Void, TheErrorLegacy>
  public var enqueueOperation: (@escaping () -> Void) -> Void
}

extension SQLiteConnection {

  public static func open(
    at path: String = ":memory:",
    key: String? = nil,
    options: Int32 = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE,
    migrations: Array<SQLiteMigration> = .init()
  ) -> Result<SQLiteConnection, TheErrorLegacy> {
    let databaseQueue: DispatchQueue = .init(label: "SQLiteConnectionQueue")

    let connectionOpeningResult: Result<SQLiteConnectionHandle, TheErrorLegacy> = SQLiteConnectionHandle.open(
      at: path,
      key: key,
      options: options
    )

    let connection: SQLiteConnection
    switch connectionOpeningResult {
    case let .success(connectionHandle):
      connection = .init(
        execute: { statement, parameters in
          dispatchPrecondition(condition: .onQueue(databaseQueue))
          return
            connectionHandle
            .execute(statement, with: parameters)
        },
        fetch: { statement, parameters in
          dispatchPrecondition(condition: .onQueue(databaseQueue))
          return
            connectionHandle
            .fetch(statement, with: parameters)
        },
        beginTransaction: {
          dispatchPrecondition(condition: .onQueue(databaseQueue))
          return
            connectionHandle
            .execute("BEGIN TRANSACTION;")
        },
        rollbackTransaction: {
          dispatchPrecondition(condition: .onQueue(databaseQueue))
          return
            connectionHandle
            .execute("ROLLBACK TRANSACTION;")
        },
        endTransaction: {
          dispatchPrecondition(condition: .onQueue(databaseQueue))
          return
            connectionHandle
            .execute("END TRANSACTION;")
        },
        enqueueOperation: { operation in
          databaseQueue.async(execute: operation)
        }
      )

      let migrationResult: Result<Void, TheErrorLegacy> = Self.performMigrations(
        migrations,
        using: connectionHandle
      )

      switch migrationResult {
      case .success:
        return .success(connection)

      case let .failure(error):
        return .failure(error)
      }

    case let .failure(error):
      return .failure(error)
    }
  }

  @inlinable
  public func execute(
    _ statement: SQLiteStatement,
    with parameters: SQLiteBindable?...
  ) -> Result<Void, TheErrorLegacy> {
    execute(
      statement,
      parameters
    )
  }

  @inlinable
  public func execute(
    _ statement: SQLiteStatement,
    with parameters: Array<SQLiteBindable?>
  ) -> Result<Void, TheErrorLegacy> {
    execute(
      statement,
      parameters
    )
  }

  @inlinable
  public func fetch(
    _ statement: SQLiteStatement,
    with parameters: SQLiteBindable?...
  ) -> Result<Array<SQLiteRow>, TheErrorLegacy> {
    fetch(
      statement,
      parameters
    )
  }

  @inline(__always)
  public func fetch<Value>(
    _ statement: SQLiteStatement,
    with parameters: SQLiteBindable?...,
    mapping: (Array<SQLiteRow>) -> Result<Value, TheErrorLegacy>
  ) -> Result<Value, TheErrorLegacy> {
    fetch(
      statement,
      parameters
    )
    .flatMap(mapping)
  }

  @inline(__always)
  public func fetch<Value>(
    _ statement: SQLiteStatement,
    with parameters: Array<SQLiteBindable?>,
    mapping: (Array<SQLiteRow>) -> Result<Value, TheErrorLegacy>
  ) -> Result<Value, TheErrorLegacy> {
    fetch(
      statement,
      parameters
    )
    .flatMap(mapping)
  }

  @inlinable
  public func withQueue<Value>(
    _ operation: @escaping (Self) -> Result<Value, TheErrorLegacy>
  ) -> AnyPublisher<Value, TheErrorLegacy> {
    let resultSubject: PassthroughSubject<Value, TheErrorLegacy> = .init()
    enqueueOperation {
      switch operation(self) {
      case let .success(value):
        resultSubject.send(value)
        resultSubject.send(completion: .finished)

      case let .failure(error):
        resultSubject.send(completion: .failure(error))
      }
    }
    return
      resultSubject
      .eraseToAnyPublisher()
  }

  @inlinable
  public func withTransaction(
    _ transaction: (SQLiteConnection) -> Result<Void, TheErrorLegacy>
  ) -> Result<Void, TheErrorLegacy> {
    switch beginTransaction() {
    case .success:
      break

    case let .failure(error):
      return .failure(error)
    }

    switch transaction(self) {
    case .success:
      return endTransaction()

    case let .failure(error):
      return rollbackTransaction()
        .flatMap {
          .failure(error)
        }
    }
  }

  private static func performMigrations(
    _ migrations: Array<SQLiteMigration>,
    using connection: SQLiteConnectionHandle
  ) -> Result<Void, TheErrorLegacy> {
    func withTransaction(
      _ transaction: (SQLiteConnectionHandle) -> Result<Void, TheErrorLegacy>
    ) -> Result<Void, TheErrorLegacy> {
      switch connection.execute("BEGIN TRANSACTION;") {
      case .success:
        break

      case let .failure(error):
        return .failure(error)
      }

      switch transaction(connection) {
      case .success:
        return connection.execute("END TRANSACTION;")

      case let .failure(error):
        return connection.execute("ROLLBACK TRANSACTION;")
          .flatMap {
            .failure(error)
          }
      }
    }

    let currentSchemaVersionFetchResult: Result<Int?, TheErrorLegacy> =
      connection
      .fetch(
        "PRAGMA user_version;"
      )
      .map { rows -> Int? in
        rows.compactMap { $0.user_version as Int? }.first
      }

    let currentSchemaVersion: Int
    switch currentSchemaVersionFetchResult {
    case let .success(version):
      currentSchemaVersion = version ?? 0

    case let .failure(error):
      return .failure(error)
    }

    guard currentSchemaVersion < migrations.count
    else {
      if currentSchemaVersion > migrations.count {
        return .failure(
          TheErrorLegacy.databaseMigrationError(
            databaseErrorMessage:
              "Invalid schema version, provided: \(migrations.count), existing: \(currentSchemaVersion)"
          )
        )
      }
      else {
        return .success  // no migration needed
      }
    }

    for migration in migrations[currentSchemaVersion...] {
      let transactionResult: Result<Void, TheErrorLegacy> = withTransaction { conn in
        for step in migration.steps {
          let statementExecutionResult: Result<Void, TheErrorLegacy> =
            conn
            .execute(
              step.statement,
              with: step.parameters
            )

          switch statementExecutionResult {
          case .success:
            continue

          case let .failure(error):
            #if DEBUG
            raise(SIGTRAP)
            #endif
            return .failure(error)
          }
        }

        return .success
      }

      switch transactionResult {
      case .success:
        continue

      case let .failure(error):
        return .failure(error)
      }
    }

    return .success
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
      endTransaction: unimplemented("You have to provide mocks for used methods"),
      enqueueOperation: unimplemented("You have to provide mocks for used methods")
    )
  }
}

#endif
