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

// MARK: - Interface

internal struct ResourceFolderEditController {

  internal var viewState: ViewStateBinding<ViewState>
  internal var setFolderName: (String) -> Void
  internal var saveChanges: () -> Void
}

extension ResourceFolderEditController: ViewController {

  internal typealias Context = ResourceFolderEditForm.Context

  internal struct ViewState: Hashable {

    internal var folderName: Validated<String>
    internal var folderLocation: Array<String>
    internal var folderPermissionItems: Array<OverlappingAvatarStackView.Item>
    internal var loading: Bool
    internal var snackBarMessage: SnackBarMessage?
  }

  #if DEBUG
  static var placeholder: Self {
    .init(
      viewState: .placeholder,
      setFolderName: unimplemented(),
      saveChanges: unimplemented()
    )
  }
  #endif
}

// MARK: - Implementation

extension ResourceFolderEditController {

  @MainActor fileprivate static func load(
    features: FeatureFactory,
    context: Context
  ) async throws -> Self {
    unowned let features: FeatureFactory = features
    let popFeaturesScope: () async -> Void = features.pushScope(.resourceFolderEdit)

    let diagnostics: OSDiagnostics = features.instance()
    let asyncExecutor: AsyncExecutor = try await features.instance()
    let navigation: DisplayNavigation = try await features.instance()
    let users: Users = try await features.instance()
    let resourceFolderEditForm: ResourceFolderEditForm = try await features.instance(context: context)

    @Sendable nonisolated func userAvatarImage(
      for userID: User.ID
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

    @Sendable nonisolated func update(
      viewState: inout ViewState,
      using formState: ResourceFolderEditFormState
    ) {
      viewState.folderName = formState.name
      viewState.folderLocation = formState.location.value.map(\.folderName)
      viewState.folderPermissionItems = formState
        .permissions
        .value
        .map { (permission: ResourceFolderPermissionDSV) -> OverlappingAvatarStackView.Item in
          switch permission {
          case let .user(id: userID, type: _, permissionID: _):
            return .user(
              userID,
              avatarImage: userAvatarImage(for: userID)
            )

          case let .userGroup(id: userGroupID, type: _, permissionID: _):
            return .userGroup(
              userGroupID
            )
          }
        }
    }

    var initialState: ViewState = .init(
      folderName: .valid(""),
      folderLocation: .init(),
      folderPermissionItems: .init(),
      loading: false
    )
    update(
      viewState: &initialState,
      using: resourceFolderEditForm.formState()
    )
    let viewState: ViewStateBinding<ViewState> = .init(
      initial: initialState
    )
    viewState.cancellables.addCleanup {
      Task { await popFeaturesScope() }
    }

    asyncExecutor.schedule(.reuse) { [weak viewState] in
      for await _ in resourceFolderEditForm.formUpdates {
        if let viewState: ViewStateBinding<ViewState> = viewState {
          await viewState.mutate { viewState in
            update(
              viewState: &viewState,
              using: resourceFolderEditForm.formState()
            )
          }
        }
        else {
          diagnostics.log(diagnostic: "Resource folder edit form updates ended.")
        }
      }
    }

    nonisolated func setFolderName(
      _ folderName: String
    ) {
      resourceFolderEditForm.setFolderName(folderName)
    }

    nonisolated func saveChanges() {
      asyncExecutor.schedule(.reuse) {
        await viewState.mutate { viewState in
          viewState.loading = true
        }
        do {
          try await resourceFolderEditForm.sendForm()
          await navigation.pop(ResourceFolderEditView.self)
          await viewState.mutate { viewState in
            viewState.loading = false
          }
        }
        catch {
          await viewState.mutate { viewState in
            viewState.loading = false
            viewState.snackBarMessage = .error(error)
          }
        }
      }
    }

    return .init(
      viewState: viewState,
      setFolderName: setFolderName(_:),
      saveChanges: saveChanges
    )
  }
}

extension FeatureFactory {

  @MainActor public func usePassboltResourceFolderEditController() {
    self.use(
      .disposable(
        ResourceFolderEditController.self,
        load: ResourceFolderEditController.load(features:context:)
      )
    )
  }
}

extension FeaturesScope {

  internal static var resourceFolderEdit: Self {
    .init(identifier: #function)
  }
}
