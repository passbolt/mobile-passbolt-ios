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

import Localization

public struct Unidentified: TheError {

  public static func error(
    _ message: StaticString = "Unidentified",
    underlyingError: Error,
    file: StaticString = #fileID,
    line: UInt = #line
  ) -> Self {
    Self(
      context: (underlyingError as? Unidentified)?.context
        ?? (underlyingError as? TheError)
        .map {
          DiagnosticsContext
            .merging(
              $0.context,
              .context(
                .message(
                  message,
                  file: file,
                  line: line
                )
              )
            )
        }
        ?? .context(
          .message(
            message,
            file: file,
            line: line
          )
        ),
      underlyingError: underlyingError,
      displayableMessage: .raw(underlyingError.localizedDescription)
    )
  }

  public var context: DiagnosticsContext
  public var underlyingError: Error
  public var displayableMessage: DisplayableString
}

extension Error {

  /// Convert any error to ``Unidentified`` error.
  public func asUnidentified(
    message: StaticString = "Unidentified",
    file: StaticString = #fileID,
    line: UInt = #line
  ) -> Unidentified {
    .error(
      message,
      underlyingError: self,
      file: file,
      line: line
    )
  }
}
