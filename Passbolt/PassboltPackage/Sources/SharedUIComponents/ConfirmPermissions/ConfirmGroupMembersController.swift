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

import CommonModels
import Display
import FeatureScopes
import Users

/// The members of a group referenced by the permission confirmation screen, listed as read-only user rows. Reached
/// by tapping the member avatars on the group details screen. Membership is taken from the confirmed snapshot, so
/// it reflects exactly the users the secret is (indirectly) shared with - not the current local database.
internal final class ConfirmGroupMembersController: @MainActor ViewController {

  internal struct Context: Sendable {

    internal var groupName: String
    internal var members: OrderedSet<UserDetailsDSV>
  }

  internal struct ViewState: Equatable, Sendable {

    internal var groupName: String
    internal var members: Array<UserDetailsDSV>
  }

  internal let viewState: ViewStateSource<ViewState>

  private let users: Users

  internal init(
    context: Context,
    features: Features
  ) throws {
    self.users = try features.instance()
    self.viewState = .init(
      initial: .init(
        groupName: context.groupName,
        members: .init(context.members)
      )
    )
  }

  internal func avatar(
    for userID: User.ID
  ) -> @Sendable () async -> Data? {
    self.users.loadAvatar(for: userID)
  }
}
