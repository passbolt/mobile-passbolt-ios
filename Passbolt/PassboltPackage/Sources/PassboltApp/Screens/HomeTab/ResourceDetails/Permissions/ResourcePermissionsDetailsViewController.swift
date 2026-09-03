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
import FeatureScopes
import OSFeatures
import Resources
import SharedUIComponents
import Users

internal final class ResourcePermissionsDetailsViewController: ViewController {

  internal struct ViewState: Equatable {

    internal var editable: Bool
    internal var permissionListItems: Array<PermissionListRowItem>
  }

  internal nonisolated let viewState: ViewStateSource<ViewState>

  private let navigationToSelf: NavigationToResourcePermissionsDetails
  private let navigationToUserPermissionDetails: NavigationToUserPermissionDetails
  private let navigationToGroupPermissionDetails: NavigationToUserGroupPermissionDetails

  private let resourceController: ResourceController
  private let users: Users

  private let features: Features
  private let resourceID: Resource.ID

  internal init(
    context: Void,
    features: Features
  ) throws {
    try features.ensureScope(ResourceScope.self)
    self.resourceID = try features.context(of: ResourceScope.self)
    self.features = features.takeOwned()

    self.navigationToSelf = try features.instance()
    self.navigationToUserPermissionDetails = try features.instance()
    self.navigationToGroupPermissionDetails = try features.instance()

    self.resourceController = try features.instance()
    self.users = try features.instance()

    self.viewState = .init(
      initial: .init(
        editable: false,
        permissionListItems: .init()
      )
    )
  }
}

extension ResourcePermissionsDetailsViewController {

  @Sendable internal func activate() async {
    await consumingErrors(
      errorDiagnostics: "Resource permissions details updates broken!",
      fallback: { @Sendable in
        try? await self.navigationToSelf.revert()
      },
      { @Sendable in
        for try await resource in self.resourceController.state {
          try await self.update(resource.value)
        }
      }
    )
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
        // Editing permissions requires ownership, not merely edit access.
        state.editable = resource.permission.canShare
      }
    }
    catch {
      SnackBarMessageEvent.send(.error(error))
    }
  }

  internal func showUserPermissionDetails(
    _ details: UserPermissionDetailsDSV
  ) async {
    await consumingErrors {
      try await navigationToUserPermissionDetails.perform(context: details)
    }
  }

  internal func showUserGroupPermissionDetails(
    _ details: UserGroupPermissionDetailsDSV
  ) async {
    await consumingErrors {
      try await navigationToGroupPermissionDetails.perform(context: details)
    }
  }

  /// Opens the confirmation the operator edits and confirms the recipients on - sharing has no separate editing
  /// screen, so this is where a change to who holds the secret is composed.
  internal func editPermissions() async {
    await consumingErrors {
      let permissionConfirmation: ResourceSharePermissionConfirmation = try await .init(
        features: self.features,
        resourceID: self.resourceID
      )
      try await permissionConfirmation.present()
    }
  }
}
