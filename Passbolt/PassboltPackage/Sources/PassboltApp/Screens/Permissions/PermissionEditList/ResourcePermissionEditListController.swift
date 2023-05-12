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
      features
      .branch(
        scope: ResourceDetailsScope.self,
        context: context
      )
      .branch(
        scope: ResourceShareScope.self,
        context: context
      )
    let features: Features = features
    let navigation: DisplayNavigation = try features.instance()
    let diagnostics: OSDiagnostics = features.instance()
    let resourceShareForm: ResourceShareForm = try features.instance(context: context)

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
            case let .user(userID, permission, _):
              let userDetails: UserDetails =
                try await features
                .instance(
                  of: UserDetails.self,
                  context: userID
                )

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
                      permission: permission
                    ),
                    imageData: userDetails.avatarImage
                  )
                )

            case let .userGroup(userGroupID, permission, _):
              let details: UserGroupDetailsDSV =
                try await features
                .instance(
                  of: UserGroupDetails.self,
                  context: userGroupID
                )
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
        catch {
          diagnostics.log(error: error)
          viewState.withValue { (state: inout ViewState) in
            state.loading = false
            state.snackBarMessage = .error(error)
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
