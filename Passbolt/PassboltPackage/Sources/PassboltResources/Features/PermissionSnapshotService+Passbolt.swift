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
import FeatureScopes
import NetworkOperations
import OSFeatures
import Resources

extension PermissionSnapshotService {

  /// Ids sent per by-ids request. They travel as repeated `filter[has-id][]` query items, so a folder shared with
  /// a large group would otherwise produce a URL long enough for the server to reject.
  fileprivate static let idsPerRequest: Int = 100

  @MainActor fileprivate static func load(
    using features: Features
  ) throws -> Self {
    let time: OSTime = features.instance()
    let resourceFetchNetworkOperation: ResourceFetchNetworkOperation = try features.instance()
    let resourceFolderFetchNetworkOperation: ResourceFolderFetchNetworkOperation = try features.instance()
    let usersFetchByIDsNetworkOperation: UsersFetchByIDsNetworkOperation = try features.instance()
    let userGroupsFetchByIDsNetworkOperation: UserGroupsFetchByIDsNetworkOperation = try features.instance()

    @Sendable func resourcePermission(
      from dto: GenericPermissionDTO
    ) -> ResourcePermission? {
      if let userID: User.ID = dto.userID {
        return .user(id: userID, permission: dto.permission, permissionID: dto.id)
      }
      else if let userGroupID: UserGroup.ID = dto.userGroupID {
        return .userGroup(id: userGroupID, permission: dto.permission, permissionID: dto.id)
      }
      else {
        return .none
      }
    }

    @Sendable func userEntry(
      from userDTO: UserDTO
    ) -> PermissionSnapshotUser? {
      guard let dso: UserDSO = userDTO.asFilteredDSO
      else { return .none }
      return .init(
        details: .init(
          id: dso.id,
          username: dso.username,
          firstName: dso.profile.firstName,
          lastName: dso.profile.lastName,
          fingerprint: dso.keyFingerprint,
          avatarImageURL: dso.profile.avatar.urlString,
          isSuspended: dso.isSuspended
        ),
        publicKey: dso.publicKey
      )
    }

    /// Fetches the given groups (with their membership) and every user needed to describe them - the users named
    /// plus the members of the groups - skipping ids already present. Returns the entries to merge into a snapshot.
    ///
    /// Two kinds of gap are told apart, because only one of them is safe to live with:
    /// - a recipient the server never returned - user or group - means the response did not cover what was
    ///   requested, so the snapshot would be incomplete without anyone noticing; it throws
    ///   ``PermissionSnapshotIncomplete`` rather than producing a snapshot missing a reviewed recipient;
    /// - a user the server returned without a usable key (never activated, deleted) cannot hold a secret at all,
    ///   so they are left out of the entries *and* out of the group membership captured here, keeping the reviewed
    ///   recipient list and the encryption recipients in agreement.
    @Sendable func fetchEntries(
      userIDs: OrderedSet<User.ID>,
      groupIDs: Array<UserGroup.ID>,
      alreadyKnownUsers: OrderedDictionary<User.ID, PermissionSnapshotUser>
    ) async throws -> (
      users: OrderedDictionary<User.ID, PermissionSnapshotUser>,
      groups: OrderedDictionary<UserGroup.ID, PermissionSnapshotGroup>
    ) {
      var groupDTOs: Array<UserGroupDTO> = .init()
      for chunk: ArraySlice<UserGroup.ID> in groupIDs.chunked(into: Self.idsPerRequest) {
        groupDTOs.append(
          contentsOf: try await userGroupsFetchByIDsNetworkOperation(.init(groupsIDs: .init(chunk)))
        )
      }

      // A group the server did not answer for is the same kind of gap as an unanswered user, with a wider blast
      // radius: its whole membership would be missing, so the group would vanish from the reviewed recipient list
      // and its members would be left out of a secret rotation while keeping their access.
      let answeredGroupIDs: Set<UserGroup.ID> = .init(groupDTOs.map(\.id))
      let unansweredGroupIDs: Array<UserGroup.ID> = groupIDs.filter { (groupID: UserGroup.ID) -> Bool in
        answeredGroupIDs.contains(groupID) == false
      }
      guard unansweredGroupIDs.isEmpty
      else { throw PermissionSnapshotIncomplete.error(missingGroups: unansweredGroupIDs) }

      var neededUserIDs: OrderedSet<User.ID> = userIDs
      for group: UserGroupDTO in groupDTOs {
        neededUserIDs.formUnion(group.userReferences.map(\.id))
      }
      neededUserIDs.subtract(alreadyKnownUsers.keys)

      var userDTOs: Array<UserDTO> = .init()
      for chunk: ArraySlice<User.ID> in Array(neededUserIDs).chunked(into: Self.idsPerRequest) {
        userDTOs.append(
          contentsOf: try await usersFetchByIDsNetworkOperation(.init(usersIDs: .init(chunk)))
        )
      }

      let answeredUserIDs: Set<User.ID> = .init(userDTOs.map(\.id))
      let unansweredUserIDs: Array<User.ID> = neededUserIDs.filter { (userID: User.ID) -> Bool in
        answeredUserIDs.contains(userID) == false
      }
      guard unansweredUserIDs.isEmpty
      else { throw PermissionSnapshotIncomplete.error(missingUsers: unansweredUserIDs) }

      var users: OrderedDictionary<User.ID, PermissionSnapshotUser> = .init()
      for user: UserDTO in userDTOs {
        guard let entry: PermissionSnapshotUser = userEntry(from: user)
        else { continue }  // answered, but holds no usable key - no secret can be encrypted for them
        users[entry.id] = entry
      }

      let describedUsers: OrderedDictionary<User.ID, PermissionSnapshotUser> = users
      func canHoldSecret(
        _ userID: User.ID
      ) -> Bool {
        describedUsers[userID] != nil || alreadyKnownUsers[userID] != nil
      }

      var groups: OrderedDictionary<UserGroup.ID, PermissionSnapshotGroup> = .init()
      for group: UserGroupDTO in groupDTOs {
        groups[group.id] = .init(
          id: group.id,
          name: group.name,
          members: .init(group.userReferences.map(\.id).filter(canHoldSecret))
        )
      }

      return (users: users, groups: groups)
    }

    /// Expands a permission set (step 2 of the build) into a full snapshot: referenced groups give membership,
    /// and every referenced user - direct or via a group - is fetched to gather public key and fingerprint.
    @Sendable func snapshot(
      from permissionDTOs: OrderedSet<GenericPermissionDTO>
    ) async throws -> PermissionSnapshot {
      let permissions: OrderedSet<ResourcePermission> = .init(
        permissionDTOs.compactMap(resourcePermission(from:))
      )

      let entries:
        (
          users: OrderedDictionary<User.ID, PermissionSnapshotUser>,
          groups: OrderedDictionary<UserGroup.ID, PermissionSnapshotGroup>
        ) =
          try await fetchEntries(
            userIDs: .init(permissions.compactMap(\.userID)),
            groupIDs: permissions.compactMap(\.userGroupID),
            alreadyKnownUsers: .init()
          )

      return .init(
        permissions: permissions,
        users: entries.users,
        groups: entries.groups,
        created: time.timestamp()
      )
    }

    /// Adds recipients the operator picked to an existing snapshot: fetches their keys and (for groups) membership
    /// and merges them into `users`/`groups`. `permissions` is left untouched - it remains the drift baseline; the
    /// edited recipient set is tracked separately by the screen.
    @Sendable func expanding(
      _ current: PermissionSnapshot,
      addedUserIDs: Array<User.ID>,
      addedGroupIDs: Array<UserGroup.ID>
    ) async throws -> PermissionSnapshot {
      let entries:
        (
          users: OrderedDictionary<User.ID, PermissionSnapshotUser>,
          groups: OrderedDictionary<UserGroup.ID, PermissionSnapshotGroup>
        ) =
          try await fetchEntries(
            userIDs: .init(addedUserIDs),
            groupIDs: addedGroupIDs,
            alreadyKnownUsers: current.users
          )

      var users: OrderedDictionary<User.ID, PermissionSnapshotUser> = current.users
      for (id, entry): (User.ID, PermissionSnapshotUser) in entries.users {
        users[id] = entry
      }
      var groups: OrderedDictionary<UserGroup.ID, PermissionSnapshotGroup> = current.groups
      for (id, entry): (UserGroup.ID, PermissionSnapshotGroup) in entries.groups {
        groups[id] = entry
      }

      return .init(
        permissions: current.permissions,
        users: users,
        groups: groups,
        created: current.created
      )
    }

    @Sendable func forResource(
      _ resourceID: Resource.ID
    ) async throws -> PermissionSnapshot {
      let resource: ResourceDTO = try await resourceFetchNetworkOperation(.init(resourceID: resourceID))
      return try await snapshot(from: resource.permissions)
    }

    @Sendable func forFolder(
      _ folderID: ResourceFolder.ID
    ) async throws -> PermissionSnapshot {
      let folder: ResourceFolderDTO = try await resourceFolderFetchNetworkOperation(.init(folderID: folderID))
      return try await snapshot(from: folder.permissions)
    }

    return .init(
      forResource: forResource,
      forFolder: forFolder,
      expanding: expanding(_:addedUserIDs:addedGroupIDs:),
      drift: Self.drift(confirmed:current:),
      unexpectedRecipients: Self.unexpectedRecipients(confirmed:simulatedAdded:)
    )
  }
}

