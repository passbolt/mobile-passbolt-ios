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

// MARK: - Shared test data and folder scenario setup

extension DatabaseOperationsTestCase {

  internal var currentUser: UserDSO { .mock_ada }
  internal var otherUser: UserDSO { .mock_1 }
  internal var thirdUser: UserDSO { .mock_frances }

  internal var testFolderID: ResourceFolder.ID { .mock_1 }
  internal var testParentFolderID: ResourceFolder.ID { .mock_1 }
  internal var testChildFolderID: ResourceFolder.ID { .mock_2 }
  internal var testGroupID: UserGroup.ID { .mock_2 }

  // MARK: - Scenario setup helpers

  /// Folder owned only by the current user. Expected: not shared.
  internal func setupPrivateFolder() async throws {
    try await storeUsers([currentUser])
    try await storeFolders([
      .init(
        id: testFolderID,
        parentID: nil,
        name: "Private Folder",
        permission: .owner,
        permissions: [
          .userToFolder(id: .init(), userID: currentUser.id, folderID: testFolderID, permission: .owner)
        ]
      )
    ])
  }

  /// Folder shared between current user and another user. Expected: shared.
  internal func setupFolderSharedWithOtherUser() async throws {
    try await storeUsers([currentUser, otherUser])
    try await storeFolders([
      .init(
        id: testFolderID,
        parentID: nil,
        name: "Shared Folder",
        permission: .owner,
        permissions: [
          .userToFolder(id: .init(), userID: currentUser.id, folderID: testFolderID, permission: .owner),
          .userToFolder(id: .init(), userID: otherUser.id, folderID: testFolderID, permission: .read),
        ]
      )
    ])
  }

  /// Folder with a group permission where the group has multiple members. Expected: shared.
  internal func setupFolderWithMultiMemberGroup() async throws {
    try await storeUsers([currentUser, otherUser])
    try await storeUserGroups([
      .init(id: testGroupID, name: "Team", userReferences: [.init(id: currentUser.id), .init(id: otherUser.id)])
    ])
    try await storeFolders([
      .init(
        id: testFolderID,
        parentID: nil,
        name: "Group Folder",
        permission: .owner,
        permissions: [
          .userToFolder(id: .init(), userID: currentUser.id, folderID: testFolderID, permission: .owner),
          .userGroupToFolder(id: .init(), userGroupID: testGroupID, folderID: testFolderID, permission: .read),
        ]
      )
    ])
  }

  /// Folder with a group permission where the group has only one member. Expected: not shared.
  internal func setupFolderWithSingleMemberGroup() async throws {
    try await storeUsers([currentUser])
    try await storeUserGroups([
      .init(id: testGroupID, name: "Solo Group", userReferences: [.init(id: currentUser.id)])
    ])
    try await storeFolders([
      .init(
        id: testFolderID,
        parentID: nil,
        name: "Solo Group Folder",
        permission: .owner,
        permissions: [
          .userToFolder(id: .init(), userID: currentUser.id, folderID: testFolderID, permission: .owner),
          .userGroupToFolder(id: .init(), userGroupID: testGroupID, folderID: testFolderID, permission: .read),
        ]
      )
    ])
  }

  /// Folder shared with another user and a multi-member group. Expected: shared.
  internal func setupFolderWithOtherUserAndGroup() async throws {
    try await storeUsers([currentUser, otherUser, thirdUser])
    try await storeUserGroups([
      .init(id: testGroupID, name: "Team", userReferences: [.init(id: otherUser.id), .init(id: thirdUser.id)])
    ])
    try await storeFolders([
      .init(
        id: testFolderID,
        parentID: nil,
        name: "Multi Shared Folder",
        permission: .owner,
        permissions: [
          .userToFolder(id: .init(), userID: currentUser.id, folderID: testFolderID, permission: .owner),
          .userToFolder(id: .init(), userID: otherUser.id, folderID: testFolderID, permission: .read),
          .userGroupToFolder(id: .init(), userGroupID: testGroupID, folderID: testFolderID, permission: .read),
        ]
      )
    ])
  }

  /// Folder with a single-member group where the only member is the current user. Expected: not shared.
  internal func setupFolderWithSingleMemberGroupOfCurrentUser() async throws {
    try await storeUsers([currentUser])
    try await storeUserGroups([
      .init(id: testGroupID, name: "My Group", userReferences: [.init(id: currentUser.id)])
    ])
    try await storeFolders([
      .init(
        id: testFolderID,
        parentID: nil,
        name: "My Group Folder",
        permission: .owner,
        permissions: [
          .userToFolder(id: .init(), userID: currentUser.id, folderID: testFolderID, permission: .owner),
          .userGroupToFolder(id: .init(), userGroupID: testGroupID, folderID: testFolderID, permission: .read),
        ]
      )
    ])
  }

  /// Shared parent folder with a private child folder. For testing path shared flags.
  internal func setupNestedFolderWithSharedParent() async throws {
    try await storeUsers([currentUser, otherUser])
    try await storeFolders([
      .init(
        id: testParentFolderID,
        parentID: nil,
        name: "Shared Parent",
        permission: .owner,
        permissions: [
          .userToFolder(id: .init(), userID: currentUser.id, folderID: testParentFolderID, permission: .owner),
          .userToFolder(id: .init(), userID: otherUser.id, folderID: testParentFolderID, permission: .read),
        ]
      ),
      .init(
        id: testChildFolderID,
        parentID: testParentFolderID,
        name: "Private Child",
        permission: .owner,
        permissions: [
          .userToFolder(id: .init(), userID: currentUser.id, folderID: testChildFolderID, permission: .owner)
        ]
      ),
    ])
  }
}
