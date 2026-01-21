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

internal final class UserGroupPermissionEditViewController: @MainActor ViewController {

  internal typealias Context = (
    resourceID: Resource.ID,
    permissionDetails: UserGroupPermissionDetailsDSV
  )

  internal struct ViewState: Equatable {

    internal var name: DisplayableString
    internal var permission: Permission
    internal var groupMembersPreviewItems: Array<OverlappingAvatarStackView.Item>
    internal var alert: AlertViewModel? = .none
  }

  internal let viewState: ViewStateSource<ViewState>

  private let context: Context
  private let navigationToGroupMembers: NavigationToUserGroupMembersList
  private let resourceShareForm: ResourceShareForm
  private let navigationToSelf: NavigationToUserGroupPermissionEdit

  internal init(context: Context, features: Features) throws {
    self.context = context
    self.navigationToGroupMembers = try features.instance()
    self.resourceShareForm = try features.instance()
    self.navigationToSelf = try features.instance()

    let users: Users = try features.instance()

    func loadAvatar(for userID: User.ID) -> () async -> Data? {
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

    self.viewState = .init(
      initial:
        .init(
          name: .raw(context.permissionDetails.name),
          permission: context.permissionDetails.permission,
          groupMembersPreviewItems: context
            .permissionDetails
            .members
            .map { user in
              .user(
                user.id,
                avatarImage: loadAvatar(for: user.id),
                isSuspended: user.isSuspended
              )
            }
        )
    )
  }

  internal func showGroupMembers() async {
    await consumingErrors {
      try await navigationToGroupMembers.perform(
        context: context.permissionDetails.asUserGroupDetails
      )
    }
  }

  internal func setPermissionType(_ type: Permission) {
    viewState.update(\.permission, to: type)
  }

  internal func saveChanges() async {
    let permission: Permission = await viewState.current.permission
    await resourceShareForm
      .setUserGroupPermission(
        context.permissionDetails.id,
        permission
      )

    await consumingErrors {
      try await navigationToSelf.revert()
    }
  }

  internal func deletePermission() async {

  }

  internal func deletePermission() {
    viewState.update(
      \.alert,
      to: .init(
        title: .localized(key: .areYouSure),
        message: "resource.permission.delete.user.group.permission.confirmation.message",
        actions: [
          .cancel(
            id: .init(),
            title: .localized(key: .cancel)
          ),
          .destructive(
            id: .init(),
            title: .localized(key: .confirm),
            perform: confirmedDeletePermission
          ),
        ]
      )
    )
  }

  internal func confirmedDeletePermission() async {
    await resourceShareForm
      .deleteUserGroupPermission(
        context.permissionDetails.id
      )
    await consumingErrors {
      try await navigationToSelf.revert()
    }
  }
}
