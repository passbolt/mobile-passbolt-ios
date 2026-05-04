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

import Accounts
import Display
import OSFeatures
import Resources
import Users

internal final class PermissionUsersAndGroupsSearchViewController: @MainActor ViewController {

  internal typealias Context = Resource.ID

  internal struct ViewState: Equatable {

    internal var searchText: String = .empty
    internal var selectedItems: Array<OverlappingAvatarStackView.Item> = .init()
    internal var listSelectionRowViewModels: Array<SelectionRowViewModel> = .init()
    internal var listExistingRowViewModels: Array<ExistingPermissionRowViewModel> = .init()
  }

  internal let viewState: ViewStateSource<ViewState>

  private let resourceShareForm: ResourceShareForm
  private let users: Users
  private let userGroups: UserGroups
  private let navigationToSelf: NavigationToPermissionUsersAndGroupsSearch
  private var searchTask: Task<Void, Never>? = .none

  internal init(context: Resource.ID, features: Features) throws {
    self.navigationToSelf = try features.instance()
    self.resourceShareForm = try features.instance()
    self.users = try features.instance()
    self.userGroups = try features.instance()
    self.viewState = .init(initial: .init())
    self.updateSearchText(.empty)
  }

  internal func updateSearchText(_ newText: String) {
    self.viewState.update(\.searchText, to: newText)
    searchTask?.cancel()
    searchTask = .init { [weak self] in
      guard let self else { return }
      let matchingUserGroups: Array<UserGroupDetailsDSV>
      let matchingUsers: Array<UserDetailsDSV>

      do {
        matchingUsers =
          try await users
          .filteredUsers(.init(text: newText))
        matchingUserGroups =
          try await userGroups
          .filteredUserGroups(.init(userID: .none, text: newText))
      }
      catch {
        return error.consume()
      }
      let existingPermissions: OrderedSet<ResourcePermission> =
        await resourceShareForm
        .currentPermissions()

      let selectableUsersAndGroups: Array<SelectionRowViewModel> =
        matchingUserGroups
        .asSelectableItems(existingPermissions: existingPermissions)
        + matchingUsers
        .asSelectableItems(
          existingPermissions: existingPermissions,
          avatarLoader: loadAvatar(for:)
        )

      let existingUsersAndGroupsPermissions: Array<ExistingPermissionRowViewModel> =
        matchingUserGroups
        .asExistingItems(existingPermissions: existingPermissions)

        + matchingUsers
        .asExistingItems(
          existingPermissions: existingPermissions,
          avatarLoader: loadAvatar(for:)
        )
      self.viewState.update { state in
        state.listSelectionRowViewModels = selectableUsersAndGroups
        state.listExistingRowViewModels = existingUsersAndGroupsPermissions
      }
    }
  }

  @Sendable internal func activate() async {
    await consumingErrors {
      let existingPermissions: OrderedSet<ResourcePermission> = await resourceShareForm.currentPermissions()
      let selectedItems: Array<OverlappingAvatarStackView.Item> = try await existingPermissions.asyncMap { permission in
        switch permission {
        case .user(let id, _, _):
          return await .user(
            id,
            avatarImage: users.loadAvatar(for: id),
            isSuspended: try users.userDetails(id).isSuspended
          )

        case .userGroup(let id, _, _):
          return .userGroup(id)
        }
      }

      await self.viewState.update(\.selectedItems, to: selectedItems)
    }
  }

  @Sendable private func loadAvatar(for userID: User.ID) async -> Data? {
    do {
      return try await users.userAvatarImage(userID)
    }
    catch {
      error.logged()
      return nil
    }
  }

  internal func toggleUserSelection(
    _ userListRowViewModel: UserListRowViewModel
  ) async {
    let currentState: ViewState = await viewState.current
    let userID = userListRowViewModel.id
    if currentState.selectedItems.contains(where: { item in
      switch item {
      case .user(let id, _, _):
        return userID == id
      case .userGroup:
        return false
      }
    }) {
      let selectedItems: Array<OverlappingAvatarStackView.Item> = currentState.selectedItems.filter { item in
        switch item {
        case .user(let id, _, _):
          return userID != id
        case .userGroup:
          return true
        }
      }
      viewState.update(\.selectedItems, to: selectedItems)
    }
    else {
      var selectedItems: Array<OverlappingAvatarStackView.Item> = currentState.selectedItems
      selectedItems.append(
        .user(
          userID,
          avatarImage: { [weak self] in await self?.loadAvatar(for: userID) },
          isSuspended: userListRowViewModel.isSuspended
        )
      )
      viewState.update(\.selectedItems, to: selectedItems)
    }
  }

  internal func toggleUserGroupSelection(
    _ userGroupID: UserGroup.ID
  ) async {
    let currentState: ViewState = await viewState.current

    if currentState.selectedItems.contains(where: { item in
      switch item {
      case .userGroup(let id):
        return userGroupID == id
      case .user:
        return false
      }
    }) {
      let selectedItems: Array<OverlappingAvatarStackView.Item> = currentState.selectedItems.filter { item in
        switch item {
        case .userGroup(let id):
          return userGroupID != id
        case .user:
          return true
        }
      }
      viewState.update(\.selectedItems, to: selectedItems)
    }
    else {
      var selectedItems: Array<OverlappingAvatarStackView.Item> = currentState.selectedItems
      selectedItems.append(.userGroup(userGroupID))
      viewState.update(\.selectedItems, to: selectedItems)
    }
  }

