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
import Display
import FeatureScopes
import Resources
import SessionData
import Users

/// A single rendered row of the confirmation list. Each row is a navigation entry into the recipient's details
/// screen (where the permission level is adjusted). `editable` is false in read-only mode and always false for the
/// operator's own row; it drives whether removal (swipe) and level editing are offered.
internal enum ConfirmPermissionRowItem: Equatable, Hashable, Sendable {

  case user(UserPermissionDetailsDSV, editable: Bool)
  case group(UserGroupPermissionDetailsDSV, editable: Bool)

  /// Stable identity of the row: the recipient it grants access to, independent of the level it currently holds.
  internal var recipientID: String {
    switch self {
    case .user(let details, _):
      return "user-\(details.id)"

    case .group(let details, _):
      return "group-\(details.id)"
    }
  }
}

internal final class ConfirmPermissionsController: @MainActor ViewController {

  internal typealias Context = ConfirmPermissionsContext

  internal struct ViewState: Equatable, Sendable {

    internal var mode: ConfirmPermissionsMode
    internal var rows: Array<ConfirmPermissionRowItem>
    internal var loading: Bool = false
    /// Warning shown above the list when a recipient would receive access more than once (directly and through a
    /// group, or through several groups). Nil when no recipient is granted redundantly.
    internal var duplicateWarning: DisplayableString?
  }

  internal let viewState: ViewStateSource<ViewState>

  private let context: Context
  private let navigationToSelf: NavigationToConfirmPermissions
  private let navigationToAddRecipients: NavigationToConfirmAddRecipients
  private let navigationToUserDetails: NavigationToConfirmUserPermissionDetails
  private let navigationToGroupDetails: NavigationToConfirmGroupPermissionDetails
  private let permissionSnapshotService: PermissionSnapshotService
  private let sessionData: SessionData
  private let users: Users

  /// Current snapshot backing the list. Replaced via ``reset(snapshot:)`` when the flow reopens after drift.
  private var snapshot: PermissionSnapshot
  /// Editable recipient set, seeded from the snapshot. The encryption is bound to whatever is confirmed here.
  private var editedPermissions: OrderedSet<ResourcePermission>

  internal init(
    context: Context,
    features: Features
  ) throws {
    self.context = context
    self.navigationToSelf = try features.instance()
    self.navigationToAddRecipients = try features.instance()
    self.navigationToUserDetails = try features.instance()
    self.navigationToGroupDetails = try features.instance()
    self.permissionSnapshotService = try features.instance()
    self.sessionData = try features.instance()
    self.users = try features.instance()
    self.snapshot = context.snapshot
    self.editedPermissions = context.snapshot.permissions

    self.viewState = .init(
      initial: .init(
        mode: context.mode,
        rows: Self.rows(
          for: context.snapshot.permissions,
          snapshot: context.snapshot,
          editable: context.mode.isEditable,
          operatorID: context.operatorID
        ),
        duplicateWarning: Self.duplicateAccessWarning(
          for: context.snapshot.permissions,
          snapshot: context.snapshot
        )
      )
    )
  }

  internal func avatar(
    for userID: User.ID
  ) -> @Sendable () async -> Data? {
    self.users.loadAvatar(for: userID)
  }

  /// Reopens the list with fresh server data after drift was detected on confirmation, so the operator reviews
  /// the recipients as they now stand. Any pending edits are dropped with the snapshot they were made against.
  internal func reset(
    snapshot: PermissionSnapshot
  ) {
    self.snapshot = snapshot
    self.editedPermissions = snapshot.permissions
    self.refreshRows()
  }

  internal func setUserPermission(
    _ userID: User.ID,
    to permission: Permission
  ) {
    // The operator must remain an owner - the view does not offer it, this holds it at the controller boundary.
    guard self.context.mode.isEditable,
      userID != self.context.operatorID
    else { return }
    self.editedPermissions = OrderedSet(
      self.editedPermissions.map { (existing: ResourcePermission) -> ResourcePermission in
        switch existing {
        case .user(let id, _, let permissionID) where id == userID:
          return .user(id: id, permission: permission, permissionID: permissionID)

        case _:
          return existing
        }
      }
    )
    self.refreshRows()
  }

