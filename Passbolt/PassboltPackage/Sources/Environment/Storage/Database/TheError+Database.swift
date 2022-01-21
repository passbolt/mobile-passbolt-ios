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

extension TheErrorLegacy {

  public static func databaseConnectionClosed(
    underlyingError: Error? = nil,
    databaseErrorMessage: String?
  ) -> Self {
    .init(
      identifier: .databaseConnectionClosed,
      underlyingError: underlyingError,
      extensions: [
        .databaseErrorMessage: databaseErrorMessage as Any
      ]
    )
  }

  public static func databaseConnectionError(
    underlyingError: Error? = nil,
    databaseErrorMessage: String?
  ) -> Self {
    .init(
      identifier: .databaseConnectionError,
      underlyingError: underlyingError,
      extensions: [
        .databaseErrorMessage: databaseErrorMessage as Any
      ]
    )
  }

  public static func databaseStatementError(
    underlyingError: Error? = nil,
    databaseErrorMessage: String?
  ) -> Self {
    .init(
      identifier: .databaseStatementError,
      underlyingError: underlyingError,
      extensions: [
        .databaseErrorMessage: databaseErrorMessage as Any
      ]
    )
  }

  public static func databaseBindingError(
    underlyingError: Error? = nil,
    databaseErrorMessage: String?
  ) -> Self {
    .init(
      identifier: .databaseBindingError,
      underlyingError: underlyingError,
      extensions: [
        .databaseErrorMessage: databaseErrorMessage as Any
      ]
    )
  }

  public static func databaseExecutionError(
    underlyingError: Error? = nil,
    databaseErrorMessage: String?
  ) -> Self {
    .init(
      identifier: .databaseExecutionError,
      underlyingError: underlyingError,
      extensions: [
        .databaseErrorMessage: databaseErrorMessage as Any
      ]
    )
  }

  public static func databaseMigrationError(
    underlyingError: Error? = nil,
    databaseErrorMessage: String?
  ) -> Self {
    .init(
      identifier: .databaseMigrationError,
      underlyingError: underlyingError,
      extensions: [
        .databaseErrorMessage: databaseErrorMessage as Any
      ]
    )
  }

  public static func databaseFetchError(
    underlyingError: Error? = nil,
    databaseErrorMessage: String?
  ) -> Self {
    .init(
      identifier: .databaseFetchError,
      underlyingError: underlyingError,
      extensions: [
        .databaseErrorMessage: databaseErrorMessage as Any
      ]
    )
  }
}

extension TheErrorLegacy.ID {

  public static let databaseConnectionClosed: Self = "databaseConnectionClosed"
  public static let databaseConnectionError: Self = "databaseConnectionError"
  public static let databaseStatementError: Self = "databaseStatementError"
  public static let databaseBindingError: Self = "databaseBindingError"
  public static let databaseExecutionError: Self = "databaseExecutionError"
  public static let databaseMigrationError: Self = "databaseMigrationError"
  public static let databaseFetchError: Self = "databaseFetchError"
}

extension TheErrorLegacy.Extension {

  public static let databaseErrorMessage: Self = "databaseErrorMessage"
}
