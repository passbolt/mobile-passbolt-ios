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

#warning("TODO: [PAS-82] Prepare database with environment")
internal struct DatabaseConnection {

  internal var accountID: () -> Account.LocalID
  internal var execute:
    (
      _ statement: DatabaseStatement,
      _ bindings: Array<DatabaseStatementBindable?>
    ) -> AnyPublisher<Void, TheError>
  internal var loadRows:
    (
      _ query: DatabaseStatement,
      _ bindings: Array<DatabaseStatementBindable?>
    ) -> AnyPublisher<Array<DatabaseRow>, TheError>
  internal var close: () -> Void
}

#warning("FIXME: PAS-82 - this should only be available in DEBUG")
extension DatabaseConnection {

  internal static var placeholder: Self {
    Self(
      accountID: Commons.placeholder("You have to provide mocks for used methods"),
      execute: Commons.placeholder("You have to provide mocks for used methods"),
      loadRows: Commons.placeholder("You have to provide mocks for used methods"),
      close: Commons.placeholder("You have to provide mocks for used methods")
    )
  }
}