extension PermissionSnapshotService {

  @Sendable fileprivate static func drift(
    confirmed: PermissionSnapshot,
    current: PermissionSnapshot
  ) -> PermissionDrift {
    let confirmedKeys: Set<PermissionKey> = confirmed.permissionKeys
    let currentKeys: Set<PermissionKey> = current.permissionKeys

    // Both directions, each walked in list order, so the recipient named in the message is stable across runs.
    // Each side names its own recipients: a removed one is only described by the confirmed snapshot and an
    // added one only by the current one.
    var changedRecipients: OrderedSet<String> = .init(
      confirmed.recipientNames(withPermissionsMissingFrom: currentKeys)
    )
    changedRecipients.formUnion(current.recipientNames(withPermissionsMissingFrom: confirmedKeys))

    var changedFingerprints: Bool = false
    for (id, user): (User.ID, PermissionSnapshotUser) in confirmed.users {
      guard let currentUser: PermissionSnapshotUser = current.user(id),
        currentUser.fingerprint != user.fingerprint
      else { continue }
      changedFingerprints = true
      changedRecipients.append(user.details.displayName)
    }

    var changedMemberships: Bool = false
    for (id, group): (UserGroup.ID, PermissionSnapshotGroup) in confirmed.groups {
      guard let currentGroup: PermissionSnapshotGroup = current.group(id),
        currentGroup.members != group.members
      else { continue }
      changedMemberships = true
      changedRecipients.append(group.name)
    }

    return .init(
      changedPermissions: confirmedKeys != currentKeys,
      changedFingerprints: changedFingerprints,
      changedMemberships: changedMemberships,
      changedRecipients: changedRecipients
    )
  }

