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

/// Covers delete-only-vanished + membership reconciliation for user groups. Groups absent from the
/// server response must be removed along with their memberships and permissions; surviving groups keep
/// theirs, and their membership is reconciled every refresh.
final internal class UserGroupsStoreDatabaseOperationTests: DatabaseOperationsTestCase {

  override internal func commonPrepare() async throws {
    try await super.commonPrepare()
    try await self.storeUsers([currentUser, otherUser])
  }

  internal func test_store_removesVanishedGroupsAndKeepsSurvivors() async throws {
    try await self.storeUserGroups([self.group(.mock_1), self.group(.mock_2)])
    XCTAssertEqual(try self.count("SELECT id FROM userGroups"), 2)

    try await self.storeUserGroups([self.group(.mock_1)])

    XCTAssertEqual(try self.count("SELECT id FROM userGroups"), 1)
    XCTAssertTrue(try self.exists("SELECT id FROM userGroups WHERE id = ?1", UserGroup.ID.mock_1))
    XCTAssertFalse(try self.exists("SELECT id FROM userGroups WHERE id = ?1", UserGroup.ID.mock_2))
  }

  internal func test_store_reconcilesMembershipOfSurvivingGroup() async throws {
    try await self.storeUserGroups([self.group(.mock_1, members: [currentUser.id, otherUser.id])])
    XCTAssertEqual(try self.membershipCount(.mock_1), 2)

    // Same group, but one member removed server-side (which never bumps any resource `modified`).
    try await self.storeUserGroups([self.group(.mock_1, members: [currentUser.id])])

    XCTAssertEqual(try self.membershipCount(.mock_1), 1)
  }

  internal func test_store_removesResourcePermissionsOfVanishedGroup() async throws {
    let resource: ResourceDTO = try await self.storeResourceSharedWithGroup(.mock_2)
    XCTAssertEqual(try self.groupResourcePermissionCount(resource.id), 1)

    // The group is gone from the response: its resource permissions cascade away with it.
    try await self.storeUserGroups([self.group(.mock_1)])

    XCTAssertEqual(try self.groupResourcePermissionCount(resource.id), 0)
    XCTAssertFalse(try self.exists("SELECT id FROM userGroups WHERE id = ?1", UserGroup.ID.mock_2))
  }

  internal func test_store_preservesResourcePermissionsOfSurvivingGroup() async throws {
    let resource: ResourceDTO = try await self.storeResourceSharedWithGroup(.mock_2)

    // Re-storing the still-present group must not cascade-delete its resource permissions.
    try await self.storeUserGroups([self.group(.mock_2)])

    XCTAssertEqual(try self.groupResourcePermissionCount(resource.id), 1)
  }

  // MARK: - Helpers

  private func group(_ id: UserGroup.ID, members: Array<User.ID>? = nil) -> UserGroupDTO {
    .init(
      id: id,
      name: "Group \(id)",
      userReferences: (members ?? [currentUser.id]).map { .init(id: $0) }
    )
  }

  /// Stores the group, a resource type and a resource shared with that group, returning the resource.
  private func storeResourceSharedWithGroup(_ groupID: UserGroup.ID) async throws -> ResourceDTO {
    try await self.storeUserGroups([self.group(groupID)])
    try await self.storeResourceTypes([testResourceType])
    let resource: ResourceDTO = .create(resourceTypeId: testResourceType.id, name: "Shared") { resource in
      resource.permissions = [
        .userGroupToResource(id: .init(), userGroupID: groupID, resourceID: resource.id, permission: .read)
      ]
    }
    try await self.storeResources([resource])
    return resource
  }

  private func membershipCount(_ groupID: UserGroup.ID) throws -> Int {
    try self.count("SELECT userID FROM usersGroups WHERE userGroupID = ?1", groupID)
  }

  private func groupResourcePermissionCount(_ resourceID: Resource.ID) throws -> Int {
    try self.count("SELECT userGroupID FROM userGroupsResources WHERE resourceID = ?1", resourceID)
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
