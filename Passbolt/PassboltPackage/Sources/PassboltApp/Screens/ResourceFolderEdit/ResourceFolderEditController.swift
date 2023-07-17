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
import Users

internal final class ResourceFolderEditController: ViewController {

  internal nonisolated let viewState: ViewStateSource<ViewState>

  private let asyncExecutor: AsyncExecutor
  private let navigation: DisplayNavigation
  private let users: Users
  private let resourceFolderEditForm: ResourceFolderEditForm

  private let context: ResourceFolderEditForm.Context
  private let features: Features

  internal init(
    context: ResourceFolderEditForm.Context,
    features: Features
  ) throws {
    let features: FeaturesContainer = features.branch(
      scope: ResourceFolderEditScope.self,
      context: context.editedFolderID
    )
    self.context = context
    self.features = features

    self.asyncExecutor = try features.instance()
    self.navigation = try features.instance()
    self.users = try features.instance()
    let resourceFolderEditForm: ResourceFolderEditForm = try features.instance(context: context)
    self.resourceFolderEditForm = resourceFolderEditForm

    var initialState: ViewState = .init(
      folderName: .valid(""),
      folderLocation: .init(),
      folderPermissionItems: .init(),
      loading: false
    )
    Self.update(
      viewState: &initialState,
      using: resourceFolderEditForm.formState(),
      users: users
    )
    self.viewState = .init(
      initial: initialState,
      updateUsing: self.resourceFolderEditForm.updates,
      update: { [users, resourceFolderEditForm] (viewState: inout ViewState) in
        Self.update(
          viewState: &viewState,
          using: resourceFolderEditForm.formState(),
          users: users
        )
      }
    )
  }
}

extension ResourceFolderEditController {

  internal struct ViewState: Equatable {

    internal var folderName: Validated<String>
    internal var folderLocation: Array<String>
    internal var folderPermissionItems: Array<OverlappingAvatarStackView.Item>
    internal var loading: Bool
    internal var snackBarMessage: SnackBarMessage?
  }
}

extension ResourceFolderEditController {

  @Sendable nonisolated static func update(
    viewState: inout ViewState,
    using formState: ResourceFolderEditFormState,
    users: Users
  ) {
    viewState.folderName = formState.name
    viewState.folderLocation = formState.location.value.map(\.folderName)
    viewState.folderPermissionItems = formState
      .permissions
      .value
      .map { (permission: ResourceFolderPermission) -> OverlappingAvatarStackView.Item in
        switch permission {
        case let .user(id: userID, _, _):
          return .user(
            userID,
            avatarImage: { try? await users.userAvatarImage(userID) }
          )

        case let .userGroup(id: userGroupID, _, _):
          return .userGroup(
            userGroupID
          )
        }
      }
  }

  @Sendable nonisolated internal final func setFolderName(
    _ folderName: String
  ) {
    self.resourceFolderEditForm.setFolderName(folderName)
  }

  internal final func saveChanges() {
    self.asyncExecutor.schedule(.reuse) { [viewState, resourceFolderEditForm, navigation] in
      await viewState.update { viewState in
        viewState.loading = true
      }
      do {
        try await resourceFolderEditForm.sendForm()
        await navigation.pop(ResourceFolderEditView.self)
        await viewState.update { viewState in
          viewState.loading = false
        }
      }
      catch {
        await viewState.update { viewState in
          viewState.loading = false
          viewState.snackBarMessage = .error(error)
        }
      }
    }
  }
}
