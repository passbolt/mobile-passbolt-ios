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

/// Raised when applying confirmed permissions failed *after* part of the change had already reached the server -
/// recipients losing access are revoked in their own request, before the secret is rotated.
///
/// The distinction matters to the flow: the resource no longer matches the snapshot the operator reviewed, but by
/// our own doing rather than through server-side drift. Whoever handles this must refresh before another attempt
/// (otherwise the drift check blames the next attempt on someone else) and surface ``underlyingError`` - the
/// failure the operator can actually act on.
public struct PermissionsPartiallyApplied: TheErrorWrapper {

  public static func error(
    _ message: StaticString = "PermissionsPartiallyApplied",
    underlyingError: Error,
    file: StaticString = #fileID,
    line: UInt = #line
  ) -> Self {
    let underlying: TheError = underlyingError.asTheError(file: file, line: line)
    return Self(
      context: .merging(
        underlying.context,
        .context(
          .message(
            message,
            file: file,
            line: line
          )
        )
      ),
      displayableMessage: underlying.displayableMessage,
      underlyingError: underlying
    )
  }

  public var context: DiagnosticsContext
  public var displayableMessage: DisplayableString
  public var underlyingError: TheError
}
