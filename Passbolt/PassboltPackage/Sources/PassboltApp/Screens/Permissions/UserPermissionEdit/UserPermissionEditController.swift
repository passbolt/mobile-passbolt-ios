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

internal struct UserPermissionEditController {

  internal var viewState: ObservableValue<ViewState>
  internal var setPermissionType: @MainActor (Permission) -> Void
  internal var saveChanges: @MainActor () -> Void
  internal var deletePermission: @MainActor () -> Void
  internal var navigateBack: () -> Void
}

extension UserPermissionEditController: ComponentController {

  internal typealias ControlledView = UserPermissionEditView
  internal typealias Context = (
    resourceID: Resource.ID,
    permissionDetails: UserPermissionDetailsDSV
  )

  @MainActor static func instance(
    in context: Context,
    with features: inout Features,
    cancellables: Cancellables
  ) throws -> Self {
    let features: Features = features

    let diagnostics: OSDiagnostics = features.instance()
    let navigation: DisplayNavigation = try features.instance()
    let userDetails: UserDetails = try features.instance(context: context.permissionDetails.id)
    let resourceShareForm: ResourceShareForm = try features.instance(context: context.resourceID)

    let viewState: ObservableValue<ViewState> = .init(
      initial: .init(
        name: .raw(
          context.permissionDetails.firstName
            + " "
            + context.permissionDetails.lastName
        ),
        username: .raw(context.permissionDetails.username),
        fingerprint: context.permissionDetails.fingerprint,
        permission: context.permissionDetails.permission,
        avatarImageFetch: userDetails.avatarImage
      )
    )

    @MainActor func setPermissionType(
      _ type: Permission
    ) {
      viewState
        .set(\.permission, to: type)
    }

    @MainActor func saveChanges() {
      cancellables.executeOnMainActor {
        await resourceShareForm
          .setUserPermission(
            context.permissionDetails.id,
            viewState.permission
          )
        await navigation.pop(if: UserPermissionEditView.self)
      }
    }

    @MainActor func deletePermission() {
      viewState
        .set(
          \.deleteConfirmationAlert,
          to: .init(
            title: .localized(
              key: .areYouSure
            ),
            message: .localized(
              key: "resource.permission.delete.user.permission.confirmation.message"
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

    @Sendable nonisolated func confirmedDeletePermission() async {
      await resourceShareForm
        .deleteUserPermission(
          context.permissionDetails.id
        )
      await navigation.pop(if: UserPermissionEditView.self)
    }

    nonisolated func navigateBack() {
      Task {
        await navigation.pop(if: UserPermissionEditView.self)
      }
    }

    return Self(
      viewState: viewState,
      setPermissionType: setPermissionType(_:),
      saveChanges: saveChanges,
      deletePermission: deletePermission,
      navigateBack: navigateBack
    )
  }
}
