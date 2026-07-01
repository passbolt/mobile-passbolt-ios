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

/// Covers delete-only-vanished + permission reconciliation for folders. Folders absent from the server
/// response must be removed along with their permissions; surviving folders keep theirs, with their
/// permissions reconciled every refresh.
final internal class ResourceFoldersStoreDatabaseOperationTests: DatabaseOperationsTestCase {

  override internal func commonPrepare() async throws {
    try await super.commonPrepare()
    try await self.storeUsers([currentUser, thirdUser])
  }

  internal func test_store_removesVanishedFoldersAndKeepsSurvivors() async throws {
    try await self.storeFolders([self.folder(.mock_1), self.folder(.mock_2)])
    XCTAssertEqual(try self.count("SELECT id FROM resourceFolders"), 2)

    try await self.storeFolders([self.folder(.mock_1)])

    XCTAssertEqual(try self.count("SELECT id FROM resourceFolders"), 1)
    XCTAssertTrue(try self.exists("SELECT id FROM resourceFolders WHERE id = ?1", ResourceFolder.ID.mock_1))
    XCTAssertFalse(try self.exists("SELECT id FROM resourceFolders WHERE id = ?1", ResourceFolder.ID.mock_2))
  }

  internal func test_store_removesPermissionsOfVanishedFolder() async throws {
    try await self.storeFolders([self.folder(.mock_2, users: [currentUser.id])])
    XCTAssertEqual(try self.folderPermissionCount(.mock_2), 1)

    try await self.storeFolders([self.folder(.mock_1)])

    XCTAssertEqual(try self.folderPermissionCount(.mock_2), 0)
  }

  internal func test_store_reconcilesPermissionsOfSurvivingFolder() async throws {
    try await self.storeFolders([self.folder(.mock_1, users: [currentUser.id, thirdUser.id])])
    XCTAssertEqual(try self.folderPermissionCount(.mock_1), 2)

    // Same folder, but one share revoked server-side — must be reflected without truncating everything.
    try await self.storeFolders([self.folder(.mock_1, users: [currentUser.id])])

    XCTAssertEqual(try self.folderPermissionCount(.mock_1), 1)
  }

  // MARK: - Helpers

  private func folder(_ id: ResourceFolder.ID, users: Array<User.ID> = []) -> ResourceFolderDTO {
    .init(
      id: id,
      parentID: nil,
      name: "Folder \(id)",
      permission: .owner,
      permissions: .init(
        users.map { .userToFolder(id: .init(), userID: $0, folderID: id, permission: .owner) }
      )
    )
  }

  private func folderPermissionCount(_ folderID: ResourceFolder.ID) throws -> Int {
    try self.count("SELECT userID FROM usersResourceFolders WHERE resourceFolderID = ?1", folderID)
  }

  private func count(_ sql: StaticString, _ argument: SQLiteValueConvertible? = nil) throws -> Int {
    guard let connection: SQLiteConnection = self.databaseConnection
    else { XCTFail("Missing test connection"); return -1 }
    let statement: SQLiteStatement = argument.map { .statement(sql, arguments: $0) } ?? .statement(sql)
    return try connection.fetch(statement).count
  }

  private func exists(_ sql: StaticString, _ argument: SQLiteValueConvertible) throws -> Bool {
    try self.count(sql, argument) > 0
  }
}
