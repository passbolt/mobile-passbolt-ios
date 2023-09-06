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
import UIComponents
import Users

internal struct PermissionUsersAndGroupsSearchController {

  internal var viewState: ObservableValue<ViewState>
  internal var toggleUserSelection: @MainActor (User.ID) -> Void
  internal var toggleUserGroupSelection: @MainActor (UserGroup.ID) -> Void
  internal var saveSelection: @MainActor () -> Void
  internal var navigateBack: () -> Void
}

extension PermissionUsersAndGroupsSearchController: ComponentController {

  internal typealias ControlledView = PermissionUsersAndGroupsSearchView
  internal typealias Context = Resource.ID

  @MainActor static func instance(
    in context: Context,
    with features: inout Features,
    cancellables: Cancellables
  ) throws -> Self {

    let navigation: DisplayNavigation = try features.instance()
    let executor: AsyncExecutor = try features.instance()
    let resourceShareForm: ResourceShareForm = try features.instance()
    let users: Users = try features.instance()
    let userGroups: UserGroups = try features.instance()

    let viewState: ObservableValue<ViewState> = .init(
      initial: .init(
        searchText: "",
        selectedItems: .init(),
        listSelectionRowViewModels: .init(),
        listExistingRowViewModels: .init()
      )
    )

    executor.schedule { @MainActor in
      let existingPermissions: OrderedSet<ResourcePermission> =
        await resourceShareForm
        .currentPermissions()
      let selectedItems: Array<OverlappingAvatarStackView.Item> =
        existingPermissions
        .map { permission in
          switch permission {
          case let .user(userID, _, _):
            return .user(userID, avatarImage: userAvatarImageFetch(userID))
          case let .userGroup(userGroupID, _, _):
            return .userGroup(userGroupID)
          }
        }
      viewState.value.selectedItems = selectedItems
    }

    func userAvatarImageFetch(
      _ userID: User.ID
    ) -> @Sendable () async -> Data? {
      { @Sendable in
        do {
          return try await users.userAvatarImage(userID)
        }
        catch {
          error.logged()
          return nil
        }
      }
    }

    let searchTextSequence =
      viewState
      .asAnyAsyncSequence()
      .map(\.searchText)
    executor.scheduleIteration(
      over: searchTextSequence,
      failMessage: "Search updates broken!"
    ) { @MainActor (searchText: String) async throws -> Void in
      let matchingUserGroups: Array<UserGroupDetailsDSV>
      let matchingUsers: Array<UserDetailsDSV>

      do {
        matchingUsers =
          try await users
          .filteredUsers(.init(text: searchText))
        matchingUserGroups =
          try await userGroups
          .filteredUserGroups(.init(userID: .none, text: searchText))
      }
      catch {
        error.logged()
        viewState.set(
          \.snackBarMessage,
          to: .error(error)
        )
        return
      }
      let existingPermissions: OrderedSet<ResourcePermission> =
        await resourceShareForm
        .currentPermissions()

      let selectableUsersAndGroups: Array<ControlledView.SelectionRowViewModel> =
        matchingUserGroups
        .compactMap { (userGroupDetails: UserGroupDetailsDSV) -> ControlledView.SelectionRowViewModel? in
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
        + matchingUsers
        .compactMap { (userDetails: UserDetailsDSV) -> ControlledView.SelectionRowViewModel? in
          let permissionExists: Bool = existingPermissions.contains {
            (permission: ResourcePermission) -> Bool in
            permission.userID == userDetails.id
          }

          guard !permissionExists
          else { return .none }

          return .user(
            .init(
              id: userDetails.id,
              fullName: "\(userDetails.firstName) \(userDetails.lastName)",
              username: "\(userDetails.username)",
              avatarImageFetch: userAvatarImageFetch(userDetails.id)
            )
          )
        }

      let existingUsersAndGroupsPermissions: Array<ControlledView.ExistingPermissionRowViewModel> =
        matchingUserGroups
        .compactMap { (userGroupDetails: UserGroupDetailsDSV) -> ControlledView.ExistingPermissionRowViewModel? in
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
        + matchingUsers
        .compactMap { (userDetails: UserDetailsDSV) -> ControlledView.ExistingPermissionRowViewModel? in
          let matchingPermission: ResourcePermission? =
            existingPermissions.first { (permission: ResourcePermission) -> Bool in
              permission.userID == userDetails.id
            }

          guard let permission: ResourcePermission = matchingPermission
          else { return .none }

          guard let permission = matchingPermission
          else { return .none }

          return .user(
            .init(
              id: userDetails.id,
              fullName: "\(userDetails.firstName) \(userDetails.lastName)",
              username: "\(userDetails.username)",
              avatarImageFetch: userAvatarImageFetch(userDetails.id)
            ),
            permission: permission.permission
          )
        }

      viewState.withValue { (state: inout ViewState) in
        state.listSelectionRowViewModels = selectableUsersAndGroups
        state.listExistingRowViewModels = existingUsersAndGroupsPermissions
      }
    }

    @MainActor func toggleUserSelection(
      _ userID: User.ID
    ) {
      if viewState.selectedItems.contains(where: { item in
        switch item {
        case let .user(id, _):
          return userID == id
        case .userGroup:
          return false
        }
      }) {
        viewState.selectedItems.removeAll(where: { item in
          switch item {
          case let .user(id, _):
            return userID == id
          case .userGroup:
            return false
          }
        })
      }
      else {
        viewState.selectedItems.append(.user(userID, avatarImage: userAvatarImageFetch(userID)))
      }
    }

    @MainActor func toggleUserGroupSelection(
      _ userGroupID: UserGroup.ID
    ) {
      if viewState.selectedItems.contains(where: { item in
        switch item {
        case let .userGroup(id):
          return userGroupID == id
        case .user:
          return false
        }
      }) {
        viewState.selectedItems.removeAll(where: { item in
          switch item {
          case let .userGroup(id):
            return userGroupID == id
          case .user:
            return false
          }
        })
      }
      else {
        viewState.selectedItems.append(.userGroup(userGroupID))
      }
    }

    @MainActor func saveSelection() {
      executor.schedule(.reuse) { @MainActor in
        let existingPermissions: OrderedSet<ResourcePermission> =
          await resourceShareForm
          .currentPermissions()
        let newSelections =
          viewState
          .selectedItems
          .dropFirst(existingPermissions.count)

        for row in newSelections {
          switch row {
          case let .user(userID, _):
            await resourceShareForm
              .setUserPermission(
                userID,
                .read
              )
          case let .userGroup(userGroupID):
            await resourceShareForm
              .setUserGroupPermission(
                userGroupID,
                .read
              )
          }

        }

        await navigation.pop(if: ControlledView.self)
      }
    }

    nonisolated func navigateBack() {
      executor.schedule(.reuse) {
        await navigation.pop(if: PermissionUsersAndGroupsSearchView.self)
      }
    }

    return .init(
      viewState: viewState,
      toggleUserSelection: toggleUserSelection(_:),
      toggleUserGroupSelection: toggleUserGroupSelection(_:),
      saveSelection: saveSelection,
      navigateBack: navigateBack
    )
  }
}