  internal func setUserGroupPermission(
    _ groupID: UserGroup.ID,
    to permission: Permission
  ) {
    guard self.context.mode.isEditable
    else { return }
    self.editedPermissions = OrderedSet(
      self.editedPermissions.map { (existing: ResourcePermission) -> ResourcePermission in
        switch existing {
        case .userGroup(let id, _, let permissionID) where id == groupID:
          return .userGroup(id: id, permission: permission, permissionID: permissionID)

        case _:
          return existing
        }
      }
    )
    self.refreshRows()
  }

  internal func removeUser(
    _ userID: User.ID
  ) {
    guard self.context.mode.isEditable,
      userID != self.context.operatorID
    else { return }
    self.editedPermissions = OrderedSet(
      self.editedPermissions.filter { $0.userID != userID }
    )
    self.refreshRows()
  }

  internal func removeUserGroup(
    _ groupID: UserGroup.ID
  ) {
    guard self.context.mode.isEditable
    else { return }
    self.editedPermissions = OrderedSet(
      self.editedPermissions.filter { $0.userGroupID != groupID }
    )
    self.refreshRows()
  }

  internal func addRecipients() async {
    // A read-only list may not gain recipients either - the row is hidden, this guards the action itself.
    guard self.context.mode.isEditable
    else { return }

    // The picker searches the local database, so pull the workspace users and groups from the server first -
    // otherwise a recently invited user or a new group would not be offered. Only those two are refreshed; a
    // full session refresh would also pull metadata, folders and every resource. A failed refresh is not fatal:
    // the picker still opens with the cached lists.
    self.viewState.update(\.loading, to: true)
    do {
      try await self.sessionData.refreshUsersAndGroups()
    }
    catch {
      error.logged()
    }
    self.viewState.update(\.loading, to: false)

    let excludedUsers: Set<User.ID> = .init(self.editedPermissions.compactMap(\.userID))
    let excludedGroups: Set<UserGroup.ID> = .init(self.editedPermissions.compactMap(\.userGroupID))
    await consumingErrors {
      try await self.navigationToAddRecipients.perform(
        context: .init(
          excludedUsers: excludedUsers,
          excludedGroups: excludedGroups,
          onSelect: { [weak self] (users: Array<User.ID>, groups: Array<UserGroup.ID>) in
            await self?.handleAddedRecipients(users: users, groups: groups)
          }
        )
      )
    }
  }

  /// Adds the recipients picked in the search screen: expands the snapshot with their keys/membership (so the
  /// encryption can bind to them) and grants them the default `read` permission.
  ///
  /// Only recipients the expanded snapshot actually describes are granted. A picked user the server returned
  /// without a usable key is described by nobody: granting them would add a permission that renders no row (the
  /// list only shows described recipients) and that no secret can be encrypted for - an invisible grant, which is
  /// exactly what this screen exists to prevent. They are dropped and the operator is told.
  private func handleAddedRecipients(
    users: Array<User.ID>,
    groups: Array<UserGroup.ID>
  ) async {
    guard self.context.mode.isEditable,
      !users.isEmpty || !groups.isEmpty
    else { return }
    do {
      let expandedSnapshot: PermissionSnapshot =
        try await self.permissionSnapshotService.expanding(self.snapshot, users, groups)
      self.snapshot = expandedSnapshot

      let describedUsers: Array<User.ID> = users.filter { (userID: User.ID) -> Bool in
        expandedSnapshot.user(userID) != nil
      }
      let describedGroups: Array<UserGroup.ID> = groups.filter { (groupID: UserGroup.ID) -> Bool in
        expandedSnapshot.group(groupID) != nil
      }

      for userID: User.ID in describedUsers where !self.editedPermissions.contains(where: { $0.userID == userID }) {
        self.editedPermissions.append(.user(id: userID, permission: .read, permissionID: .none))
      }
      for groupID: UserGroup.ID in describedGroups
      where !self.editedPermissions.contains(where: { $0.userGroupID == groupID }) {
        self.editedPermissions.append(.userGroup(id: groupID, permission: .read, permissionID: .none))
      }
      self.refreshRows()

      if describedUsers.count != users.count || describedGroups.count != groups.count {
        SnackBarMessageEvent.send(.error("resource.permission.confirm.recipient.unavailable.message"))
      }
    }
    catch {
      error.consume()
    }
  }

