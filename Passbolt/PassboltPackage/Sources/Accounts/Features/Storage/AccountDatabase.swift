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

import Features

public struct AccountDatabase {
  
  public var execute: (
    _ statement: DatabaseStatement,
    _ bindings: Array<DatabaseStatementBindable?>
  ) -> AnyPublisher<Void, TheError>
  public var loadRows: (
    _ query: DatabaseStatement,
    _ bindings: Array<DatabaseStatementBindable?>
  ) -> AnyPublisher<Array<DatabaseRow>, TheError>
  public var featureUnload: () -> Bool
}

extension AccountDatabase: Feature {
  
  public typealias Environment = AppLifeCycle
  
  public static func environmentScope(
    _ rootEnvironment: RootEnvironment
  ) -> Environment {
    rootEnvironment.appLifeCycle
  }
  
  public static func load(
    in environment: Environment,
    using features: FeatureFactory,
    cancellables: Cancellables
  ) -> AccountDatabase {
    let diagnostics: Diagnostics = features.instance()
    let accountSession: AccountSession = features.instance()
    let accountsDataStore: AccountsDataStore = features.instance()
    let databaseConnectionSubject: CurrentValueSubject<DatabaseConnection?, TheError> = .init(nil)
    
    accountSession
      .statePublisher()
      .compactMap { sessionState -> AnyPublisher<DatabaseConnection?, Never>? in
        switch sessionState {
        // swiftlint:disable:next explicit_type_interface
        case let .authorized(account, token: _):
          if databaseConnectionSubject.value == nil {
            // create database connection
            switch accountsDataStore.accountDatabaseConnection(account.localID) {
            // swiftlint:disable:next explicit_type_interface
            case let .success(connection):
              return Just(connection)
                .eraseToAnyPublisher()
            // swiftlint:disable:next explicit_type_interface
            case let .failure(error):
              diagnostics.debugLog(
                "Failed to open database for account: \(account.localID)"
                  + " - status: \(error.osStatus.map(String.init(describing:)) ?? "N/A")"
              )
              return Just(nil)
                .eraseToAnyPublisher()
            }
          } else if databaseConnectionSubject.value?.accountID() != account.localID {
            assertionFailure("AccontDatabase has to be unloaded when switching account")
            return Just(nil) // close current database connection as fallback
              .eraseToAnyPublisher()
          } else {
            return nil // keep current database connection
          }
          
        case .authorizationRequired:
          // drop connection only when going to background
          return environment
            .lifeCyclePublisher()
            .filter { $0 == .didEnterBackground }
            .map { _ -> DatabaseConnection? in nil }
            .eraseToAnyPublisher()
          
        case .none:
          return Just(nil)
            .eraseToAnyPublisher()
        }
      }
      .switchToLatest()
      .sink { connection in
        databaseConnectionSubject.value?.close()
        databaseConnectionSubject.send(connection)
      }
      .store(in: cancellables)
    
    func execute(
      statement: DatabaseStatement,
      with bindings: Array<DatabaseStatementBindable?>
    ) -> AnyPublisher<Void, TheError> {
      databaseConnectionSubject
        .map { connection -> AnyPublisher<Void, TheError> in
          if let connection: DatabaseConnection = connection {
            return connection.execute(statement, bindings)
          } else {
            return Fail<Void, TheError>(error: .databaseConnectionClosed())
              .eraseToAnyPublisher()
          }
        }
        .switchToLatest()
        .eraseToAnyPublisher()
    }
    
    func loadRows(
      matching statement: DatabaseStatement,
      with bindings: Array<DatabaseStatementBindable?>
    ) -> AnyPublisher<Array<DatabaseRow>, TheError> {
      databaseConnectionSubject
        .map { connection -> AnyPublisher<Array<DatabaseRow>, TheError> in
          if let connection: DatabaseConnection = connection {
            return connection.loadRows(statement, bindings)
          } else {
            return Fail<Array<DatabaseRow>, TheError>(error: .databaseConnectionClosed())
              .eraseToAnyPublisher()
          }
        }
        .switchToLatest()
        .eraseToAnyPublisher()
    }
    
    func featureUnload() -> Bool {
      databaseConnectionSubject.value?.close()
      databaseConnectionSubject.send(completion: .finished)
      return true
    }
    
    return Self(
      execute: execute(statement:with:),
      loadRows: loadRows(matching:with:),
      featureUnload: featureUnload
    )
  }
  
  #if DEBUG
  public static var placeholder: AccountDatabase {
    Self(
      execute: Commons.placeholder("You have to provide mocks for used methods"),
      loadRows: Commons.placeholder("You have to provide mocks for used methods"),
      featureUnload: Commons.placeholder("You have to provide mocks for used methods")
    )
  }
  #endif
}
