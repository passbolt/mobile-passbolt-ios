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

internal final class ConfirmUserPermissionDetailsController: @MainActor ViewController {

  internal struct Context: Sendable {

    internal var details: UserPermissionDetailsDSV
    /// False only for a read-only list; the operator's own row is not treated differently.
    internal var editable: Bool
    /// Reports the applied permission level back to the confirmation screen.
    internal var setPermission: @Sendable (Permission) async -> Void
    /// Drops the recipient from the confirmation screen's list.
    internal var remove: @Sendable () async -> Void
  }

  internal struct ViewState: Equatable, Sendable {

    internal var details: UserPermissionDetailsDSV
    internal var selectedPermission: Permission
    internal var editable: Bool
  }

  internal let viewState: ViewStateSource<ViewState>

  private let context: Context
  private let navigationToSelf: NavigationToConfirmUserPermissionDetails
  private let users: Users

  internal init(
    context: Context,
    features: Features
  ) throws {
    self.context = context
    self.navigationToSelf = try features.instance()
    self.users = try features.instance()
    self.viewState = .init(
      initial: .init(
        details: context.details,
        selectedPermission: context.details.permission,
        editable: context.editable
      )
    )
  }

  internal func loadAvatar() -> @Sendable () async -> Data? {
    self.users.loadAvatar(for: self.context.details.id)
  }

  /// Picks a level in the list. Local only - the confirmation screen hears nothing until ``apply()``.
  internal func selectPermission(
    _ permission: Permission
  ) {
    self.viewState.update(\.selectedPermission, to: permission)
  }

  /// Commits the picked level and returns to the recipient list.
  internal func apply() async {
    let selected: Permission = await self.viewState.current.selectedPermission
    await self.context.setPermission(selected)
    await self.leave()
  }

  /// Drops the recipient and returns to the recipient list.
  internal func remove() async {
    await self.context.remove()
    await self.leave()
  }

  private func leave() async {
    await consumingErrors {
      try await self.navigationToSelf.revert()
    }
  }
}
