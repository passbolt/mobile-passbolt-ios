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

/// Covers the reconciliation that replaced the previous truncate-and-rebuild approach. Because a
/// resource's `modified` does not advance when its share, folder, favorite or refresh state changes,
/// those must be reconciled for every resource on every refresh — including resources passed in as
/// `unchanged` (decryption skipped). Permission tests exercise the access reconciliation; the
/// folder/favorite/state tests exercise the temp-table reconcile UPDATE applied to `unchanged` resources.
final internal class ResourcesStoreDatabaseOperationTests: DatabaseOperationsTestCase {

  override internal func commonPrepare() async throws {
    try await super.commonPrepare()
    try await self.storeUsers([currentUser])
    try await self.storeResourceTypes([testResourceType])
  }

  internal func test_storeUnchanged_removesRevokedUserPermission() async throws {
    let resource: ResourceDTO = .create(resourceTypeId: testResourceType.id, name: "Shared") { resource in
      resource.permissions = [
        .userToResource(id: .init(), userID: self.currentUser.id, resourceID: resource.id, permission: .owner)
      ]
    }
    try await self.storeResources([resource])
    XCTAssertEqual(try self.userPermissionCount(for: resource.id), 1, "Permission should be stored initially.")

    // The share is revoked server-side without bumping `modified`, so the resource arrives as unchanged.
    var revoked: ResourceDTO = resource
    revoked.permissions = .init()
    try await self.storeResources([], unchanged: [revoked])

    XCTAssertEqual(try self.userPermissionCount(for: resource.id), 0, "Revoked permission must be removed.")
  }

  internal func test_storeUnchanged_updatesChangedPermissionLevel() async throws {
    let resource: ResourceDTO = .create(resourceTypeId: testResourceType.id, name: "Shared") { resource in
      resource.permissions = [
        .userToResource(id: .init(), userID: self.currentUser.id, resourceID: resource.id, permission: .owner)
      ]
    }
    try await self.storeResources([resource])

    var downgraded: ResourceDTO = resource
    downgraded.permissions = [
      .userToResource(id: .init(), userID: self.currentUser.id, resourceID: resource.id, permission: .read)
    ]
    try await self.storeResources([], unchanged: [downgraded])

    XCTAssertEqual(
      try self.userPermissionLevel(for: resource.id),
      Permission.read.rawValue,
      "Permission level change must be reflected after an unchanged refresh."
    )
  }

  internal func test_storeChanged_removesStalePermission() async throws {
    let resource: ResourceDTO = .create(resourceTypeId: testResourceType.id, name: "Shared") { resource in
      resource.permissions = [
        .userToResource(id: .init(), userID: self.currentUser.id, resourceID: resource.id, permission: .owner)
      ]
    }
    try await self.storeResources([resource])
    XCTAssertEqual(try self.userPermissionCount(for: resource.id), 1)

    // Re-store as changed with no permissions: stale rows must be cleared (no longer relying on the
    // users/groups truncate cascade for cleanup).
    var cleared: ResourceDTO = resource
    cleared.permissions = .init()
    try await self.storeResources([cleared])

    XCTAssertEqual(try self.userPermissionCount(for: resource.id), 0, "Changed store must drop stale permissions.")
  }

  internal func test_storeUnchanged_removesRevokedGroupPermission() async throws {
    try await self.storeUserGroups([.init(id: .mock_2, name: "Team", userReferences: [.init(id: currentUser.id)])])
    let resource: ResourceDTO = .create(resourceTypeId: testResourceType.id, name: "Shared") { resource in
      resource.permissions = [
        .userGroupToResource(id: .init(), userGroupID: .mock_2, resourceID: resource.id, permission: .read)
      ]
    }
    try await self.storeResources([resource])
    XCTAssertEqual(try self.groupPermissionCount(for: resource.id), 1)

    var revoked: ResourceDTO = resource
    revoked.permissions = .init()
    try await self.storeResources([], unchanged: [revoked])

    XCTAssertEqual(try self.groupPermissionCount(for: resource.id), 0, "Revoked group permission must be removed.")
  }

  // MARK: - Folder / favorite / state reconciliation

  internal func test_storeUnchanged_movesResourceToNewParentFolder() async throws {
    try await self.storeFolders([self.folder(.mock_1), self.folder(.mock_2)])
    let resource: ResourceDTO = .create(resourceTypeId: testResourceType.id, name: "Filed") { resource in
      resource.parentFolderID = .mock_1
    }
    try await self.storeResources([resource])
    XCTAssertTrue(
      try self.resource(resource.id, hasParentFolder: .mock_1),
      "Resource should start in the first folder."
    )

    // Moving a resource between folders never bumps `modified`, so it arrives as unchanged.
    var moved: ResourceDTO = resource
    moved.parentFolderID = .mock_2
    try await self.storeResources([], unchanged: [moved])

    XCTAssertTrue(
      try self.resource(resource.id, hasParentFolder: .mock_2),
      "Reconcile must move the resource to the new folder."
    )
  }

  internal func test_storeUnchanged_clearsParentFolderWhenFolderVanished() async throws {
    try await self.storeFolders([self.folder(.mock_1)])
    let resource: ResourceDTO = .create(resourceTypeId: testResourceType.id, name: "Filed") { resource in
      resource.parentFolderID = .mock_1
    }
    try await self.storeResources([resource])
    XCTAssertTrue(try self.resource(resource.id, hasParentFolder: .mock_1))

    // The parent folder is absent from this refresh (never stored), so the reconcile guard must resolve
    // it to NULL rather than violating the parentFolderID foreign key.
    var orphaned: ResourceDTO = resource
    orphaned.parentFolderID = .mock_2
    try await self.storeResources([], unchanged: [orphaned])

    XCTAssertTrue(try self.resourceHasNoParentFolder(resource.id), "A vanished parent folder must reconcile to NULL.")
  }

