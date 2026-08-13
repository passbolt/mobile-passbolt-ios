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

extension ResourcePermission {

  /// Whether both permissions are granted to the same recipient, regardless of level or permission identifier.
  internal func matchesRecipient(
    of other: ResourcePermission
  ) -> Bool {
    if let userID: User.ID = self.userID {
      return userID == other.userID
    }
    else if let groupID: UserGroup.ID = self.userGroupID {
      return groupID == other.userGroupID
    }
    else {
      return false
    }
  }

  /// The permission as a grant to be created on the given resource.
  internal func asNewDTO(
    resourceID: Resource.ID
  ) -> NewGenericPermissionDTO? {
    switch self {
    case .user(let id, let level, _):
      return .userToResource(userID: id, resourceID: resourceID, permission: level)

    case .userGroup(let id, let level, _):
      return .userGroupToResource(userGroupID: id, resourceID: resourceID, permission: level)
    }
  }

  /// The permission as an already-existing grant on the given resource. Nil when it carries no permission
  /// identifier - such a permission does not exist on the server yet and can only be sent as a new grant.
  internal func asExistingDTO(
    resourceID: Resource.ID
  ) -> GenericPermissionDTO? {
    switch self {
    case .user(let id, let level, .some(let permissionID)):
      return .userToResource(id: permissionID, userID: id, resourceID: resourceID, permission: level)

    case .userGroup(let id, let level, .some(let permissionID)):
      return .userGroupToResource(id: permissionID, userGroupID: id, resourceID: resourceID, permission: level)

    case _:
      return .none
    }
  }
}

/// The operator-confirmed recipient set diffed against the permissions captured in the confirmed snapshot, split
/// into what has to be created, updated and deleted on the server.
///
/// Shared by every flow that applies confirmed permissions so that the rules deciding *who ends up holding the
/// secret* live in exactly one place.
internal struct ConfirmedPermissionsDiff {

  /// Recipients granted access for the first time - they carry no permission identifier yet.
  internal let created: OrderedSet<ResourcePermission>
  /// Recipients that keep access at a different level than the one captured in the snapshot.
  internal let updated: OrderedSet<ResourcePermission>
  /// Recipients present in the snapshot but absent from the confirmed set - they lose access.
  internal let deleted: OrderedSet<ResourcePermission>
  /// Recipients that keep the access they already had - the ones a rotated secret has to be re-encrypted for.
  internal let kept: OrderedSet<ResourcePermission>

  internal init(
    confirmed: OrderedSet<ResourcePermission>,
    original: OrderedSet<ResourcePermission>
  ) {
    self.created = .init(
      confirmed.filter { (permission: ResourcePermission) -> Bool in
        permission.permissionID == .none
      }
    )
    self.updated = .init(
      confirmed.filter { (permission: ResourcePermission) -> Bool in
        guard permission.permissionID != .none,
          let existing: ResourcePermission = original.first(where: { $0.matchesRecipient(of: permission) })
        else { return false }
        return existing.permission != permission.permission
      }
    )
    self.deleted = .init(
      original.filter { (permission: ResourcePermission) -> Bool in
        confirmed.contains(where: { $0.matchesRecipient(of: permission) }) == false
      }
    )
    self.kept = .init(
      confirmed.filter { (permission: ResourcePermission) -> Bool in
        permission.permissionID != .none
      }
    )
  }
}

extension PermissionSnapshot {

  /// The user recipients described by a permission set: users named directly, plus the members of any referenced
  /// group as captured in this snapshot. A group this snapshot does not describe contributes nobody - encryption
  /// then fails closed rather than guessing membership.
  ///
  /// Only recipients the snapshot describes are returned, which is safe precisely because a snapshot is captured
  /// complete: a by-ids response short of what was requested throws ``PermissionSnapshotIncomplete`` instead of
  /// producing a snapshot. An undescribed user is therefore one the server returned without a usable key - nobody
  /// can encrypt for them and the server expects no secret for them either. Group membership is already narrowed
  /// the same way at capture time.
  internal func recipients(
    of permissions: some Sequence<ResourcePermission>
  ) -> OrderedSet<User.ID> {
    var users: OrderedSet<User.ID> = .init()
    for permission: ResourcePermission in permissions {
      if let userID: User.ID = permission.userID {
        guard self.user(userID) != nil
        else { continue }
        users.append(userID)
      }
      else if let groupID: UserGroup.ID = permission.userGroupID,
        let group: PermissionSnapshotGroup = self.group(groupID)
      {
        users.formUnion(group.members)
      }
    }
    return users
  }
}
