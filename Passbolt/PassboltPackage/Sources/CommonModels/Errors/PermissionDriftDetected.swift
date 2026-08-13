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

/// Raised when the server permission state changed between the moment the confirmation screen was rendered
/// and the moment the operator confirmed. The operation is aborted so a secret is never shared with a
/// recipient the operator did not review.
public struct PermissionDriftDetected: TheError {

  /// `drift` names the recipients behind the change when they are known; the default carries no names and
  /// yields the unattributed message - which is what a drift that cannot be attributed to a reviewed recipient
  /// (an unexpected recipient the server introduced) needs anyway.
  public static func error(
    drift: PermissionDrift = .none,
    message: StaticString = "PermissionDriftDetected",
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
      ),
      displayableMessage: drift.displayableMessage
    )
  }

  public var context: DiagnosticsContext
  public var displayableMessage: DisplayableString
}
