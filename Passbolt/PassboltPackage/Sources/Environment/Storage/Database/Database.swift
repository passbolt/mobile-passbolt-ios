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

import CommonModels
import SQLCipher

public struct Database: EnvironmentElement {

  public var openConnection:
    (
      _ path: String,
      _ key: String,
      _ migrations: Array<SQLiteMigration>
    ) -> Result<SQLiteConnection, TheErrorLegacy>
}

extension Database {

  public static func sqlite() -> Self {
    Self(
      openConnection: { path, key, migrations in
        SQLiteConnection.open(
          at: path,
          key: key,
          options: SQLITE_OPEN_CREATE
            | SQLITE_OPEN_READWRITE
            | SQLITE_OPEN_WAL
            | SQLITE_OPEN_PRIVATECACHE,
          migrations: migrations
        )
      }
    )
  }
}

extension Environment {

  public var database: Database {
    get { element(Database.self) }
    set { use(newValue) }
  }
}

#if DEBUG
extension Database {
  public static var placeholder: Self {
    Self(
      openConnection: unimplemented("You have to provide mocks for used methods")
    )
  }
}

#endif
