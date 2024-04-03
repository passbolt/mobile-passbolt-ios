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

internal struct UserGroupPermissionEditController {

  internal var viewState: ObservableValue<ViewState>
  internal var showGroupMembers: () -> Void
  internal var setPermissionType: (Permission) -> Void
  internal var saveChanges: () -> Void
  internal var deletePermission: () -> Void
  internal var navigateBack: () -> Void
}

extension UserGroupPermissionEditController: ComponentController {

  internal typealias ControlledView = UserGroupPermissionEditView
  internal typealias Context = (
    resourceID: Resource.ID,
    permissionDetails: UserGroupPermissionDetailsDSV
  )

  @MainActor static func instance(
    in context: Context,
    with features: inout Features,
    cancellables: Cancellables
  ) throws -> Self {

    let navigation: DisplayNavigation = try features.instance()
    let users: Users = try features.instance()
    let resourceShareForm: ResourceShareForm = try features.instance()

    nonisolated func userAvatarImageFetch(
      _ userID: User.ID
    ) -> () async -> Data? {
      {
        do {
          return try await users.userAvatarImage(userID)
        }
        catch {
          error.logged()
          return nil
        }
      }
    }

    let viewState: ObservableValue<ViewState> = .init(
      initial: .init(
        name: .raw(context.permissionDetails.name),
        permission: context.permissionDetails.permission,
        groupMembersPreviewItems: context
          .permissionDetails
          .members
          .map { user in
            .user(
              user.id,
              avatarImage: userAvatarImageFetch(user.id),
              isSuspended: user.isSuspended
            )
          }
      )
    )

    nonisolated func showGroupMembers() {
      cancellables.executeOnMainActor {
        await navigation
          .push(
            legacy: UserGroupMembersListView.self,
            context: context.permissionDetails.asUserGroupDetails
          )
      }
    }

    nonisolated func setPermissionType(
      _ type: Permission
    ) {
      cancellables.executeOnMainActor {
        viewState.withValue { (state: inout ViewState) in
          state.permission = type
        }
      }
    }

    nonisolated func saveChanges() {
      cancellables.executeOnMainActor {
        await resourceShareForm
          .setUserGroupPermission(
            context.permissionDetails.id,
            viewState.permission
          )
        await navigation.pop(if: UserGroupPermissionEditView.self)
      }
    }

    nonisolated func deletePermission() {
      cancellables.executeOnMainActor {
        viewState
          .set(
            \.deleteConfirmationAlert,
            to: .init(
              title: .localized(
                key: .areYouSure
              ),
              message: .localized(
                key: "resource.permission.delete.user.group.permission.confirmation.message"
              ),
              destructive: true,
              confirmAction: {
                Task {
                  await confirmedDeletePermission()
                }
              },
              confirmLabel: .localized(
                key: .confirm
              )
            )
          )
      }
    }

    @Sendable nonisolated func confirmedDeletePermission() async {
      await resourceShareForm
        .deleteUserGroupPermission(
          context.permissionDetails.id
        )
      await navigation.pop(if: UserGroupPermissionEditView.self)
    }

    nonisolated func navigateBack() {
      Task {
        await navigation.pop(if: UserGroupPermissionEditView.self)
      }
    }

    return Self(
      viewState: viewState,
      showGroupMembers: showGroupMembers,
      setPermissionType: setPermissionType(_:),
      saveChanges: saveChanges,
      deletePermission: deletePermission,
      navigateBack: navigateBack
    )
  }
}
