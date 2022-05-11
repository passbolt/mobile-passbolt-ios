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
import NetworkClient
import UIComponents
import Users

internal struct ResourceDetailsSharedSectionController {

  internal var viewState: ObservableValue<ViewState>
  internal var showResourcePermissionList: @MainActor () async -> Void
}

extension ResourceDetailsSharedSectionController: ComponentController {

  internal typealias ControlledView = ResourceDetailsSharedSectionView
  internal typealias NavigationContext = (
    resourceID: Resource.ID,
    permissions: Array<PermissionDSV>
  )

  @MainActor static func instance(
    context: NavigationContext,
    navigation: ComponentNavigation<NavigationContext>,
    with features: FeatureFactory,
    cancellables: Cancellables
  ) async throws -> Self {
    let diagnostics: Diagnostics = try await features.instance()
    let users: Users = try await features.instance()

    func userAvatarImageFetch(
      _ userID: User.ID
    ) -> () async -> Data? {
      {
        do {
          return try await users.userAvatarImage(userID)
        }
        catch {
          diagnostics.log(error)
          return nil
        }
      }
    }

    let viewState: ObservableValue<ViewState> = .init(
      initial: .init(
        items: context.permissions
          .compactMap { permission -> OverlappingAvatarStackView.Item? in
            switch permission {
            case let .userToResource(userID, _, _):
              return .user(userID, avatarImage: userAvatarImageFetch(userID))

            case let .userGroupToResource(userGroup, _, _):
              return .userGroup(userGroup)

            case .userToFolder, .userGroupToFolder:
              // should not happen, filtering out
              return nil
            }
          }
      )
    )

    @MainActor func showResourcePermissionList() async {
      await navigation.push(
        ResourcePermissionListView.self,
        in: context.resourceID
      )
    }

    return Self(
      viewState: viewState,
      showResourcePermissionList: showResourcePermissionList
    )
  }
}
