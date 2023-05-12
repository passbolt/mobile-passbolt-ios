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
import DatabaseOperations
import Display
import OSFeatures
import Resources
import UIComponents
import Users

internal struct ResourcePermissionListController {

  internal var viewState: ObservableValue<ViewState>
  internal var showUserPermissionDetails: @MainActor (UserPermissionDetailsDSV) -> Void
  internal var showUserGroupPermissionDetails: @MainActor (UserGroupPermissionDetailsDSV) -> Void
  internal var editPermissions: @MainActor () -> Void
  internal var navigateBack: () -> Void
}

extension ResourcePermissionListController: ComponentController {

  internal typealias ControlledView = ResourcePermissionListView
  internal typealias Context = Resource.ID

  @MainActor static func instance(
    in context: Context,
    with features: inout Features,
    cancellables: Cancellables
  ) throws -> Self {
    try features.ensureScope(ResourceDetailsScope.self)

    let diagnostics: OSDiagnostics = features.instance()
    let navigation: DisplayNavigation = try features.instance()
    let executor: AsyncExecutor = try features.instance()
    let users: Users = try features.instance()
    let resourceController: ResourceController = try features.instance()
    let resourceUserPermissionsDetailsFetch: ResourceUserPermissionsDetailsFetchDatabaseOperation =
      try features.instance()
    let resourceUserGroupPermissionsDetailsFetch: ResourceUserGroupPermissionsDetailsFetchDatabaseOperation =
      try features.instance()

    func userAvatarImageFetch(
      _ userID: User.ID
    ) -> () async -> Data? {
      {
        do {
          return try await users.userAvatarImage(userID)
        }
        catch {
          diagnostics.log(error: error)
          return nil
        }
      }
    }

    let viewState: ObservableValue<ViewState> = .init(
      initial: .init(
        permissionListItems: [],
        editable: false,
        snackBarMessage: .none
      )
    )

    executor.schedule { @MainActor in
      do {
        let userGroupPermissionsDetails: Array<PermissionListRowItem> =
          try await resourceUserGroupPermissionsDetailsFetch(context)
          .map { details in
            .userGroup(details: details)
          }

        let userPermissionsDetails: Array<PermissionListRowItem> =
          try await resourceUserPermissionsDetailsFetch(context)
          .map { details in
            .user(
              details: details,
              imageData: userAvatarImageFetch(details.id)
            )
          }
        let canEdit: Bool = try await resourceController.state.value.permission.canShare

        viewState.permissionListItems = userGroupPermissionsDetails + userPermissionsDetails
        viewState.editable = canEdit
      }
      catch {
        viewState.snackBarMessage = .error(error.asTheError().displayableMessage)
        await navigation.pop(if: ControlledView.self)
      }
    }

    nonisolated func showUserPermissionDetails(
      _ details: UserPermissionDetailsDSV
    ) {
      executor.schedule(.reuse) {
        await navigation.push(
          legacy: UserPermissionDetailsView.self,
          context: details
        )
      }
    }

    nonisolated func showUserGroupPermissionDetails(
      _ details: UserGroupPermissionDetailsDSV
    ) {
      executor.schedule(.reuse) {
        await navigation.push(
          legacy: UserGroupPermissionDetailsView.self,
          context: details
        )
      }
    }

    nonisolated func editPermissions() {
      executor.schedule(.reuse) {
        await navigation.replace(
          ResourcePermissionListView.self,
          pushing: ResourcePermissionEditListView.self,
          in: context
        )
      }
    }

    nonisolated func navigateBack() {
      executor.schedule(.reuse) {
        await navigation.pop(if: ResourcePermissionListView.self)
      }
    }

    return Self(
      viewState: viewState,
      showUserPermissionDetails: showUserPermissionDetails(_:),
      showUserGroupPermissionDetails: showUserGroupPermissionDetails(_:),
      editPermissions: editPermissions,
      navigateBack: navigateBack
    )
  }
}