  internal func test_storeUnchanged_updatesFavorite() async throws {
    let resource: ResourceDTO = .create(resourceTypeId: testResourceType.id, name: "Faved")
    try await self.storeResources([resource])
    XCTAssertTrue(try self.resourceHasNoFavorite(resource.id), "Resource should start without a favorite.")

    // Favoriting never bumps `modified`, so the flip arrives as unchanged.
    let favoriteID: Resource.Favorite.ID = .init()
    var favorited: ResourceDTO = resource
    favorited.favoriteID = favoriteID
    try await self.storeResources([], unchanged: [favorited])
    XCTAssertTrue(try self.resource(resource.id, hasFavorite: favoriteID), "Reconcile must set the favorite id.")

    // Un-favoriting likewise arrives as unchanged and must clear it.
    var unfavorited: ResourceDTO = favorited
    unfavorited.favoriteID = .none
    try await self.storeResources([], unchanged: [unfavorited])
    XCTAssertTrue(try self.resourceHasNoFavorite(resource.id), "Reconcile must clear a removed favorite.")
  }

  internal func test_storeUnchanged_clearsPendingRefreshState() async throws {
    let resource: ResourceDTO = .create(resourceTypeId: testResourceType.id, name: "Pending")
    try await self.storeResources([resource])
    // A refresh marks every resource `waitingForUpdate` up front; unchanged resources skip decryption, so
    // the reconcile inside the store is what must clear that pending state (else cleanup would delete it).
    try self.setState(.waitingForUpdate, for: resource.id)
    XCTAssertTrue(try self.resource(resource.id, hasState: .waitingForUpdate), "Precondition: state marked pending.")

    try await self.storeResources([], unchanged: [resource])

    XCTAssertTrue(try self.resourceHasNoState(resource.id), "Reconcile must clear the pending refresh state.")
  }

  // MARK: - Helpers

  private func groupPermissionCount(for resourceID: Resource.ID) throws -> Int {
    guard let connection: SQLiteConnection = self.databaseConnection
    else { XCTFail("Missing test connection"); return -1 }
    return try connection.fetch(
      .statement("SELECT userGroupID FROM userGroupsResources WHERE resourceID = ?1;", arguments: resourceID)
    )
    .count
  }

  private func userPermissionCount(for resourceID: Resource.ID) throws -> Int {
    guard let connection: SQLiteConnection = self.databaseConnection
    else { XCTFail("Missing test connection"); return -1 }
    return try connection.fetch(
      .statement("SELECT userID FROM usersResources WHERE resourceID = ?1;", arguments: resourceID)
    )
    .count
  }

  private func userPermissionLevel(for resourceID: Resource.ID) throws -> Int? {
    guard let connection: SQLiteConnection = self.databaseConnection
    else { XCTFail("Missing test connection"); return nil }
    let rows: Array<SQLiteRow> = try connection.fetch(
      .statement("SELECT permission FROM usersResources WHERE resourceID = ?1;", arguments: resourceID)
    )
    guard let row: SQLiteRow = rows.first
    else { return nil }
    return row.permission as Int?
  }

  private func folder(_ id: ResourceFolder.ID) -> ResourceFolderDTO {
    .init(id: id, parentID: nil, name: "Folder \(id)", permission: .owner, permissions: .init())
  }

  private func setState(_ state: ResourceState, for resourceID: Resource.ID) throws {
    guard let connection: SQLiteConnection = self.databaseConnection
    else { XCTFail("Missing test connection"); return }
    try connection.execute(
      .statement("UPDATE resources SET state = ?1 WHERE id = ?2;", arguments: state.rawValue, resourceID)
    )
  }

  private func resource(_ resourceID: Resource.ID, hasParentFolder folderID: ResourceFolder.ID) throws -> Bool {
    try self.rowExists(
      .statement("SELECT id FROM resources WHERE id = ?1 AND parentFolderID = ?2;", arguments: resourceID, folderID)
    )
  }

  private func resourceHasNoParentFolder(_ resourceID: Resource.ID) throws -> Bool {
    try self.rowExists(
      .statement("SELECT id FROM resources WHERE id = ?1 AND parentFolderID IS NULL;", arguments: resourceID)
    )
  }

  private func resource(_ resourceID: Resource.ID, hasFavorite favoriteID: Resource.Favorite.ID) throws -> Bool {
    try self.rowExists(
      .statement("SELECT id FROM resources WHERE id = ?1 AND favoriteID = ?2;", arguments: resourceID, favoriteID)
    )
  }

  private func resourceHasNoFavorite(_ resourceID: Resource.ID) throws -> Bool {
    try self.rowExists(
      .statement("SELECT id FROM resources WHERE id = ?1 AND favoriteID IS NULL;", arguments: resourceID)
    )
  }

  private func resource(_ resourceID: Resource.ID, hasState state: ResourceState) throws -> Bool {
    try self.rowExists(
      .statement("SELECT id FROM resources WHERE id = ?1 AND state = ?2;", arguments: resourceID, state.rawValue)
    )
  }

  private func resourceHasNoState(_ resourceID: Resource.ID) throws -> Bool {
    try self.rowExists(
      .statement("SELECT id FROM resources WHERE id = ?1 AND state IS NULL;", arguments: resourceID)
    )
  }

  private func rowExists(_ statement: SQLiteStatement) throws -> Bool {
    guard let connection: SQLiteConnection = self.databaseConnection
    else { XCTFail("Missing test connection"); return false }
    return try connection.fetch(statement).isEmpty == false
  }
}
