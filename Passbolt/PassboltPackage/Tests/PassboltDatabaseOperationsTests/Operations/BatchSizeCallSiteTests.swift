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
import Database
import DatabaseOperations
import XCTest

@testable import PassboltDatabaseOperations

/// End-to-end check that the `SQLiteBatch.maxRows(perRowBindings:)` call sites size their multi-row
/// statements safely against the real bundled SQLCipher build. Each test feeds one full chunk's worth
/// of rows to the widest upsert in an operation and runs it against the in-memory database; a chunk
/// whose text or parameter count exceeds SQLCipher's limits (`SQLITE_MAX_SQL_LENGTH` is the tighter one
/// here — see `SQLiteBatch`) throws, failing the test. Row counts derive from the current sizing, so
/// they self-adjust if the budgets change.
///
/// Note: because the sizing keeps headroom under the hard limits, these verify the *current* sizing is
/// safe but do not catch a future off-by-one column drift on their own — see `SQLiteBatchTests` for the
/// per-binding invariants.
final internal class BatchSizeCallSiteTests: DatabaseOperationsTestCase {

  // One more than a full chunk for the given per-row bindings, so the first chunk is packed to the limit.
  private func chunkFillingCount(perRowBindings: Int) -> Int {
    SQLiteBatch.maxRows(perRowBindings: perRowBindings) + 1
  }

  private func rowCount(_ countStatement: SQLiteStatement) throws -> Int {
    guard let connection: SQLiteConnection = self.databaseConnection
    else {
      XCTFail("Missing test connection")
      return -1
    }
    return try connection.fetch(countStatement).count
  }

  // users upsert: 8 host parameters/row (UsersStoreDatabaseOperation+Passbolt.swift).
  internal func test_usersStore_fullChunkStaysUnderHostParameterLimit() async throws {
    let count: Int = self.chunkFillingCount(perRowBindings: 8)
    let users: Array<UserDSO> = (0 ..< count)
      .map { (index: Int) in
        var user: UserDSO = self.currentUser
        user.id = .init()
        user.username = "batch-user-\(index)@passbolt.test"
        return user
      }

    try await self.storeUsers(users)

    XCTAssertEqual(try self.rowCount("SELECT 1 FROM users;"), count)
  }

  // resourceFolders upsert: 4 host parameters/row (ResourceFoldersStoreDatabaseOperation+Passbolt.swift).
  internal func test_foldersStore_fullChunkStaysUnderHostParameterLimit() async throws {
    let count: Int = self.chunkFillingCount(perRowBindings: 4)
    let folders: Array<ResourceFolderDTO> = (0 ..< count)
      .map { (index: Int) in
        .init(id: .init(), parentID: .none, name: "batch-folder-\(index)", permission: .owner, permissions: [])
      }

    try await self.storeFolders(folders)

    XCTAssertEqual(try self.rowCount("SELECT 1 FROM resourceFolders;"), count)
  }

  // userGroups upsert + usersGroups membership: both 2 host parameters/row
  // (UserGroupsStoreDatabaseOperation+Passbolt.swift). Memberships insert directly, so a stored user is
  // required for the FK.
  internal func test_userGroupsStore_fullChunkStaysUnderHostParameterLimit() async throws {
    try await self.storeUsers([self.currentUser])
    let count: Int = self.chunkFillingCount(perRowBindings: 2)
    let groups: Array<UserGroupDTO> = (0 ..< count)
      .map { (index: Int) in
        .init(id: .init(), name: "batch-group-\(index)", userReferences: [.init(id: self.currentUser.id)])
      }

    try await self.storeUserGroups(groups)

    XCTAssertEqual(try self.rowCount("SELECT 1 FROM userGroups;"), count)
    XCTAssertEqual(try self.rowCount("SELECT 1 FROM usersGroups;"), count)
  }

  // Widest resources upserts: resources (10/row) and resourceMetadata (8/row)
  // (ResourcesStoreDatabaseOperation+Passbolt.swift). Sizing for 8/row fills both chunks.
  internal func test_resourcesStore_fullChunkStaysUnderHostParameterLimit() async throws {
    try await self.storeResourceTypes([self.testResourceType])
    let count: Int = self.chunkFillingCount(perRowBindings: 8)
    let resources: Array<ResourceDTO> = (0 ..< count)
      .map { (index: Int) in
        .create(resourceTypeId: self.testResourceType.id, name: "batch-resource-\(index)")
      }

    try await self.storeResources(resources)

    XCTAssertEqual(try self.rowCount("SELECT 1 FROM resources;"), count)
    XCTAssertEqual(try self.rowCount("SELECT 1 FROM resourceMetadata;"), count)
  }
}
