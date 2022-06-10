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

  public var storeResources: StoreResourcesOperation
  public var storeResourcesTypes: StoreResourcesTypesOperation
  public var fetchResourceListItemDSVs: FetchResourceListItemDSVsOperation
  public var fetchResourceDetailsDSVs: FetchResourceDetailsDSVsOperation
  public var fetchResourcesTypesOperation: FetchResourcesTypesOperation
  public var fetchEditViewResourceOperation: FetchEditViewResourcesOperation
  public var storeFolders: StoreFoldersOperation
  public var fetchFolder: FetchFolderOperation
  public var fetchResourceFolderListItemDSVs: FetchResourceFolderListItemDSVsOperation
  public var fetchResourceTagList: FetchResourceTagListItemDSVOperation
  public var storeUserGroups: StoreUserGroupsOperation
  public var storeUsers: StoreUsersOperation
  public var fetchResourceUserGroupList: FetchResourceListItemDSVsUserGroupOperation

  internal var currentConnection: () async throws -> SQLiteConnection

  public var featureUnload: @FeaturesActor () async throws -> Void
}

extension AccountDatabase {

  internal typealias DatabaseConnection = (
    accountID: Account.LocalID,
    connection: SQLiteConnection
  )
}

extension AccountDatabase: LegacyFeature {

  public static func load(
    in environment: AppEnvironment,
    using features: FeatureFactory,
    cancellables: Cancellables
  ) async throws -> AccountDatabase {
    let appLifeCycle: AppLifeCycle = environment.appLifeCycle

    let accountSession: AccountSession = try await features.instance()
    let accountsDataStore: AccountsDataStore = try await features.instance()

    // always access with StorageAccessActor
    var currentDatabaseConnection: DatabaseConnection? = nil

    @StorageAccessActor func currentSQLiteConnection() async throws -> SQLiteConnection {
      switch await accountSession.currentState() {
      case let .authorized(account), let .authorizedMFARequired(account, _):
        if let currentConnection = currentDatabaseConnection, currentConnection.accountID == account.localID {
          return currentConnection.connection
        }
        else {
          let databaseKey: String = try await accountSession.databaseKey()
          let connection: SQLiteConnection = try accountsDataStore.accountDatabaseConnection(
            account.localID,
            databaseKey
          )
          currentDatabaseConnection =
            (
              accountID: account.localID,
              connection: connection
            )
          return connection
        }

      case let .authorizationRequired(account):
        throw
          SessionAuthorizationRequired
          .error(account: account)

      case .none:
        currentDatabaseConnection = .none
        throw
          SessionMissing
          .error()
      }
    }

    appLifeCycle
      .lifeCyclePublisher()
      .filter { $0 == .didEnterBackground }
      .sink { _ in
        cancellables.executeOnStorageAccessActor {
          currentDatabaseConnection = .none
        }
      }
      .store(in: cancellables)

    @FeaturesActor func featureUnload() async throws {
      // previous connection is automatically closed when dealocating
      currentDatabaseConnection = nil
    }

    return Self(
      storeResources: StoreResourcesOperation.using(currentSQLiteConnection),
      storeResourcesTypes: StoreResourcesTypesOperation.using(currentSQLiteConnection),
      fetchResourceListItemDSVs: FetchResourceListItemDSVsOperation.using(currentSQLiteConnection),
      fetchResourceDetailsDSVs: FetchResourceDetailsDSVsOperation.using(currentSQLiteConnection),
      fetchResourcesTypesOperation: FetchResourcesTypesOperation.using(currentSQLiteConnection),
      fetchEditViewResourceOperation: FetchEditViewResourcesOperation.using(currentSQLiteConnection),
      storeFolders: StoreFoldersOperation.using(currentSQLiteConnection),
      fetchFolder: FetchFolderOperation.using(currentSQLiteConnection),
      fetchResourceFolderListItemDSVs: FetchResourceFolderListItemDSVsOperation.using(currentSQLiteConnection),
      fetchResourceTagList: FetchResourceTagListItemDSVOperation.using(currentSQLiteConnection),
      storeUserGroups: StoreUserGroupsOperation.using(currentSQLiteConnection),
      storeUsers: StoreUsersOperation.using(currentSQLiteConnection),
      fetchResourceUserGroupList: FetchResourceListItemDSVsUserGroupOperation.using(currentSQLiteConnection),
      currentConnection: currentSQLiteConnection,
      featureUnload: featureUnload
    )
  }

  #if DEBUG
  public static var placeholder: AccountDatabase {
    Self(
      storeResources: .placeholder,
      storeResourcesTypes: .placeholder,
      fetchResourceListItemDSVs: .placeholder,
      fetchResourceDetailsDSVs: .placeholder,
      fetchResourcesTypesOperation: .placeholder,
      fetchEditViewResourceOperation: .placeholder,
      storeFolders: .placeholder,
      fetchFolder: .placeholder,
      fetchResourceFolderListItemDSVs: .placeholder,
      fetchResourceTagList: .placeholder,
      storeUserGroups: .placeholder,
      storeUsers: .placeholder,
      fetchResourceUserGroupList: .placeholder,
      currentConnection: unimplemented("You have to provide mocks for used methods"),
      featureUnload: unimplemented("You have to provide mocks for used methods")
    )
  }
  #endif
}
