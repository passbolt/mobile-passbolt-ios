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
import CommonModels
import Environment

import struct Foundation.Date
import struct Foundation.TimeInterval

public typealias FetchLastUpdateOperation = DatabaseOperation<Void, Date>

extension FetchLastUpdateOperation {

  static func using(
    _ connection: @escaping () async throws -> SQLiteConnection
  ) -> Self {
    withConnection(
      using: connection
    ) { conn, input in
      try conn
        .fetch(
          """
          SELECT
            lastUpdateTimestamp
          FROM
            updates
          LIMIT
            1;
          """,
          mapping: { rows -> Date in
            rows
              .first
              .map { row -> Date in
                let timeInterval: TimeInterval = .init(row.lastUpdateTimestamp as Int? ?? 0)
                return Date(timeIntervalSince1970: timeInterval)
              }
              ?? Date(timeIntervalSince1970: 0)
          }
        )
    }
  }
}

public typealias SaveLastUpdateOperation = DatabaseOperation<Date, Void>

extension SaveLastUpdateOperation {

  static func using(
    _ connection: @escaping () async throws -> SQLiteConnection
  ) -> Self {
    withConnectionInTransaction(
      using: connection
    ) { conn, input in
      try conn
        .execute(
          """
          UPDATE OR FAIL
            updates
          SET
            lastUpdateTimestamp = ?1;
          """,
          with: Int(input.timeIntervalSince1970)
        )
    }
  }
}
