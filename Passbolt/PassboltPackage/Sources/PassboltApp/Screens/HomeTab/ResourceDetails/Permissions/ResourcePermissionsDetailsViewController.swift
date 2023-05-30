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

import Display
import OSFeatures
import Resources
import Users

internal final class ResourcePermissionsDetailsViewController: ViewController {

  internal struct ViewState: Equatable {

    internal var editable: Bool
    internal var permissionListItems: Array<PermissionListRowItem>
    internal var snackBarMessage: SnackBarMessage?
  }

  internal nonisolated let viewState: MutableViewState<ViewState>

  private let navigationToSelf: NavigationToResourcePermissionsDetails

  private let resourceController: ResourceController
  private let users: Users
  private let legacyNavigation: DisplayNavigation

  private let diagnostics: OSDiagnostics
  private let asyncExecutor: AsyncExecutor

  private let resourceID: Resource.ID

  internal init(
    context: Void,
    features: Features
  ) throws {
    try features.ensureScope(ResourceDetailsScope.self)
    self.resourceID = try features.context(of: ResourceDetailsScope.self)

    self.navigationToSelf = try features.instance()

    self.diagnostics = features.instance()
    self.asyncExecutor = try features.instance()

    self.resourceController = try features.instance()
    self.users = try features.instance()
    self.legacyNavigation = try features.instance()

    self.viewState = .init(
      initial: .init(
        editable: false,
        permissionListItems: .init(),
        snackBarMessage: .none
      )
    )
  }
}

extension ResourcePermissionsDetailsViewController {

  @Sendable internal func activate() async {
    await self.diagnostics
      .withLogCatch(
        info: .message("Resource permissions details updates broken!"),
        fallback: { [navigationToSelf] in
          try? await navigationToSelf.revert()
        }
      ) {
        for try await resource in self.resourceController.state {
          await self.update(resource)
        }
      }
  }

  internal func update(
    _ resource: Resource
  ) async {
    @Sendable func avatarImageFetch(
      for userID: User.ID
    ) -> @Sendable () async -> Data? {
      { [users] () async -> Data? in
        try? await users.userAvatarImage(userID)
      }
    }

    do {
      let userGroupPermissionsDetails: Array<PermissionListRowItem> =
        try await self.resourceController.loadUserGroupPermissionsDetails()
        .map { details in
          .userGroup(details: details)
        }

      let userPermissionsDetails: Array<PermissionListRowItem> =
        try await self.resourceController.loadUserPermissionsDetails()
        .map { details in
          .user(
            details: details,
            imageData: avatarImageFetch(for: details.id)
          )
        }

      self.viewState.update { (state: inout ViewState) in
        state.permissionListItems = userGroupPermissionsDetails + userPermissionsDetails
        state.editable = resource.permission.canEdit
      }
    }
    catch {
      self.viewState.update(\.snackBarMessage, to: .error(error))
    }
  }

  nonisolated func showUserPermissionDetails(
    _ details: UserPermissionDetailsDSV
  ) {
    self.asyncExecutor.schedule(.reuse) { [legacyNavigation] in
      await legacyNavigation.push(
        legacy: UserPermissionDetailsView.self,
        context: details
      )
    }
  }

  nonisolated func showUserGroupPermissionDetails(
    _ details: UserGroupPermissionDetailsDSV
  ) {
    self.asyncExecutor.schedule(.reuse) { [legacyNavigation] in
      await legacyNavigation.push(
        legacy: UserGroupPermissionDetailsView.self,
        context: details
      )
    }
  }

  nonisolated func editPermissions() {
    self.asyncExecutor.schedule(.reuse) { [legacyNavigation, resourceID] in
      await legacyNavigation.replace(
        UIHostingController<ResourcePermissionsDetailsView>.self,
        pushing: ResourcePermissionEditListView.self,
        in: resourceID
      )
    }
  }
}