  @MainActor func saveSelection() async throws {
    let existingPermissions: OrderedSet<ResourcePermission> =
      await resourceShareForm
      .currentPermissions()
    let newSelections =
      await viewState
      .current
      .selectedItems
      .dropFirst(existingPermissions.count)

    for row in newSelections {
      switch row {
      case .user(let userID, _, _):
        await resourceShareForm
          .setUserPermission(
            userID,
            .read
          )
      case .userGroup(let userGroupID):
        await resourceShareForm
          .setUserGroupPermission(
            userGroupID,
            .read
          )
      }

    }

    await consumingErrors {
      try await navigationToSelf.revert()
    }
  }
}

extension PermissionUsersAndGroupsSearchViewController {

  internal enum SelectionRowViewModel: Hashable, Identifiable {

    case user(UserListRowViewModel)
    case userGroup(UserGroupListRowViewModel)

    internal var id: AnyHashable {
      switch self {
      case .user(let model):
        return "user-\(model.id)"
      case .userGroup(let model):
        return "userGroup-\(model.id)"
      }
    }
  }

  internal enum ExistingPermissionRowViewModel: Hashable, Identifiable {

    case user(UserListRowViewModel, permission: Permission)
    case userGroup(UserGroupListRowViewModel, permission: Permission)

    internal var id: AnyHashable {
      switch self {
      case .user(let model, _):
        return "user-\(model.id)"
      case .userGroup(let model, _):
        return "userGroup-\(model.id)"
      }
    }
  }
}

extension Array where Element == UserGroupDetailsDSV {

  fileprivate func asSelectableItems(
    existingPermissions: OrderedSet<ResourcePermission>
  ) -> Array<PermissionUsersAndGroupsSearchViewController.SelectionRowViewModel> {
    compactMap {
      (
        userGroupDetails: UserGroupDetailsDSV
      )
        -> PermissionUsersAndGroupsSearchViewController.SelectionRowViewModel? in
      let permissionExists: Bool = existingPermissions.contains {
        (permission: ResourcePermission) -> Bool in
        permission.userGroupID == userGroupDetails.id
      }

      guard !permissionExists
      else { return .none }

      return .userGroup(
        .init(
          id: userGroupDetails.id,
          name: "\(userGroupDetails.name)"
        )
      )
    }
  }

  fileprivate func asExistingItems(
    existingPermissions: OrderedSet<ResourcePermission>
  ) -> Array<PermissionUsersAndGroupsSearchViewController.ExistingPermissionRowViewModel> {
    compactMap {
      (
        userGroupDetails: UserGroupDetailsDSV
      ) -> PermissionUsersAndGroupsSearchViewController.ExistingPermissionRowViewModel? in
      let matchingPermission: ResourcePermission? =
        existingPermissions.first { (permission: ResourcePermission) -> Bool in
          permission.userGroupID == userGroupDetails.id
        }

      guard let permission: ResourcePermission = matchingPermission
      else { return .none }

      return .userGroup(
        .init(
          id: userGroupDetails.id,
          name: "\(userGroupDetails.name)"
        ),
        permission: permission.permission
      )
    }
  }
}

extension Array where Element == UserDetailsDSV {

  internal func asSelectableItems(
    existingPermissions: OrderedSet<ResourcePermission>,
    avatarLoader: @escaping @Sendable (User.ID) async -> Data?
  ) -> Array<PermissionUsersAndGroupsSearchViewController.SelectionRowViewModel> {
    compactMap { (userDetails: UserDetailsDSV) -> PermissionUsersAndGroupsSearchViewController.SelectionRowViewModel? in
      let permissionExists: Bool = existingPermissions.contains {
        (permission: ResourcePermission) -> Bool in
        permission.userID == userDetails.id
      }

      guard !permissionExists
      else { return .none }

      let isSuspended = userDetails.isSuspended
      let suspendedMark =
        isSuspended
        ? " (\(DisplayableString.localized("resource.permission.details.user.suspended").string()))" : ""

      return .user(
        .init(
          id: userDetails.id,
          fullName: "\(userDetails.firstName) \(userDetails.lastName)\(suspendedMark)",
          username: "\(userDetails.username)",
          avatarImageFetch: { await avatarLoader(userDetails.id) },
          isSuspended: isSuspended
        )
      )
    }
  }

  internal func asExistingItems(
    existingPermissions: OrderedSet<ResourcePermission>,
    avatarLoader: @escaping @Sendable (User.ID) async -> Data?
  ) -> Array<PermissionUsersAndGroupsSearchViewController.ExistingPermissionRowViewModel> {
    compactMap {
      (
        userDetails: UserDetailsDSV
      ) -> PermissionUsersAndGroupsSearchViewController.ExistingPermissionRowViewModel? in
      let matchingPermission: ResourcePermission? =
        existingPermissions.first { (permission: ResourcePermission) -> Bool in
          permission.userID == userDetails.id
        }

      guard let permission: ResourcePermission = matchingPermission
      else { return .none }

      let isSuspended = userDetails.isSuspended
      let suspendedMark =
        isSuspended
        ? " (\(DisplayableString.localized("resource.permission.details.user.suspended").string()))" : ""

      return .user(
        .init(
          id: userDetails.id,
          fullName: "\(userDetails.firstName) \(userDetails.lastName)\(suspendedMark)",
          username: "\(userDetails.username)",
          avatarImageFetch: { await avatarLoader(userDetails.id) },
          isSuspended: isSuspended
        ),
        permission: permission.permission
      )
    }
  }
}
