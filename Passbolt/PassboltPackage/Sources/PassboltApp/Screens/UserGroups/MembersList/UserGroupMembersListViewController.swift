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
import Users

internal final class UserGroupMembersListViewController: @MainActor ViewController {

  internal typealias Context = UserGroupDetailsDSV

  internal struct ViewState: Equatable {
    internal let groupName: String
    internal let items: Array<UserGroupMembersListRowItem>
  }

  internal let viewState: ViewStateSource<ViewState>

  private let navigationToMemberDetails: NavigationToUserGroupMemberDetails

  internal init(context: UserGroupDetailsDSV, features: Features) throws {
    self.navigationToMemberDetails = try features.instance()
    let users: Users = try features.instance()

    @Sendable
    func userAvatarImageFetch(
      _ userID: User.ID
    ) async -> Data? {
      do {
        return try await users.userAvatarImage(userID)
      }
      catch {
        error.logged()
        return nil
      }
    }

    self.viewState = .init(
      initial: .init(
        groupName: context.name,
        items: context
          .members
          .map { (user: UserDetailsDSV) -> UserGroupMembersListRowItem in
            .init(
              userDetails: user,
              avatarImageData: {
                await userAvatarImageFetch(user.id)
              }
            )
          }
      )
    )
  }

  func showUserDetails(
    _ details: UserDetailsDSV
  ) async {
    await consumingErrors {
      try await self.navigationToMemberDetails.perform(context: details)
    }
  }
}
