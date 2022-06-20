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
import Resources
import UIComponents
import Users

internal struct UserPermissionEditController {

  internal var viewState: ObservableValue<ViewState>
  internal var setPermissionType: (PermissionType) async -> Void
  internal var saveChanges: () async -> Void
  internal var deletePermission: () async -> Void
}

extension UserPermissionEditController: ComponentController {

  internal typealias ControlledView = UserPermissionEditView
  internal typealias NavigationContext = (
    resourceID: Resource.ID,
    permissionDetails: UserPermissionDetailsDSV
  )

  @MainActor static func instance(
    context: NavigationContext,
    navigation: ComponentNavigation<NavigationContext>,
    with features: FeatureFactory,
    cancellables: Cancellables
  ) async throws -> Self {
    let diagnostics: Diagnostics = try await features.instance()
    let userDetails: UserDetails = try await features.instance(context: context.permissionDetails.id)
    let resourceShareForm: ResourceShareForm = try await features.instance(context: context.resourceID)

    let viewState: ObservableValue<ViewState> = .init(
      initial: .init(
        name: .raw(
          context.permissionDetails.firstName
            + " "
            + context.permissionDetails.lastName
        ),
        username: .raw(context.permissionDetails.username),
        fingerprint: context.permissionDetails.fingerprint,
        permissionType: context.permissionDetails.permissionType,
        avatarImageFetch: userDetails.avatarImage
      )
    )

    nonisolated func setPermissionType(_ type: PermissionType) async {
      await viewState.withValue { (state: inout ViewState) in
        state.permissionType = type
      }
    }

    nonisolated func saveChanges() async {
      do {
        await viewState.set(\.loading, to: true)
        try await resourceShareForm
          .setUserPermission(
            context.permissionDetails.id,
            viewState.permissionType
          )
        await navigation.pop(if: UserPermissionEditView.self)
      }
      catch {
        diagnostics.log(error)
        await viewState.withValue { (state: inout ViewState) in
          state.loading = false
          state.snackBarMessage = .error(error)
        }
      }
    }

    nonisolated func deletePermission() async {
      await viewState
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
              Task { @MainActor in
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
      do {
        await viewState.set(\.loading, to: true)
        try await resourceShareForm
          .deleteUserPermission(
            context.permissionDetails.id
          )
        await navigation.pop(if: UserPermissionEditView.self)
      }
      catch {
        diagnostics.log(error)
        await viewState.withValue { (state: inout ViewState) in
          state.loading = false
          state.snackBarMessage = .error(error)
        }
      }
    }

    return Self(
      viewState: viewState,
      setPermissionType: setPermissionType(_:),
      saveChanges: saveChanges,
      deletePermission: deletePermission
    )
  }
}
