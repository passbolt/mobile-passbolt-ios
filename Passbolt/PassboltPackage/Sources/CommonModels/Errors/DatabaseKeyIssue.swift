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

/// The database exists and is reachable, but the key it was opened with does not decrypt it.
///
/// Kept apart from `DatabaseConnectionIssue` on purpose: this is the only database failure that
/// says something about the *key* rather than about the file or the device, so it is the only one
/// that may be answered by retrying under a different key. Every other failure - a missing
/// directory, a full disk, a failed migration - must not be mistaken for a wrong key.
public struct DatabaseKeyIssue: TheError {

  public static func error(
    _ message: StaticString = "DatabaseKeyIssue",
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
      displayableMessage: .localized(key: "error.database.connection.issue")
    )
  }

  public var context: DiagnosticsContext
  public var displayableMessage: DisplayableString
}

extension Error {

  /// The database was reachable but the key it was opened with does not decrypt it.
  /// The one database failure that may be answered by retrying under a different key.
  public var isDatabaseKeyIssue: Bool {
    self.isOrWraps(DatabaseKeyIssue.self)
  }

  /// The database file could not be reached or read at all - a missing directory, a full disk,
  /// a device that refused the operation. Says nothing about the contents being intact, so it
  /// must never be answered by deleting them.
  public var isDatabaseConnectionIssue: Bool {
    self.isOrWraps(DatabaseConnectionIssue.self)
  }
}
