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

/// Details of a single user recipient shown from the permission confirmation screen: avatar, name, username,
/// fingerprint and - when the row is editable - a radio picker for the permission level. Selecting a level reports
/// it back to the confirmation screen via ``Context/setPermission`` so the edited recipient set stays in sync.
internal final class ConfirmUserPermissionDetailsController: @MainActor ViewController {

  internal struct Context: Sendable {

    internal var details: UserPermissionDetailsDSV
    /// Whether the permission level may be changed here (false for read-only flows and the operator's own row).
    internal var editable: Bool
    /// Reports a newly-picked permission level back to the confirmation screen.
    internal var setPermission: @Sendable (Permission) async -> Void
  }

  internal struct ViewState: Equatable, Sendable {

    internal var details: UserPermissionDetailsDSV
    internal var selectedPermission: Permission
    internal var editable: Bool
  }

  internal let viewState: ViewStateSource<ViewState>

  private let context: Context
  private let users: Users

  internal init(
    context: Context,
    features: Features
  ) throws {
    self.context = context
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

  internal func setPermission(
    _ permission: Permission
  ) async {
    self.viewState.update(\.selectedPermission, to: permission)
    await self.context.setPermission(permission)
  }
}
