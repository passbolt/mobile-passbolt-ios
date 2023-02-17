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

internal struct ResourceFolderPermissionListController {

  internal var viewState: MutableViewState<ViewState>
  internal var showUserPermissionDetails: (UserPermissionDetailsDSV) -> Void
  internal var showUserGroupPermissionDetails: (UserGroupPermissionDetailsDSV) -> Void
  internal var navigateBack: () -> Void
}

extension ResourceFolderPermissionListController: ViewController {

  internal typealias Context = ResourceFolder.ID

  internal struct ViewState: Hashable {

    internal var permissionListItems: Array<PermissionListRowItem>
    internal var snackBarMessage: SnackBarMessage? = .none
  }

  #if DEBUG
  static var placeholder: Self {
    .init(
      viewState: .placeholder(),
      showUserPermissionDetails: unimplemented1(),
      showUserGroupPermissionDetails: unimplemented1(),
      navigateBack: unimplemented0()
    )
  }
  #endif
}

extension ResourceFolderPermissionListController {

  @MainActor static func load(
    features: Features,
    context: Context
  ) throws -> Self {
    let diagnostics: OSDiagnostics = features.instance()
    let asyncExecutor: AsyncExecutor = try features.instance()
    let navigation: DisplayNavigation = try features.instance()
    let users: Users = try features.instance()
    let resourceFolderDetails: ResourceFolderDetails = try features.instance(context: context)
    let resourceFolderUserPermissionsDetailsFetch: ResourceFolderUserPermissionsDetailsFetchDatabaseOperation =
      try features.instance()
    let resourceFolderUserGroupPermissionsDetailsFetch:
      ResourceFolderUserGroupPermissionsDetailsFetchDatabaseOperation =
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

    let viewState: MutableViewState<ViewState> = .init(
      initial: .init(
        permissionListItems: [],
        snackBarMessage: .none
      )
    )

    asyncExecutor.schedule { @MainActor in
      do {
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

        viewState
          .update(
            \.permissionListItems,
            to: userGroupPermissionsDetails + userPermissionsDetails
          )
      }
      catch {
        diagnostics.log(error: error)
        await navigation.pop(ResourceFolderPermissionListView.self)
      }
    }

    nonisolated func showUserPermissionDetails(
      _ details: UserPermissionDetailsDSV
    ) {
      asyncExecutor.schedule(.reuse) {
        await navigation.push(
          legacy: UserPermissionDetailsView.self,
          context: details
        )
      }
    }

    nonisolated func showUserGroupPermissionDetails(
      _ details: UserGroupPermissionDetailsDSV
    ) {
      asyncExecutor.schedule(.reuse) {
        await navigation.push(
          legacy: UserGroupPermissionDetailsView.self,
          context: details
        )
      }
    }

    nonisolated func navigateBack() {
      asyncExecutor.schedule(.reuse) {
        await navigation.pop(ResourceFolderPermissionListView.self)
      }
    }

    return Self(
      viewState: viewState,
      showUserPermissionDetails: showUserPermissionDetails(_:),
      showUserGroupPermissionDetails: showUserGroupPermissionDetails(_:),
      navigateBack: navigateBack
    )
  }
}

extension FeaturesRegistry {

  public mutating func usePassboltResourceFolderPermissionListController() {
    self.use(
      .disposable(
        ResourceFolderPermissionListController.self,
        load: ResourceFolderPermissionListController.load(features:context:)
      ),
      in: SessionScope.self
    )
  }
}
