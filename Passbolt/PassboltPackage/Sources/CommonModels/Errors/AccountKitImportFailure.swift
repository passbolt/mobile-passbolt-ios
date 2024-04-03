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

public struct AccountKitImportFailure: TheError {

  /**
   * Creates a new error instance specific to the AccountKit domain.
   *
   * This static function constructs an error related to Account Kit processing
   *
   * @param {Error} [underlyingError] - An optional underlying error that may have caused this error.
   * @param {StaticString} [file] - The file where the error is being created, defaults to the current file.
   * @param {UInt} [line] - The line number in the file where the error is being created, defaults to the current  line.
   * @returns {ErrorType} An instance of the error type, configured with the provided context and underlying error.
   */
  public static func error(
    underlyingError: Error? = .none,
    file: StaticString = #fileID,
    line: UInt = #line
  ) -> Self {
    Self(
      context: .context(
        .message(
          "AccountKitImportFailure",
          file: file,
          line: line
        )
      ),
      underlyingError: underlyingError
    )
  }

  public var context: DiagnosticsContext
  public var underlyingError: Error?
}
