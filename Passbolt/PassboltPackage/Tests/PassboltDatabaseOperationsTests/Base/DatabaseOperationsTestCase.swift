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
import Database
import DatabaseOperations
import FeatureScopes
import Session
import TestExtensions
import XCTest

@testable import PassboltDatabaseOperations

/// Base test case for database operation tests using an in-memory SQLite database.
/// Subclasses should override `registerOperations()` to register additional operations under test.
internal class DatabaseOperationsTestCase: FeaturesTestCase {

  /// Override in subclasses to register additional database operations under test.
  internal func registerOperations() {
    // to override
  }

  /// Sets up an in-memory database with all migrations applied,
  /// registers store operations for test data population,
  /// and configures the session scope with mock account.
  final private func setupDatabase() throws {
    let connection: SQLiteConnection = try SQLiteConnection.open(
      migrations: SQLiteMigration.allCases
    )

    register(
      { $0.usePassboltUsersStoreDatabaseOperation() },
      for: UsersStoreDatabaseOperation.self
    )
    register(
      { $0.usePassboltUserGroupsStoreDatabaseOperation() },
      for: UserGroupsStoreDatabaseOperation.self
    )
    register(
      { $0.usePassboltResourceFoldersStoreDatabaseOperation() },
      for: ResourceFoldersStoreDatabaseOperation.self
    )
    register(
      { $0.usePassboltResourceTypesStoreDatabaseOperation() },
      for: ResourceTypesStoreDatabaseOperation.self
    )
    register(
      { $0.usePassboltResourcesStoreDatabaseOperation() },
      for: ResourcesStoreDatabaseOperation.self
    )

    registerOperations()

    set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_1
      )
    )

    patch(
      \SessionDatabase.connection,
      with: { connection }
    )
  }

  override open func commonPrepare() async throws {
    try await super.commonPrepare()
    try setupDatabase()
  }

  // MARK: - Store helpers

  final internal func storeUsers(_ users: Array<UserDSO>) async throws {
    let operation: UsersStoreDatabaseOperation = try testedInstance()
    try await operation(users)
  }

  final internal func storeUserGroups(_ groups: Array<UserGroupDTO>) async throws {
    let operation: UserGroupsStoreDatabaseOperation = try testedInstance()
    try await operation(groups)
  }

  final internal func storeFolders(_ folders: Array<ResourceFolderDTO>) async throws {
    let operation: ResourceFoldersStoreDatabaseOperation = try testedInstance()
    try await operation(folders)
  }

  final internal func storeResourceTypes(_ types: Array<ResourceType>) async throws {
    let operation: ResourceTypesStoreDatabaseOperation = try testedInstance()
    try await operation(types)
  }

  final internal func storeResources(_ resources: Array<ResourceDTO>) async throws {
    let operation: ResourcesStoreDatabaseOperation = try testedInstance()
    try await operation(resources)
  }
}
