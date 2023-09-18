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

internal struct UserGroupMembersListController {

  internal var viewState: ObservableValue<ViewState>
  internal var showUserDetails: @MainActor (UserDetailsDSV) -> Void
}

extension UserGroupMembersListController: ComponentController {

  internal typealias ControlledView = UserGroupMembersListView
  internal typealias Context = UserGroupDetailsDSV

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
        groupName: context.name,
        items: context
          .members
          .map { (user: UserDetailsDSV) -> UserGroupMembersListRowItem in
            .init(
              userDetails: user,
              avatarImageData: userAvatarImageFetch(user.id)
            )
          }
      )
    )

    @MainActor func showUserDetails(
      _ details: UserDetailsDSV
    ) {
      cancellables.executeOnMainActor {
        await navigation
          .push(
            legacy: UserGroupMemberDetailsView.self,
            context: details
          )
      }
    }

    return Self(
      viewState: viewState,
      showUserDetails: showUserDetails(_:)
    )
  }
}
