//
// Passbolt - Open source password manager for teams
// Copyright (c) 2021 Passbolt SA
//
// This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General
// Public License (AGPL) as published by the Free Software Foundation version 3.
//
// The name "Passbolt" is a registered trademark ceof Passbolt SA, and Passbolt SA hereby declines to grant a trademark
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
import Resources
import Users

// MARK: - Interface

internal struct ResourceFolderDetailsController {

  @IID internal var id
  internal var viewState: ViewStateBinding<ViewState>
  internal var viewActions: ViewActions
}

extension ResourceFolderDetailsController: ViewController {

  internal typealias Context = ResourceFolder.ID

  internal struct ViewState: Hashable {

    internal var folderName: String
    internal var folderLocation: Array<String>
    internal var folderPermissionItems: Array<OverlappingAvatarStackView.Item>
    internal var folderShared: Bool
    internal var snackBarMessage: SnackBarMessage?
  }

  internal struct ViewActions: ViewControllerActions {

    internal var openLocationDetails: () -> Void
    internal var openPermissionDetails: () -> Void

    #if DEBUG
    static var placeholder: Self {
      .init(
        openLocationDetails: unimplemented(),
        openPermissionDetails: unimplemented()
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

// MARK: - Implementation

extension ResourceFolderDetailsController {

  fileprivate static func load(
    features: FeatureFactory,
    context: Context
  ) async throws -> Self {
    unowned let features: FeatureFactory = features
    let popFeaturesScope: () async -> Void = await features.pushScope(.resourceFolderDetails)

    let diagnostics: Diagnostics = await features.instance()
    let asyncExecutor: AsyncExecutor = await features.instance(of: AsyncExecutor.self).detach()
    let navigation: DisplayNavigation = try await features.instance()
    let users: Users = try await features.instance()
    let folderDetails: ResourceFolderDetails = try await features.instance(context: context)

    @Sendable func userAvatarImage(
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

    @Sendable func update(
      viewState: inout ViewState,
      using details: ResourceFolderDetailsDSV
    ) {
      viewState.folderName = details.name
      viewState.folderLocation = details.location.map(\.folderName)
      viewState.folderPermissionItems = details
        .permissions
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
      viewState.folderShared = details.shared
    }

    let viewState: ViewStateBinding<ViewState> = .init(
      initial: .init(
        folderName: "",
        folderLocation: .init(),
        folderPermissionItems: .init(),
        folderShared: false
      ),
      cleanup: {
        await popFeaturesScope()
        asyncExecutor.clearTasks()
      }
    )

    asyncExecutor.schedule(.reuse) { [weak viewState] in
      for await details: ResourceFolderDetailsDSV in folderDetails.details {
        if let viewState: ViewStateBinding<ViewState> = viewState {
          update(
            viewState: &viewState.wrappedValue,
            using: details
          )
        }
        else {
          diagnostics.log(diagnostic: "Resource folder details updates ended.")
        }
      }
    }

    func openLocationDetails() {
      // TODO: MOB-611
    }

    func openPermissionDetails() {
      // TODO: MOB-611
    }

    return .init(
      viewState: viewState,
      viewActions: .init(
        openLocationDetails: openLocationDetails,
        openPermissionDetails: openPermissionDetails
      )
    )
  }
}

extension FeatureFactory {

  @MainActor public func usePassboltResourceFolderDetailsController() {
    self.use(
      .disposable(
        ResourceFolderDetailsController.self,
        load: ResourceFolderDetailsController.load(features:context:)
      )
    )
  }
}

extension FeaturesScope {

  internal static var resourceFolderDetails: Self {
    .init(identifier: #function)
  }
}