  @Sendable fileprivate static func unexpectedRecipients(
    confirmed: PermissionSnapshot,
    simulatedAdded: Array<User.ID>
  ) -> OrderedSet<User.ID> {
    .init(
      simulatedAdded.filter { (userID: User.ID) -> Bool in
        confirmed.user(userID) == nil
      }
    )
  }
}

/// Identity and level of a single permission - the unit drift is measured in. Permission identifiers are
/// deliberately excluded: the same grant re-issued under a new identifier is not a change to review.
private enum PermissionKey: Hashable {

  case user(User.ID, Permission)
  case userGroup(UserGroup.ID, Permission)
}

extension ResourcePermission {

  fileprivate var permissionKey: PermissionKey {
    switch self {
    case .user(let id, let level, _):
      return .user(id, level)

    case .userGroup(let id, let level, _):
      return .userGroup(id, level)
    }
  }
}

extension PermissionSnapshot {

  fileprivate var permissionKeys: Set<PermissionKey> {
    Set(self.permissions.map(\.permissionKey))
  }

  /// Display names of the recipients whose permission is absent from `keys` - those added or removed relative to
  /// the snapshot those keys came from. A recipient this snapshot does not describe is skipped, having no name.
  fileprivate func recipientNames(
    withPermissionsMissingFrom keys: Set<PermissionKey>
  ) -> Array<String> {
    self.permissions
      .filter { (permission: ResourcePermission) -> Bool in
        keys.contains(permission.permissionKey) == false
      }
      .compactMap(self.recipientName(of:))
  }

  /// Display name of the user or group a permission is granted to.
  private func recipientName(
    of permission: ResourcePermission
  ) -> String? {
    switch permission {
    case .user(let id, _, _):
      return self.user(id)?.details.displayName

    case .userGroup(let id, _, _):
      return self.group(id)?.name
    }
  }
}

extension FeaturesRegistry {

  internal mutating func usePassboltPermissionSnapshotService() {
    self.use(
      .lazyLoaded(
        PermissionSnapshotService.self,
        load: PermissionSnapshotService.load(using:)
      ),
      in: SessionScope.self
    )
  }
}
