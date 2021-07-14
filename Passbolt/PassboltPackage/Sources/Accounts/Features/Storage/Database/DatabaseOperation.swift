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

import Combine
import Commons
import Environment

public struct DatabaseOperation<Input, Output> {

  public var execute: (Input) -> AnyPublisher<Output, TheError>
}

extension DatabaseOperation {

  public func callAsFunction(
    _ input: Input
  ) -> AnyPublisher<Output, TheError> {
    execute(input)
  }
}

extension DatabaseOperation where Input == Void {

  public func callAsFunction() -> AnyPublisher<Output, TheError> {
    execute(Void())
  }
}

extension DatabaseOperation {

  internal static func withConnection(
    using connectionPublisher: AnyPublisher<SQLiteConnection, TheError>,
    execute operation: @escaping (SQLiteConnection, Input) -> Result<Output, TheError>
  ) -> Self {
    Self { input -> AnyPublisher<Output, TheError> in
      connectionPublisher
        .first()
        .map { conn -> AnyPublisher<Output, TheError> in
          conn
            .withQueue { conn -> Result<Output, TheError> in
              operation(conn, input)
            }
        }
        .switchToLatest()
        .eraseToAnyPublisher()
    }
  }
}

#if DEBUG
extension DatabaseOperation {

  internal static var placeholder: Self {
    Self(
      execute: Commons.placeholder("You have to provide mocks for used methods")
    )
  }
}
#endif
