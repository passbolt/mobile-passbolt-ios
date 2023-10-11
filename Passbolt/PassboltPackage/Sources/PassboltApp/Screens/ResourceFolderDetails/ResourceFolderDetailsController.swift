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
import SessionData
import Users

internal final class ResourceFolderDetailsController: ViewController {

  internal var viewState: ViewStateSource<ViewState>

  private let asyncExecutor: AsyncExecutor
  private let sessionData: SessionData
  private let navigation: DisplayNavigation
  private let users: Users
  private let resourceFolderController: ResourceFolderController

  private let context: ResourceFolder.ID
  private let features: Features

  internal init(
    context: ResourceFolder.ID,
    features: Features
  ) throws {
    let features: Features =
      try features
      .branch(
        scope: ResourceFolderScope.self,
        context: context
      )

		let sessionConfiguration: SessionConfiguration = try features.sessionConfiguration()

    self.context = context
    self.features = features

    self.asyncExecutor = try features.instance()
    self.sessionData = try features.instance()
    self.navigation = try features.instance()
    self.users = try features.instance()
    self.resourceFolderController = try features.instance()

    self.viewState = .init(
      initial: .init(
        folderName: "",
        folderLocation: .init(),
        permissionsListVisible: sessionConfiguration.share.showMembersList,
        folderPermissionItems: .init(),
        folderShared: false
      )
    )

    @Sendable nonisolated func userAvatarImageFetch(
      _ userID: User.ID
    ) -> () async -> Data? {
      { [users] in
        do {
          return try await users.userAvatarImage(userID)
        }
        catch {
          error.logged()
          return nil
        }
      }
    }

    self.asyncExecutor.scheduleIteration(
      over: self.resourceFolderController.state,
      failMessage: "Resource folder details updates broken!",
      failAction: { (error: Error) in
				SnackBarMessageEvent.send(.error(error))
      }
    ) { [viewState] (update: Update<ResourceFolder>) in
      let resourceFolder: ResourceFolder = try update.value
      await viewState.update { viewState in
        viewState.folderName = resourceFolder.name
        viewState.folderLocation = resourceFolder.path.map(\.name)
        viewState.folderPermissionItems = resourceFolder
          .permissions
          .map { (permission: ResourceFolderPermission) -> OverlappingAvatarStackView.Item in
            switch permission {
            case let .user(userID, _, _):
              return .user(
                userID,
                avatarImage: userAvatarImageFetch(userID)
              )

            case let .userGroup(userGroupID, _, _):
              return .userGroup(
                userGroupID
              )
            }
          }
        viewState.folderShared = resourceFolder.shared
      }
    }
  }
}

extension ResourceFolderDetailsController {

  internal struct ViewState: Equatable {

    internal var folderName: String
    internal var folderLocation: Array<String>
    internal var permissionsListVisible: Bool
    internal var folderPermissionItems: Array<OverlappingAvatarStackView.Item>
    internal var folderShared: Bool
  }
}

extension ResourceFolderDetailsController {

  internal final func openLocationDetails() {
    self.asyncExecutor.scheduleCatching(
      behavior: .reuse
    ) { [context, features, navigation] in
      try await navigation
        .push(
          ResourceFolderLocationDetailsView.self,
          controller:
            features
            .instance(context: context)
        )
    }
  }

  internal final func openPermissionDetails() {
    self.asyncExecutor.scheduleCatching(
      behavior: .reuse
    ) { [context, features, navigation] in
      try await navigation
        .push(
          ResourceFolderPermissionListView.self,
          controller:
            features
            .instance(context: context)
        )
    }
  }
}
