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

import Commons

/// Raised when the server did not describe every recipient a ``PermissionSnapshot`` asked about, so the snapshot
/// cannot be trusted to list who a secret would be shared with.
///
/// A snapshot is only useful if it is complete: a by-ids response short of what was requested would silently
/// shrink the reviewed recipient list and, worse, could rotate a secret away from a valid holder. Capturing the
/// snapshot fails instead, leaving the operation unperformed.
///
/// Both recipient kinds are covered: an unanswered group would drop its whole membership from the snapshot, which
/// hides the group from the reviewed list *and* leaves its members out of a secret rotation.
public struct PermissionSnapshotIncomplete: TheError {

  public static func error(
    missingUsers: Array<User.ID> = .init(),
    missingGroups: Array<UserGroup.ID> = .init(),
    message: StaticString = "PermissionSnapshotIncomplete",
    file: StaticString = #fileID,
    line: UInt = #line
  ) -> Self {
    Self(
      context: .context(
        .message(
          message,
          file: file,
          line: line
        )
      )
    )
    .recording(missingUsers, for: "missingUsers")
    .recording(missingGroups, for: "missingGroups")
  }

  public var context: DiagnosticsContext
  /// Named explicitly rather than left to the generic fallback: this stops an otherwise ordinary save, so the
  /// operator has to be told that it was the recipient list - not their edit - that could not be established.
  public var displayableMessage: DisplayableString = .localized(
    key: "resource.permission.confirm.snapshot.incomplete.message"
  )
}
