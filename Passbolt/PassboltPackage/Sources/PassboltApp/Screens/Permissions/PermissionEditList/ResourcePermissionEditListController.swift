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

internal struct ResourcePermissionEditListController {

  internal var viewState: ObservableValue<ViewState>
  internal var addPermission: @MainActor () -> Void
  internal var showUserPermissionEdit: @MainActor (UserPermissionDetailsDSV) -> Void
  internal var showUserGroupPermissionEdit: @MainActor (UserGroupPermissionDetailsDSV) -> Void
  internal var saveChanges: @MainActor () -> Void
  internal var navigateBack: () -> Void
}

extension ResourcePermissionEditListController: ComponentController {

  internal typealias ControlledView = ResourcePermissionEditListView
  internal typealias Context = Resource.ID

  @MainActor static func instance(
    in context: Context,
    with features: inout Features,
    cancellables: Cancellables
  ) throws -> Self {
    features =
      try features
      .branch(
        scope: ResourceScope.self,
        context: context
      )
      .branch(scope: ResourceShareScope.self)
    let features: Features = features
    let navigation: DisplayNavigation = try features.instance()

    let resourceShareForm: ResourceShareForm = try features.instance()

    let viewState: ObservableValue<ViewState>

    viewState = .init(
      initial: .init(
        permissionListItems: []
      )
    )

    cancellables.executeAsync {
      try await resourceShareForm
        .permissionsSequence()
        .forEach { (permissions: OrderedSet<ResourcePermission>) in
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
          await viewState
            .set(
              \.permissionListItems,
              to: listItems
            )
        }
    }

    nonisolated func addPermission() {
      cancellables.executeOnMainActor {
        await navigation
          .push(
            legacy: PermissionUsersAndGroupsSearchView.self,
            context: context
          )
      }
    }

    nonisolated func showUserPermissionEdit(
      _ details: UserPermissionDetailsDSV
    ) {
      cancellables.executeOnMainActor {
        await navigation.push(
          legacy: UserPermissionEditView.self,
          context: (
            resourceID: context,
            permissionDetails: details
          )
        )
      }
    }

    nonisolated func showUserGroupPermissionEdit(
      _ details: UserGroupPermissionDetailsDSV
    ) {
      cancellables.executeOnMainActor {
        await navigation.push(
          legacy: UserGroupPermissionEditView.self,
          context: (
            resourceID: context,
            permissionDetails: details
          )
        )
      }
    }

    @MainActor func saveChanges() {
      viewState.set(\.loading, to: true)
      cancellables.executeOnMainActor {
        do {
          try await resourceShareForm.sendForm()
          await navigation
            .pop(if: ResourcePermissionEditListView.self)
          viewState.set(\.loading, to: false)
        }
        catch let error as MetadataPinnedKeyValidationError {
          viewState.withValue { (state: inout ViewState) in
            state.loading = false
          }
          let context: MetadataPinnedKeyValidationDialogViewController.Context = .init(
            reason: error.reason,
            onTrustedKey: {
              Task {
                await navigation.pop(MetadataPinnedKeyValidationDialogView.self)
                saveChanges()
              }
            },
            onCancel: {
              Task {
                await navigation.pop(MetadataPinnedKeyValidationDialogView.self)
              }
            }
          )
          let controller: MetadataPinnedKeyValidationDialogViewController =
            try .init(context: context, features: features)

          Task {
            await navigation.push(MetadataPinnedKeyValidationDialogView.self, controller: controller)
          }
        }
        catch {
          error.consume()
          viewState.withValue { (state: inout ViewState) in
            state.loading = false
          }
        }
      }
    }

    nonisolated func navigateBack() {
      Task {
        await navigation.pop(if: ResourcePermissionEditListView.self)
      }
    }

    return Self(
      viewState: viewState,
      addPermission: addPermission,
      showUserPermissionEdit: showUserPermissionEdit(_:),
      showUserGroupPermissionEdit: showUserGroupPermissionEdit(_:),
      saveChanges: saveChanges,
      navigateBack: navigateBack
    )
  }
}
