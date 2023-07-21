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

internal final class ResourceFolderPermissionListController: ViewController {

  internal var viewState: ViewStateSource<ViewState>

  private let asyncExecutor: AsyncExecutor
  private let navigation: DisplayNavigation
  private let users: Users
  private let resourceFolderController: ResourceFolderController
  private let resourceFolderUserPermissionsDetailsFetch: ResourceFolderUserPermissionsDetailsFetchDatabaseOperation
  private let resourceFolderUserGroupPermissionsDetailsFetch:
    ResourceFolderUserGroupPermissionsDetailsFetchDatabaseOperation

  private let context: ResourceFolder.ID
  private let features: Features

  internal init(
    context: ResourceFolder.ID,
    features: Features
  ) throws {
    self.context = context
    self.features = features

    self.asyncExecutor = try features.instance()
    self.navigation = try features.instance()
    self.users = try features.instance()
    self.resourceFolderController = try features.instance(context: context)
    self.resourceFolderUserPermissionsDetailsFetch = try features.instance()
    self.resourceFolderUserGroupPermissionsDetailsFetch = try features.instance()

    @Sendable nonisolated func userAvatarImageFetch(
      _ userID: User.ID
    ) -> () async -> Data? {
      { [users] in
        do {
          return try await users.userAvatarImage(userID)
        }
        catch {
          Diagnostics.log(error: error)
          return nil
        }
      }
    }

    self.viewState = .init(
      initial: .init(
        permissionListItems: [],
        snackBarMessage: .none
      )
    )

    self.asyncExecutor.scheduleIteration(
      over: self.resourceFolderController.state,
      failMessage: "Resource folder permissions list updates broken!",
      failAction: { [viewState] (error: Error) in
        await viewState.update(\.snackBarMessage, to: .error(error))
      }
    ) {
      [viewState, resourceFolderUserGroupPermissionsDetailsFetch, resourceFolderUserPermissionsDetailsFetch] (
        update: Update<ResourceFolder>
      ) in
      let userGroupPermissionsDetails: Array<PermissionListRowItem> =
        try await resourceFolderUserGroupPermissionsDetailsFetch(context)
        .map { details in
          .userGroup(details: details)
        }

      let userPermissionsDetails: Array<PermissionListRowItem> =
        try await resourceFolderUserPermissionsDetailsFetch(context)
        .map { details in
          .user(
            details: details,
            imageData: userAvatarImageFetch(details.id)
          )
        }

      await viewState
        .update(
          \.permissionListItems,
          to: userGroupPermissionsDetails + userPermissionsDetails
        )
    }
  }
}

extension ResourceFolderPermissionListController {

  internal struct ViewState: Equatable {

    internal var permissionListItems: Array<PermissionListRowItem>
    internal var snackBarMessage: SnackBarMessage? = .none
  }
}

extension ResourceFolderPermissionListController {

  internal final func showUserPermissionDetails(
    _ details: UserPermissionDetailsDSV
  ) {
    self.asyncExecutor.schedule(.reuse) { [navigation] in
      await navigation.push(
        legacy: UserPermissionDetailsView.self,
        context: details
      )
    }
  }

  internal final func showUserGroupPermissionDetails(
    _ details: UserGroupPermissionDetailsDSV
  ) {
    self.asyncExecutor.schedule(.reuse) { [navigation] in
      await navigation.push(
        legacy: UserGroupPermissionDetailsView.self,
        context: details
      )
    }
  }

  internal final func navigateBack() {
    self.asyncExecutor.schedule(.reuse) { [navigation] in
      await navigation.pop(ResourceFolderPermissionListView.self)
    }
  }
}