  /// Warns when a recipient would receive access more than once - granted directly while already a member of a
  /// confirmed group, or a member of several confirmed groups. Recomputed with the rows, so removing the redundant
  /// grant clears the warning.
  private static func duplicateAccessWarning(
    for permissions: OrderedSet<ResourcePermission>,
    snapshot: PermissionSnapshot
  ) -> DisplayableString? {
    let directUsers: Set<User.ID> = .init(permissions.compactMap(\.userID))
    let groupIDs: Array<UserGroup.ID> = permissions.compactMap(\.userGroupID)

    // Per user, the confirmed groups they belong to - in the order the groups appear in the list.
    var groupsPerUser: OrderedDictionary<User.ID, Array<UserGroup.ID>> = .init()
    for groupID: UserGroup.ID in groupIDs {
      guard let group: PermissionSnapshotGroup = snapshot.group(groupID)
      else { continue }
      for memberID: User.ID in group.members {
        var groups: Array<UserGroup.ID> = groupsPerUser[memberID] ?? .init()
        groups.append(groupID)
        groupsPerUser[memberID] = groups
      }
    }

    var duplicatedCount: Int = 0
    var firstUserName: String?
    var firstGroupName: String?
    for (userID, groups): (User.ID, Array<UserGroup.ID>) in groupsPerUser {
      guard let firstGroupID: UserGroup.ID = groups.first,
        directUsers.contains(userID) || groups.count > 1
      else { continue }
      duplicatedCount += 1
      if firstUserName == .none {
        firstUserName = snapshot.user(userID)?.details.displayName
        firstGroupName = snapshot.group(firstGroupID)?.name
      }
    }

    guard let userName: String = firstUserName
    else { return .none }

    if duplicatedCount == 1 {
      guard let groupName: String = firstGroupName
      else { return .none }
      return .localized(
        key: "resource.permission.confirm.duplicate.single.message",
        arguments: [userName, groupName]
      )
    }
    else {
      return .localized(
        key: "resource.permission.confirm.duplicate.multiple.message",
        arguments: [userName]
      )
    }
  }

  private func duplicateAccessWarning() -> DisplayableString? {
    Self.duplicateAccessWarning(for: self.editedPermissions, snapshot: self.snapshot)
  }

  /// Opens the details screen for a user recipient. The level picked there is reported back via `setPermission`,
  /// keeping the edited recipient set - and the encryption bound to it - in sync.
  internal func openUserDetails(
    _ userID: User.ID
  ) async {
    guard let user: PermissionSnapshotUser = self.snapshot.user(userID),
      let level: Permission = self.editedPermissions.first(where: { $0.userID == userID })?.permission
    else { return }
    // The operator must remain an owner, so their own row is never editable here.
    let editable: Bool = self.context.mode.isEditable && userID != self.context.operatorID
    await consumingErrors {
      try await self.navigationToUserDetails.perform(
        context: .init(
          details: .init(
            id: user.details.id,
            username: user.details.username,
            firstName: user.details.firstName,
            lastName: user.details.lastName,
            fingerprint: user.details.fingerprint,
            avatarImageURL: user.details.avatarImageURL,
            permission: level,
            isSuspended: user.details.isSuspended
          ),
          editable: editable,
          setPermission: { [weak self] (permission: Permission) in
            await self?.setUserPermission(userID, to: permission)
          }
        )
      )
    }
  }

