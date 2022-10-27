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
import Resources
import UIComponents
import Users
import Display

internal struct ResourceFolderPermissionListController {

  @IID var id
  internal var viewState: ViewStateBinding<ViewState>
  internal var viewActions: ViewActions
}

extension ResourceFolderPermissionListController: ViewController {

  internal typealias Context = ResourceFolder.ID

  internal struct ViewState: Hashable {

    internal var permissionListItems: Array<PermissionListRowItem>
    internal var snackBarMessage: SnackBarMessage? = .none
  }

  internal struct ViewActions: ViewControllerActions {

    internal var showUserPermissionDetails: (UserPermissionDetailsDSV) -> Void
    internal var showUserGroupPermissionDetails: (UserGroupPermissionDetailsDSV) -> Void
    internal var navigateBack: () -> Void

#if DEBUG
  static var placeholder: Self {
    .init(
      showUserPermissionDetails: unimplemented(),
      showUserGroupPermissionDetails: unimplemented(),
      navigateBack: unimplemented()
    )
  }
#endif
  }

#if DEBUG
  static var placeholder: Self {
    .init(
      viewState: .placeholder,
      viewActions: .placeholder
    )
  }
#endif
}

extension ResourceFolderPermissionListController {

  @MainActor static func load(
    features: FeatureFactory,
    context: Context
  ) async throws -> Self {
    let diagnostics: Diagnostics = features.instance()
    let asyncExecutor: AsyncExecutor = features.instance(of: AsyncExecutor.self).detach()
    let navigation: DisplayNavigation = try await features.instance()
    let users: Users = try await features.instance()
    let resourceFolderDetails: ResourceFolderDetails = try await features.instance(context: context)
    let resourceFolderUserPermissionsDetailsFetch: ResourceFolderUserPermissionsDetailsFetchDatabaseOperation =
      try await features.instance()
    let resourceFolderUserGroupPermissionsDetailsFetch: ResourceFolderUserGroupPermissionsDetailsFetchDatabaseOperation =
      try await features.instance()

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

    let viewState: ViewStateBinding<ViewState>

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

      viewState = .init(
        initial: .init(
          permissionListItems: userGroupPermissionsDetails + userPermissionsDetails
        )
      )
    }
    catch {
      viewState = .init(
        initial: .init(
          permissionListItems: [],
          snackBarMessage: .error(error)
        ),
        cleanup: {
          asyncExecutor.clearTasks()
        }
      )
      diagnostics.log(error: error)
      await navigation.pop( ResourceFolderPermissionListView.self)
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
        await navigation.pop( ResourceFolderPermissionListView.self)
      }
    }

    return Self(
      viewState: viewState,
      viewActions: .init(
        showUserPermissionDetails: showUserPermissionDetails(_:),
        showUserGroupPermissionDetails: showUserGroupPermissionDetails(_:),
        navigateBack: navigateBack
      )
    )
  }
}

extension FeatureFactory {

  @MainActor public func usePassboltResourceFolderPermissionListController() {
    self.use(
      .disposable(
        ResourceFolderPermissionListController.self,
        load: ResourceFolderPermissionListController.load(features:context:)
      )
    )
  }
}
