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
import SessionData
import Users

// MARK: - Interface

internal struct ResourceFolderDetailsController {

  internal var viewState: MutableViewState<ViewState>
  internal var openLocationDetails: () -> Void
  internal var openPermissionDetails: () -> Void
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

  #if DEBUG
  static var placeholder: Self {
    .init(
      viewState: .placeholder(),
      openLocationDetails: unimplemented0(),
      openPermissionDetails: unimplemented0()
    )
  }
  #endif
}

// MARK: - Implementation

extension ResourceFolderDetailsController {

  @MainActor fileprivate static func load(
    features: Features,
    context: Context
  ) throws -> Self {
    let features: Features =
      features
      .branch(
        scope: ResourceFolderDetailsScope.self,
        context: context
      )
    let diagnostics: OSDiagnostics = features.instance()
    let asyncExecutor: AsyncExecutor = try features.instance()
    let sessionData: SessionData = try features.instance()
    let navigation: DisplayNavigation = try features.instance()
    let users: Users = try features.instance()
    let folderDetails: ResourceFolderDetails = try features.instance(context: context)

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

    let viewState: MutableViewState<ViewState> = .init(
      initial: .init(
        folderName: "",
        folderLocation: .init(),
        folderPermissionItems: .init(),
        folderShared: false
      )
    )

    asyncExecutor.schedule(.reuse) {
      for await _ in sessionData.updatesSequence {
        do {
          let details: ResourceFolderDetailsDSV = try await folderDetails.details()
          await viewState.update { viewState in
            update(
              viewState: &viewState,
              using: details
            )
          }
        }
        catch {
          diagnostics.log(error: error)
        }
      }  // break
    }

    func openLocationDetails() {
      asyncExecutor.schedule(.reuse) {
        do {
          try await navigation
            .push(
              ResourceFolderLocationDetailsView.self,
              controller:
                features
                .instance(context: context)
            )
        }
        catch {
          diagnostics.log(error: error)
        }
      }
    }

    func openPermissionDetails() {
      asyncExecutor.schedule(.reuse) {
        do {
          try await navigation
            .push(
              ResourceFolderPermissionListView.self,
              controller:
                features
                .instance(context: context)
            )
        }
        catch {
          diagnostics.log(error: error)
        }
      }
    }

    return .init(
      viewState: viewState,
      openLocationDetails: openLocationDetails,
      openPermissionDetails: openPermissionDetails
    )
  }
}

extension FeaturesRegistry {

  public mutating func usePassboltResourceFolderDetailsController() {
    self.use(
      .disposable(
        ResourceFolderDetailsController.self,
        load: ResourceFolderDetailsController.load(features:context:)
      ),
      in: SessionScope.self
    )
  }
}