  /// Opens the details screen for a group recipient (members preview + level picker). The level picked there is
  /// reported back via `setPermission`.
  internal func openGroupDetails(
    _ groupID: UserGroup.ID
  ) async {
    guard let group: PermissionSnapshotGroup = self.snapshot.group(groupID),
      let level: Permission = self.editedPermissions.first(where: { $0.userGroupID == groupID })?.permission
    else { return }
    let members: OrderedSet<UserDetailsDSV> = .init(
      group.members.compactMap { (memberID: User.ID) in
        self.snapshot.user(memberID)?.details
      }
    )
    await consumingErrors {
      try await self.navigationToGroupDetails.perform(
        context: .init(
          details: .init(
            id: groupID,
            name: group.name,
            permission: level,
            members: members
          ),
          editable: self.context.mode.isEditable,
          setPermission: { [weak self] (permission: Permission) in
            await self?.setUserGroupPermission(groupID, to: permission)
          }
        )
      )
    }
  }

  internal func confirm() async {
    self.viewState.update(\.loading, to: true)
    let outcome: ConfirmPermissionsOutcome = await self.context.onConfirm(self.editedPermissions, self.snapshot)
    self.viewState.update(\.loading, to: false)
    switch outcome {
    case .applied:
      break  // the flow already navigated away

    case .failed:
      break  // the flow already surfaced the error

    case .retryWithRefreshed(let refreshedSnapshot):
      // Drift: the flow surfaced a message and handed back fresh data; show the updated recipients to review.
      self.reset(snapshot: refreshedSnapshot)
    }
  }

  internal func cancel() async {
    await self.context.onCancel()
    await consumingErrors {
      try await self.navigationToSelf.revert()
    }
  }

  private func refreshRows() {
    let rows: Array<ConfirmPermissionRowItem> = Self.rows(
      for: self.editedPermissions,
      snapshot: self.snapshot,
      editable: self.context.mode.isEditable,
      operatorID: self.context.operatorID
    )
    let duplicateWarning: DisplayableString? = self.duplicateAccessWarning()

    self.viewState.update { (state: inout ViewState) in
      state.rows = rows
      state.duplicateWarning = duplicateWarning
    }
  }

  /// Builds the flat row list from the confirmed permissions. A row is editable only in editable mode and never
  /// for the operator's own permission; each row opens its recipient's details screen where the level is adjusted.
  private static func rows(
    for permissions: OrderedSet<ResourcePermission>,
    snapshot: PermissionSnapshot,
    editable: Bool,
    operatorID: User.ID
  ) -> Array<ConfirmPermissionRowItem> {
    var rows: Array<ConfirmPermissionRowItem> = .init()
    rows.reserveCapacity(permissions.count)

    for permission: ResourcePermission in permissions {
      switch permission {
      case .user(let userID, let level, _):
        guard let user: PermissionSnapshotUser = snapshot.user(userID)
        else { continue }
        rows.append(
          .user(
            Self.userDetails(from: user, level: level),
            editable: editable && userID != operatorID
          )
        )

      case .userGroup(let groupID, let level, _):
        guard let group: PermissionSnapshotGroup = snapshot.group(groupID)
        else { continue }
        let members: OrderedSet<UserDetailsDSV> = .init(
          group.members.compactMap { (memberID: User.ID) in
            snapshot.user(memberID)?.details
          }
        )
        rows.append(
          .group(
            .init(
              id: groupID,
              name: group.name,
              permission: level,
              members: members
            ),
            editable: editable
          )
        )
      }
    }

    return rows
  }

  private static func userDetails(
    from user: PermissionSnapshotUser,
    level: Permission
  ) -> UserPermissionDetailsDSV {
    .init(
      id: user.details.id,
      username: user.details.username,
      firstName: user.details.firstName,
      lastName: user.details.lastName,
      fingerprint: user.details.fingerprint,
      avatarImageURL: user.details.avatarImageURL,
      permission: level,
      isSuspended: user.details.isSuspended
    )
  }
}
