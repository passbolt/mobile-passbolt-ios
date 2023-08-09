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
import UIComponents
import Users

internal struct UserGroupPermissionDetailsController {

  internal var viewState: ObservableValue<ViewState>
  internal var showGroupMembers: () async -> Void
  internal var navigateBack: () -> Void
}

extension UserGroupPermissionDetailsController: ComponentController {

  internal typealias ControlledView = UserGroupPermissionDetailsView
  internal typealias Context = UserGroupPermissionDetailsDSV

  @MainActor static func instance(
    in context: Context,
    with features: inout Features,
    cancellables: Cancellables
  ) throws -> Self {

    let navigation: DisplayNavigation = try features.instance()
    let users: Users = try features.instance()

    func userAvatarImageFetch(
      _ userID: User.ID
    ) -> () async -> Data? {
      {
        do {
          return try await users.userAvatarImage(userID)
        }
        catch {
          error.logged()
          return nil
        }
      }
    }

    let viewState: ObservableValue<ViewState> = .init(
      initial: .init(
        permissionDetails: context,
        groupMembersPreviewItems: context
          .members
          .map { user in
            .user(
              user.id,
              avatarImage: userAvatarImageFetch(user.id)
            )
          }
      )
    )

    func showGroupMembers() async {
      await navigation
        .push(
          legacy: UserGroupMembersListView.self,
          context: context.asUserGroupDetails
        )
    }

    nonisolated func navigateBack() {
      Task {
        await navigation.pop(if: UserGroupPermissionDetailsView.self)
      }
    }

    return Self(
      viewState: viewState,
      showGroupMembers: showGroupMembers,
      navigateBack: navigateBack
    )
  }
}
