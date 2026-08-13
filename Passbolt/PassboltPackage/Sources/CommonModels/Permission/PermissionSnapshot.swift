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

import Commons

/// Immutable capture of an ACO's permissions together with every user and group they reference,
/// taken when the permission confirmation screen is rendered. The encryption is bound to this
/// capture and drift is measured against it on confirmation.
public struct PermissionSnapshot {

  /// Current ACO/ARO permission list with their permission types.
  public var permissions: OrderedSet<ResourcePermission>
  /// Every referenced user - both named directly in the permissions and members of any referenced group -
  /// with the public key and fingerprint needed for encryption, drift detection and the group drill-down.
  public var users: OrderedDictionary<User.ID, PermissionSnapshotUser>
  /// Full membership for every group referenced by the permissions.
  public var groups: OrderedDictionary<UserGroup.ID, PermissionSnapshotGroup>
  /// Moment the snapshot was captured.
  public var created: Timestamp

  public init(
    permissions: OrderedSet<ResourcePermission>,
    users: OrderedDictionary<User.ID, PermissionSnapshotUser>,
    groups: OrderedDictionary<UserGroup.ID, PermissionSnapshotGroup>,
    created: Timestamp
  ) {
    self.permissions = permissions
    self.users = users
    self.groups = groups
    self.created = created
  }
}

extension PermissionSnapshot: Equatable {}
extension PermissionSnapshot: Sendable {}

extension PermissionSnapshot {

  public func user(
    _ id: User.ID
  ) -> PermissionSnapshotUser? {
    self.users[id]
  }

  public func group(
    _ id: UserGroup.ID
  ) -> PermissionSnapshotGroup? {
    self.groups[id]
  }

  /// Recipients this snapshot describes that `other` does not - the ones the operator added by hand, since a
  /// fresh capture of the resource or folder only covers what already holds a permission on it.
  ///
  /// Drift is measured per recipient the two snapshots have in common, so an added recipient would otherwise
  /// never have their key re-checked before the secret is encrypted for them. Re-capturing them into the current
  /// snapshot first puts them back under the fingerprint and membership comparison.
  public func recipientsMissing(
    from other: PermissionSnapshot
  ) -> (users: Array<User.ID>, groups: Array<UserGroup.ID>) {
    (
      users: self.users.keys.filter { (userID: User.ID) -> Bool in
        other.users[userID] == nil
      },
      groups: self.groups.keys.filter { (groupID: UserGroup.ID) -> Bool in
        other.groups[groupID] == nil
      }
    )
  }
}

/// A user captured in a ``PermissionSnapshot``: display details plus the public key used to encrypt for them.
public struct PermissionSnapshotUser {

  public var details: UserDetailsDSV
  public var publicKey: ArmoredPGPPublicKey

  public init(
    details: UserDetailsDSV,
    publicKey: ArmoredPGPPublicKey
  ) {
    self.details = details
    self.publicKey = publicKey
  }
}

extension PermissionSnapshotUser: Hashable {}
extension PermissionSnapshotUser: Sendable {}

extension PermissionSnapshotUser {

  public var id: User.ID {
    self.details.id
  }

  public var fingerprint: Fingerprint {
    self.details.fingerprint
  }
}

/// A group captured in a ``PermissionSnapshot``: identity and the exact membership at capture time.
public struct PermissionSnapshotGroup {

  public var id: UserGroup.ID
  public var name: String
  public var members: OrderedSet<User.ID>

  public init(
    id: UserGroup.ID,
    name: String,
    members: OrderedSet<User.ID>
  ) {
    self.id = id
    self.name = name
    self.members = members
  }
}

extension PermissionSnapshotGroup: Hashable {}
extension PermissionSnapshotGroup: Sendable {}
