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

/// Covers the switch from truncate-and-reinsert to upsert + delete-only-vanished. The key guarantee is
/// that re-storing the same users no longer cascade-deletes surviving users' resource permissions.
final internal class UsersStoreDatabaseOperationTests: DatabaseOperationsTestCase {

  internal func test_store_removesVanishedUsersAndKeepsSurvivors() async throws {
    try await self.storeUsers([currentUser, .mock_frances])
    XCTAssertEqual(try self.userCount(), 2)

    try await self.storeUsers([currentUser])

    XCTAssertEqual(try self.userCount(), 1)
    XCTAssertTrue(try self.userExists(currentUser.id), "Surviving user must be kept.")
    XCTAssertFalse(try self.userExists(UserDSO.mock_frances.id), "Vanished user must be removed.")
  }

  internal func test_store_preservesSurvivingUsersResourcePermissions() async throws {
    try await self.storeUsers([currentUser])
    try await self.storeResourceTypes([testResourceType])
    let resource: ResourceDTO = .create(resourceTypeId: testResourceType.id, name: "Shared") { resource in
      resource.permissions = [
        .userToResource(id: .init(), userID: self.currentUser.id, resourceID: resource.id, permission: .owner)
      ]
    }
    try await self.storeResources([resource])
    XCTAssertEqual(try self.userPermissionCount(for: resource.id), 1)

    // A subsequent users refresh that still contains the user must NOT wipe the permission. The old
    // `DELETE FROM users;` approach cascade-deleted it, forcing a full per-resource rebuild every time.
    try await self.storeUsers([currentUser])

    XCTAssertEqual(
      try self.userPermissionCount(for: resource.id),
      1,
      "Re-storing surviving users must not cascade-delete their resource permissions."
    )
  }

  internal func test_store_removesResourcePermissionsOfVanishedUser() async throws {
    try await self.storeUsers([currentUser, .mock_frances])
    try await self.storeResourceTypes([testResourceType])
    let resource: ResourceDTO = .create(resourceTypeId: testResourceType.id, name: "Shared") { resource in
      resource.permissions = [
        .userToResource(id: .init(), userID: self.currentUser.id, resourceID: resource.id, permission: .owner),
        .userToResource(id: .init(), userID: UserDSO.mock_frances.id, resourceID: resource.id, permission: .read),
      ]
    }
    try await self.storeResources([resource])
    XCTAssertEqual(try self.userPermissionCount(for: resource.id), 2)

    // frances is gone from the response: her resource permission cascades away, the owner's stays.
    try await self.storeUsers([currentUser])

    XCTAssertEqual(try self.userPermissionCount(for: resource.id), 1, "Vanished user's permission must be removed.")
  }

  internal func test_store_ignoresEmptyInput() async throws {
    try await self.storeUsers([currentUser, .mock_frances])
    XCTAssertEqual(try self.userCount(), 2)

    // An empty response is a fetch/filter anomaly (the current user always survives `asFilteredDSO`), so
    // it must be ignored rather than cascade-wiping every user and their permissions.
    try await self.storeUsers([])

    XCTAssertEqual(try self.userCount(), 2, "Empty input must not delete existing users.")
  }

  // MARK: - Helpers

  private func userCount() throws -> Int {
    guard let connection: SQLiteConnection = self.databaseConnection
    else {
      XCTFail("Missing test connection")
      return -1
    }
    return try connection.fetch(.statement("SELECT id FROM users;")).count
  }

  private func userExists(_ id: User.ID) throws -> Bool {
    guard let connection: SQLiteConnection = self.databaseConnection
    else {
      XCTFail("Missing test connection")
      return false
    }
    return
      try connection
      .fetch(
        .statement("SELECT id FROM users WHERE id = ?1;", arguments: id)
      )
      .isEmpty == false
  }

  private func userPermissionCount(for resourceID: Resource.ID) throws -> Int {
    guard let connection: SQLiteConnection = self.databaseConnection
    else {
      XCTFail("Missing test connection")
      return -1
    }
    return
      try connection.fetch(
        .statement("SELECT userID FROM usersResources WHERE resourceID = ?1;", arguments: resourceID)
      )
      .count
  }
}
