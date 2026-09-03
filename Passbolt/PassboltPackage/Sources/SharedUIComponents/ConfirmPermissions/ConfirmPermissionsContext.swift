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
  /// Drift detected - reopen on the refreshed snapshot. `restoring` carries the operator's added grants, which
  /// hold no permission yet and so are absent from a fresh capture.
  case retryWithRefreshed(PermissionSnapshot, restoring: OrderedSet<ResourcePermission>)
  /// The operation failed and the error was already surfaced; the screen stays as-is for another attempt.
  case failed
}

public struct ConfirmPermissionsContext: Sendable {

  public var mode: ConfirmPermissionsMode
  /// Server truth the encryption is bound to and drift is measured against. Never carries pending edits.
  public var snapshot: PermissionSnapshot
  /// The operator performing the action, measured against by ``ConfirmPermissionsMode/ownershipRule``.
  public var operatorID: User.ID
  /// Applies the confirmed set against the snapshot currently shown, which changes after a refresh.
  public var onConfirm:
    @Sendable (OrderedSet<ResourcePermission>, PermissionSnapshot) async -> ConfirmPermissionsOutcome
  /// Invoked when the operator backs out; the flow returns to the originating form with nothing lost.
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
