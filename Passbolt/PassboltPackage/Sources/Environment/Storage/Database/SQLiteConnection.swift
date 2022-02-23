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
import Dispatch
import SQLCipher

public struct SQLiteConnection {

  public var execute:
    (
      _ statement: SQLiteStatement,
      _ parameters: Array<SQLiteBindable?>
    ) -> Result<Void, Error>
  public var fetch:
    (
      _ statement: SQLiteStatement,
      _ parameters: Array<SQLiteBindable?>
    ) -> Result<Array<SQLiteRow>, Error>
  public var beginTransaction: () -> Result<Void, Error>
  public var rollbackTransaction: () -> Result<Void, Error>
  public var endTransaction: () -> Result<Void, Error>
  public var enqueueOperation: (@escaping () -> Void) -> Void
}

extension SQLiteConnection {

  public static func open(
    at path: String = ":memory:",
    key: String? = nil,
    options: Int32 = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE,
    migrations: Array<SQLiteMigration> = .init(),
    openingOperations: Array<SQLiteStatement> = .init()
  ) -> Result<SQLiteConnection, Error> {
    let databaseQueue: DispatchQueue = .init(label: "SQLiteConnectionQueue")

    let connectionOpeningResult: Result<SQLiteConnectionHandle, Error> = SQLiteConnectionHandle.open(
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

      let migrationResult: Result<Void, Error> = Self.performMigrations(
        migrations,
        using: connectionHandle
      )

      switch migrationResult {
      case .success:
        break  // continue

      case let .failure(error):
        return .failure(error)
      }

      let openingOperationsResult: Result<Void, Error> = Self.performOpeningOperations(
        openingOperations,
        using: connectionHandle
      )

      switch openingOperationsResult {
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
  ) -> Result<Void, Error> {
    execute(
      statement,
      parameters
    )
  }

  @inlinable
  public func execute(
    _ statement: SQLiteStatement,
    with parameters: Array<SQLiteBindable?>
  ) -> Result<Void, Error> {
    execute(
      statement,
      parameters
    )
  }

  @inlinable
  public func fetch(
    _ statement: SQLiteStatement,
    with parameters: SQLiteBindable?...
  ) -> Result<Array<SQLiteRow>, Error> {
    fetch(
      statement,
      parameters
    )
  }

  @inline(__always)
  public func fetch<Value>(
    _ statement: SQLiteStatement,
    with parameters: SQLiteBindable?...,
    mapping: (Array<SQLiteRow>) -> Result<Value, Error>
  ) -> Result<Value, Error> {
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
    mapping: (Array<SQLiteRow>) -> Result<Value, Error>
  ) -> Result<Value, Error> {
    fetch(
      statement,
      parameters
    )
    .flatMap(mapping)
  }

  @inlinable
  public func withQueue<Value>(
    _ operation: @escaping (Self) -> Result<Value, Error>
  ) -> AnyPublisher<Value, Error> {
    let resultSubject: PassthroughSubject<Value, Error> = .init()
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
  public func withTransaction<Value>(
    _ transaction: (SQLiteConnection) -> Result<Value, Error>
  ) -> Result<Value, Error> {
    switch beginTransaction() {
    case .success:
      break

    case let .failure(error):
      return .failure(error)
    }

    switch transaction(self) {
    case let .success(value):
      return endTransaction().map { value }

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
  ) -> Result<Void, Error> {
    let currentSchemaVersionFetchResult: Result<Int?, Error> =
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
          DatabaseIssue
            .error(
              underlyingError:
                DatabaseConnectionIssue
                .error("Invalid database schema version")
                .recording(currentSchemaVersion, for: "currentSchemaVersion")
                .recording(migrations.count, for: "providedSchemaVersion")
            )
        )
      }
      else {
        return .success  // no migration needed
      }
    }

    for migration in migrations[currentSchemaVersion...] {
      let transactionResult: Result<Void, Error> = connection.withTransaction { conn in
        for step in migration.steps {
          let statementExecutionResult: Result<Void, Error> =
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

  private static func performOpeningOperations(
    _ operations: Array<SQLiteStatement>,
    using connection: SQLiteConnectionHandle
  ) -> Result<Void, Error> {
    connection.withTransaction { conn in
      for operation in operations {
        switch conn.execute(operation) {
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
