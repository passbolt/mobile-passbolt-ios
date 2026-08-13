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
import Commons

// swift-format-ignore: AlwaysUseLowerCamelCase
extension PermissionSnapshot {

  /// Builds a snapshot describing exactly the recipients its permissions name - directly or through a group - the
  /// way a capture of the real thing does. Which recipients a snapshot describes is what tells an addition made by
  /// hand apart from one already holding a permission, so the described users are derived rather than listed.
  ///
  /// A snapshot has the same shape whether it was captured from a folder or from a resource, so the fixtures below
  /// serve both - the operator is always `.mock_ada`.
  public static func mock(
    permissions: OrderedSet<ResourcePermission>,
    groups: OrderedDictionary<UserGroup.ID, PermissionSnapshotGroup> = .init()
  ) -> Self {
    var users: OrderedDictionary<User.ID, PermissionSnapshotUser> = .init()
    for permission: ResourcePermission in permissions {
      if let userID: User.ID = permission.userID {
        users[userID] = .mock(id: userID)
      }
      else if let groupID: UserGroup.ID = permission.userGroupID {
        for memberID: User.ID in groups[groupID]?.members ?? .init() {
          users[memberID] = .mock(id: memberID)
        }
      }  // else: no other kind of recipient exists
    }
    return .init(
      permissions: permissions,
      users: users,
      groups: groups,
      created: 0
    )
  }

  /// Shared with someone other than the operator, who owns it.
  public static let mock_shared: Self = .mock(
    permissions: [
      .user(id: .mock_ada, permission: .owner, permissionID: .mock_1),
      .user(id: .mock_1, permission: .read, permissionID: .mock_2),
    ]
  )

  /// Holds nobody but the operator.
  public static let mock_private: Self = .mock(
    permissions: [
      .user(id: .mock_ada, permission: .owner, permissionID: .mock_1)
    ]
  )

  /// Shared with the operator, who only holds the update permission on it.
  public static let mock_ownedBySomeoneElse: Self = .mock(
    permissions: [
      .user(id: .mock_ada, permission: .write, permissionID: .mock_1),
      .user(id: .mock_1, permission: .owner, permissionID: .mock_2),
    ]
  )

  /// Owned by a group the operator belongs to - ownership the server honours as their own.
  public static let mock_ownedByOperatorsGroup: Self = .mock(
    permissions: [
      .user(id: .mock_ada, permission: .write, permissionID: .mock_1),
      .userGroup(id: .mock_1, permission: .owner, permissionID: .mock_2),
    ],
    groups: [
      .mock_1: .mock_owners(members: [.mock_ada, .mock_1])
    ]
  )

  /// Owned by a group the operator does not belong to.
  public static let mock_ownedByForeignGroup: Self = .mock(
    permissions: [
      .user(id: .mock_ada, permission: .write, permissionID: .mock_1),
      .userGroup(id: .mock_1, permission: .owner, permissionID: .mock_2),
    ],
    groups: [
      .mock_1: .mock_owners(members: [.mock_1])
    ]
  )
}

extension PermissionSnapshot: MockBuilder {}

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverForceUnwrap
extension PermissionSnapshotGroup {

  /// A group holding ownership, with exactly the membership the test cares about - whether the operator is among
  /// the members is what decides ownership by group.
  public static func mock_owners(
    members: OrderedSet<User.ID>
  ) -> Self {
    .init(
      id: .mock_1,
      name: "Owners",
      members: members
    )
  }
}
