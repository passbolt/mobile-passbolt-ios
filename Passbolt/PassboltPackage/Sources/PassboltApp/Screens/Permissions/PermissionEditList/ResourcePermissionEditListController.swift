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
import FeatureScopes
import Metadata
import OSFeatures
import Resources
import SharedUIComponents
import UIComponents
import Users

internal final class ResourcePermissionEditListController: @MainActor ViewController {

  internal typealias Context = Resource.ID

  internal struct ViewState: Equatable {

    internal var permissionListItems: Array<PermissionListRowItem>
    internal var loading: Bool = false
  }

  internal let viewState: ViewStateSource<ViewState>
  private let resourceShareForm: ResourceShareForm
  private let navigationToPermissionsSelection: NavigationToPermissionUsersAndGroupsSearch
  private let navigationToSelf: NavigationToResourceShare
  private let navigationToMetadataPinnedKeyValidation: NavigationToMetadataPinnedKeyValidationDialog
  private let navigationToUserPermissionEdit: NavigationToUserPermissionEdit
  private let navigationToUserGroupPermissionEdit: NavigationToUserGroupPermissionEdit
  private let navigationToPermissionDetails: NavigationToResourcePermissionsDetails
  private let context: Context

  internal init(context: Resource.ID, features: Features) throws {
    self.context = context
    let features: Features =
      try features
      .branch(
        scope: ResourceScope.self,
        context: context
      )
      .branch(scope: ResourceShareScope.self)
    self.navigationToPermissionsSelection = try features.instance()
    self.navigationToSelf = try features.instance()
    self.navigationToMetadataPinnedKeyValidation = try features.instance()
    self.navigationToUserPermissionEdit = try features.instance()
    self.navigationToUserGroupPermissionEdit = try features.instance()
    self.navigationToPermissionDetails = try features.instance()

    let resourceShareForm: ResourceShareForm = try features.instance()
    self.resourceShareForm = resourceShareForm

    self.viewState = .init(
      initial: .init(permissionListItems: .init()),
      updateFrom: resourceShareForm.permissionsSequence(),
      update: { update, permissions in
        let listItems: Array<PermissionListRowItem> =
          try await createListItems(from: permissions.value, using: features)
        update { state in
          state.permissionListItems = listItems
        }
      }
    )
  }

  internal func addPermission() async {
    await consumingErrors {
      try await navigationToPermissionsSelection.perform(context: context)
    }
  }

  internal func showUserPermissionEdit(_ details: UserPermissionDetailsDSV) async {
    await consumingErrors {
      try await navigationToUserPermissionEdit.perform(
        context: (
          resourceID: context,
          permissionDetails: details
        )
      )
    }
  }

  internal func showUserGroupPermissionEdit(
    _ details: UserGroupPermissionDetailsDSV
  ) async {
    await consumingErrors {
      try await self.navigationToUserGroupPermissionEdit.perform(
        context: (
          resourceID: context,
          permissionDetails: details
        )
      )
    }
  }

  internal func saveChanges() async {
    viewState.update(\.loading, to: true)
    defer {
      viewState.update(\.loading, to: false)
    }
    do {
      try await resourceShareForm.sendForm()
      try await navigationToPermissionDetails.revert()
      try await navigationToSelf.revert()
    }
    catch let error as MetadataPinnedKeyValidationError {

      let context: MetadataPinnedKeyValidationDialogViewController.Context = .init(
        reason: error.reason,
        onTrustedKey: { [weak self] in
          try await self?.navigationToMetadataPinnedKeyValidation.revert()
          await self?.saveChanges()
        },
        onCancel: { [weak self] in
          await consumingErrors {
            try await self?.navigationToMetadataPinnedKeyValidation.revert()
          }
        }
      )
      await consumingErrors {
        try await navigationToMetadataPinnedKeyValidation.perform(context: context)
      }
    }
    catch {
      error.consume()
    }
  }
}

private func createListItems(
  from permissions: OrderedSet<ResourcePermission>,
  using features: Features
) async throws -> Array<PermissionListRowItem> {
  var listItems: Array<PermissionListRowItem> = .init()
  listItems.reserveCapacity(permissions.count)

  for permission: ResourcePermission in permissions {
    switch permission {
    case .user(let userID, let permission, _):
      let userDetails: UserDetails =
        try await features
        .branch(
          scope: UserScope.self,
          context: userID
        )
        .instance(of: UserDetails.self)

      let details: UserDetailsDSV =
        try await userDetails
        .details()

      listItems
        .append(
          .user(
            details: .init(
              id: userID,
              username: details.username,
              firstName: details.firstName,
              lastName: details.lastName,
              fingerprint: details.fingerprint,
              avatarImageURL: details.avatarImageURL,
              permission: permission,
              isSuspended: details.isSuspended
            ),
            imageData: userDetails.avatarImage
          )
        )

    case .userGroup(let userGroupID, let permission, _):
      let details: UserGroupDetailsDSV =
        try await features
        .branchIfNeeded(
          scope: UserGroupScope.self,
          context: userGroupID
        )
        .instance(of: UserGroupDetails.self)
        .details()

      listItems
        .append(
          .userGroup(
            details: .init(
              id: userGroupID,
              name: details.name,
              permission: permission,
              members: details.members
            )
          )
        )
    }

  }

  return listItems
}
