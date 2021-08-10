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

import Crypto
import CryptoKit
import Features

import struct Foundation.Data

public struct AccountDatabase {

  public var fetchLastUpdate: FetchLastUpdateOperation
  public var saveLastUpdate: SaveLastUpdateOperation

  public var storeResources: StoreResourcesOperation
  public var storeResourcesTypes: StoreResourcesTypesOperation
  public var fetchListViewResources: FetchListViewResourcesOperation
  public var fetchDetailsViewResources: FetchDetailsViewResourcesOperation

  public var featureUnload: () -> Bool
}

extension AccountDatabase {

  internal typealias DatabaseConnection = (
    accountID: Account.LocalID,
    connection: SQLiteConnection
  )
}

extension AccountDatabase: Feature {

  public static func load(
    in environment: Environment,
    using features: FeatureFactory,
    cancellables: Cancellables
  ) -> AccountDatabase {
    let appLifeCycle: AppLifeCycle = environment.appLifeCycle

    let diagnostics: Diagnostics = features.instance()
    let accountSession: AccountSession = features.instance()
    let accountsDataStore: AccountsDataStore = features.instance()
    let passphraseCache: PassphraseCache = features.instance()

    let databaseConnectionSubject: CurrentValueSubject<DatabaseConnection?, TheError> = .init(nil)

    accountSession
      .statePublisher()
      .compactMap { sessionState -> AnyPublisher<DatabaseConnection?, Never>? in
        switch sessionState {
        case let .authorized(account):
          if databaseConnectionSubject.value == nil {
            return
              passphraseCache
              .passphrasePublisher(account.localID)
              .first()
              .map { passphrase -> String? in
                if let passphraseData: Data = passphrase?.rawValue.data(using: .utf8) {
                  // prepare hash from passphrase
                  // to be used as database key
                  return
                    SHA512
                    .hash(data: passphraseData)
                    .compactMap { String(format: "%02x", $0) }
                    .joined()
                }
                else {
                  diagnostics.diagnosticLog(
                    "Failed to open database for account due to invalid or missing database key"
                  )
                  return nil
                }
              }
              .map { databaseKey -> AnyPublisher<DatabaseConnection?, Never> in
                guard let databaseKey: String = databaseKey
                else {
                  // can't open without key
                  return Just(nil)
                    .eraseToAnyPublisher()
                }

                // create new database connection
                switch accountsDataStore.accountDatabaseConnection(account.localID, databaseKey) {
                case let .success(connection):
                  return Just((accountID: account.localID, connection: connection))
                    .eraseToAnyPublisher()
                case let .failure(error) where error.identifier == .databaseMigrationError:
                  diagnostics.debugLog(
                    "Failed to migrate database for account: \(account.localID), deleting...\n"
                      + error.description
                  )
                  return Just(nil)
                    .eraseToAnyPublisher()
                case let .failure(error):
                  diagnostics.debugLog(
                    "Failed to open database for account: \(account.localID)\n"
                      + error.description
                  )
                  return Just(nil)
                    .eraseToAnyPublisher()
                }
              }
              .switchToLatest()
              .eraseToAnyPublisher()
          }
          else if databaseConnectionSubject.value?.accountID != account.localID {
            assertionFailure("AccountDatabase has to be unloaded when switching account")
            return Just(nil)  // close current database connection as fallback
              .eraseToAnyPublisher()
          }
          else {
            return nil  // keep current database connection
          }

        case .authorizationRequired:
          // drop connection only when going to background
          return
            appLifeCycle
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
        // previous connection is automatically closed when dealocating
        databaseConnectionSubject.send(connection)
      }
      .store(in: cancellables)

    let currentConnectionPublisher: AnyPublisher<SQLiteConnection, TheError> =
      databaseConnectionSubject
      .map { connection -> AnyPublisher<SQLiteConnection, TheError> in
        if let connection: DatabaseConnection = connection {
          return Just(connection.connection)
            .setFailureType(to: TheError.self)
            .eraseToAnyPublisher()
        }
        else {
          return Fail<SQLiteConnection, TheError>(
            error: .databaseConnectionClosed(
              databaseErrorMessage: "There is no active database connection"
            )
          )
          .eraseToAnyPublisher()
        }
      }
      .switchToLatest()
      .eraseToAnyPublisher()

    func featureUnload() -> Bool {
      // previous connection is automatically closed when dealocating
      databaseConnectionSubject.send(completion: .finished)
      return true
    }

    return Self(
      fetchLastUpdate: FetchLastUpdateOperation.using(currentConnectionPublisher),
      saveLastUpdate: SaveLastUpdateOperation.using(currentConnectionPublisher),
      storeResources: StoreResourcesOperation.using(currentConnectionPublisher),
      storeResourcesTypes: StoreResourcesTypesOperation.using(currentConnectionPublisher),
      fetchListViewResources: FetchListViewResourcesOperation.using(currentConnectionPublisher),
      fetchDetailsViewResources: FetchDetailsViewResourcesOperation.using(currentConnectionPublisher),
      featureUnload: featureUnload
    )
  }

  #if DEBUG
  public static var placeholder: AccountDatabase {
    Self(
      fetchLastUpdate: .placeholder,
      saveLastUpdate: .placeholder,
      storeResources: .placeholder,
      storeResourcesTypes: .placeholder,
      fetchListViewResources: .placeholder,
      fetchDetailsViewResources: .placeholder,
      featureUnload: Commons.placeholder("You have to provide mocks for used methods")
    )
  }
  #endif
}
