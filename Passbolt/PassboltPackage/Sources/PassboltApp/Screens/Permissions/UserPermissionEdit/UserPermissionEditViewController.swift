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
import FeatureScopes
import Resources
import Users

internal final class UserPermissionEditViewController: @MainActor ViewController {

  internal typealias Context = (
    resourceID: Resource.ID,
    permissionDetails: UserPermissionDetailsDSV
  )

  internal struct ViewState: Equatable {

    internal var name: DisplayableString
    internal var username: DisplayableString
    internal var fingerprint: Fingerprint
    internal var permission: Permission
    internal var alert: AlertViewModel? = .none
    internal var isSuspended: Bool
  }

  internal let viewState: ViewStateSource<ViewState>

  private let context: Context
  private let resourceShareForm: ResourceShareForm
  private let users: Users
  private let navigationToSelf: NavigationToUserPermissionEdit

  internal init(context: Context, features: Features) throws {
    self.context = context
    self.users = try features.instance()
    self.navigationToSelf = try features.instance()

    self.resourceShareForm = try features.instance()

    self.viewState = .init(
      initial: .init(
        name: .raw(
          context.permissionDetails.firstName
            + " "
            + context.permissionDetails.lastName
            + (context.permissionDetails.isSuspended
              ? " (\(DisplayableString.localized("resource.permission.details.user.suspended").string()))" : "")
        ),
        username: .raw(context.permissionDetails.username),
        fingerprint: context.permissionDetails.fingerprint,
        permission: context.permissionDetails.permission,
        isSuspended: context.permissionDetails.isSuspended
      )
    )
  }

  internal func set(permissionType: Permission) {
    viewState.update(\.permission, to: permissionType)
  }

  internal func saveChanges() async {
    await consumingErrors {
      let viewState: ViewState = await self.viewState.current
      await resourceShareForm
        .setUserPermission(
          context.permissionDetails.id,
          viewState.permission
        )
      try await navigationToSelf.revert()
    }
  }

  internal func deletePermission() {
    viewState.update(
      \.alert,
      to: .init(
        title: .localized(key: .areYouSure),
        message:
          "resource.permission.delete.user.permission.confirmation.message",
        actions: [
          .cancel(id: .init(), title: .localized(key: .cancel)),
          .destructive(
            id: .init(),
            title: .localized(key: .confirm),
            perform: { [weak self] in await self?.confirmedDeletePermission() }
          ),
        ]
      )
    )
  }

  private func confirmedDeletePermission() async {
    await consumingErrors {
      await resourceShareForm
        .deleteUserPermission(
          context.permissionDetails.id
        )
      try await navigationToSelf.revert()
    }
  }

  internal func loadAvatar() async -> Data? {
    do {
      return try await users.userAvatarImage(context.permissionDetails.id)
    }
    catch {
      error.logged()
      return nil
    }
  }
}
