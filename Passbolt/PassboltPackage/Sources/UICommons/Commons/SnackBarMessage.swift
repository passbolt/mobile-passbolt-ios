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

/// Message displayable as a snackbar.
/// Use `SnackBarMessageEvent` to display it
/// on the screen.
public enum SnackBarMessage {

  /// Info message uses neutral background color
  /// and can be used to indicate system events
  /// and successful results of operations.
  case info(DisplayableString)
  /// Error message uses red background color
  /// and should be used to indicate errors, invalid
  /// states and issues within the application.
  case error(DisplayableString = .localized(key: .genericError))
}

extension SnackBarMessage: Sendable {}

extension SnackBarMessage: Equatable {}

extension SnackBarMessage {

  /// Automatically convert any error to
  /// the message that can be displayed.
  /// Message presented on screen is provided
  /// by `TheError.displayableMessage`.
  /// `CancellationError` / `Cancelled` errors
  /// are ignored and does not produce a message.
  public static func error(
    _ error: Error
  ) -> Self? {
    switch error {
    case is CancellationError, is Cancelled:
      return .none

    case let error:
      return .error(
        error
          .asTheError()
          .displayableMessage
      )
    }
  }
}

extension SnackBarMessage: ExpressibleByStringLiteral {

  public init(
    stringLiteral value: String
  ) {
    self = .info(DisplayableString(stringLiteral: value))
  }
}
