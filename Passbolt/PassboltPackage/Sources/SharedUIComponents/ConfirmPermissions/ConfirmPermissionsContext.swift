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

/// Result of the presenting flow handling a confirmation, driving what the screen does next.
public enum ConfirmPermissionsOutcome: Sendable {

  /// The operation completed; the flow has navigated away and the screen should do nothing.
  case applied
  /// Drift was detected. The screen reopens with the refreshed snapshot and shows a drift message so the operator
  /// can review the updated recipients and try saving again.
  case retryWithRefreshed(PermissionSnapshot)
  /// The operation failed and the error was already surfaced; the screen stays as-is for another attempt.
  case failed
}

/// Context handed to the permission confirmation screen. Defined here (rather than in the screen's module) so the
/// shared resource-edit form - which triggers the create flow - can build it and navigate to the screen.
public struct ConfirmPermissionsContext: Sendable {

  public var mode: ConfirmPermissionsMode
  public var snapshot: PermissionSnapshot
  /// The operator performing the action. Their own permission row can never be edited or removed (they must
  /// remain an owner), matching the specification.
  public var operatorID: User.ID
  /// Invoked with the confirmed recipient set and the snapshot currently shown (which changes after a refresh).
  /// The presenting flow performs the encryption/share and navigation and reports the outcome.
  public var onConfirm:
    @Sendable (OrderedSet<ResourcePermission>, PermissionSnapshot) async -> ConfirmPermissionsOutcome
  /// Invoked when the operator backs out. The presenting flow returns to the originating form with nothing lost.
  public var onCancel: @Sendable () async -> Void

  public init(
    mode: ConfirmPermissionsMode,
    snapshot: PermissionSnapshot,
    operatorID: User.ID,
    onConfirm:
      @escaping @Sendable (OrderedSet<ResourcePermission>, PermissionSnapshot) async -> ConfirmPermissionsOutcome,
    onCancel: @escaping @Sendable () async -> Void
  ) {
    self.mode = mode
    self.snapshot = snapshot
    self.operatorID = operatorID
    self.onConfirm = onConfirm
    self.onCancel = onCancel
  }
}
