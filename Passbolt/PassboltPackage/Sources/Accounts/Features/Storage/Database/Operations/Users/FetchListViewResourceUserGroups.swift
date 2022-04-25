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
import Environment

public typealias FetchListViewResourcesUserGroupOperation = DatabaseOperation<String, Array<ListViewResourcesUserGroup>>

extension FetchListViewResourcesUserGroupOperation {

  internal static func using(
    _ connection: @escaping () async throws -> SQLiteConnection
  ) -> Self {
    withConnection(
      using: connection
    ) { conn, input in
      var statement: SQLiteStatement = """
        SELECT
          id,
          name,
          (
            SELECT
              count(*)
            FROM
              resourcesUserGroups
            WHERE
              userGroupID IS id
          ) AS resourcesCount
        FROM
          userGroups
        WHERE
          1 -- equivalent of true, used to simplify dynamic query building
        """

      var params: Array<SQLiteBindable?> = .init()

      if !input.isEmpty {
        statement
          .append(
            """
            AND
              name LIKE '%' || ? || '%'
            """
          )
        params.append(input)
      }
      else {
        /* NOP */
      }

      statement.append("ORDER BY name COLLATE NOCASE ASC;")

      return
        try conn
        .fetch(
          statement,
          with: params
        ) { rows -> Array<ListViewResourcesUserGroup> in
          try rows
            .map { row -> ListViewResourcesUserGroup in
              guard
                let id: ListViewResourcesUserGroup.ID = row.id.map(ListViewResourcesUserGroup.ID.init(rawValue:)),
                let name: String = row.name,
                let resourcesCount: Int = row.resourcesCount
              else {
                throw
                  DatabaseIssue
                  .error(
                    underlyingError:
                      DatabaseResultInvalid
                      .error("Retrived invalid data from the database")
                  )
              }

              return ListViewResourcesUserGroup(
                id: id,
                name: name,
                resourcesCount: resourcesCount
              )
            }
        }
    }
  }
}
