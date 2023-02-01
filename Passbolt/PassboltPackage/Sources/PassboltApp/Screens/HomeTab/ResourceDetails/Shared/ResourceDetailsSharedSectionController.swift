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
import Display
import OSFeatures
import Resources
import UIComponents
import Users

internal struct ResourceDetailsSharedSectionController {

  internal var viewState: ObservableValue<ViewState>
  internal var showResourcePermissionList: @MainActor () async -> Void
}

extension ResourceDetailsSharedSectionController: ComponentController {

  internal typealias ControlledView = ResourceDetailsSharedSectionView
  internal typealias Context = Resource.ID

  @MainActor static func instance(
    in context: Context,
    with features: inout Features,
    cancellables: Cancellables
  ) throws -> Self {
    let diagnostics: OSDiagnostics = features.instance()
    let asyncExecutor: AsyncExecutor = try features.instance()
    let navigation: DisplayNavigation = try features.instance()
    let resourceDetails: ResourceDetails = try features.instance(context: context)
    let users: Users = try features.instance()

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

    let viewState: ObservableValue<ViewState> = .init(
      initial: .init(
        items: .init()
      )
    )

    asyncExecutor.schedule { @MainActor in
      do {
        viewState.items =
          try await resourceDetails
          .details()
          .permissions
          .compactMap { permission -> OverlappingAvatarStackView.Item? in
            switch permission {
            case let .userToResource(_, userID, _, _):
              return .user(userID, avatarImage: userAvatarImageFetch(userID))

            case let .userGroupToResource(_, userGroup, _, _):
              return .userGroup(userGroup)

            case .userToFolder, .userGroupToFolder:
              // should not happen, filtering out
              return nil
            }
          }
      }
      catch {
        diagnostics.log(error: error)
      }
    }

    @MainActor func showResourcePermissionList() async {
      await navigation.push(
        legacy: ResourcePermissionListView.self,
        context: context
      )
    }

    return Self(
      viewState: viewState,
      showResourcePermissionList: showResourcePermissionList
    )
  }
}
