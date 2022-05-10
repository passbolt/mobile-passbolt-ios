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

public typealias FetchResourceListItemDSVsUserGroupOperation = DatabaseOperation<
  UserGroupsFilter, Array<ResourceUserGroupListItemDSV>
>

extension FetchResourceListItemDSVsUserGroupOperation {

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
              userGroupsResources
            WHERE
              userGroupsResources.userGroupID == userGroups.id
          ) AS contentCount
        FROM
          userGroups
        WHERE
          1 -- equivalent of true, used to simplify dynamic query building
        """

      if !input.text.isEmpty {
        statement
          .append(
            """
            AND
              userGroups.name LIKE '%' || ? || '%'
            """
          )
        statement.appendArgument(input.text)
      }
      else {
        /* NOP */
      }

      if let userID: User.ID = input.userID {
        statement
          .append(
            """
            AND
              (
                SELECT
                  1
                FROM
                  usersGroups
                WHERE
                  usersGroups.userID == ?
                AND
                  usersGroups.userGroupID == userGroups.id
                LIMIT 1
              )
            """
          )
        statement.appendArgument(userID)
      }
      else {
        /* NOP */
      }

      statement.append("ORDER BY name COLLATE NOCASE ASC;")

      return
        try conn
        .fetch(using: statement) { dataRow -> ResourceUserGroupListItemDSV in
          guard
            let id: UserGroup.ID = dataRow.id.map(UserGroup.ID.init(rawValue:)),
            let name: String = dataRow.name,
            let contentCount: Int = dataRow.contentCount
          else {
            throw
              DatabaseIssue
              .error(
                underlyingError:
                  DatabaseDataInvalid
                  .error(for: ResourceUserGroupListItemDSV.self)
              )
          }

          return ResourceUserGroupListItemDSV(
            id: id,
            name: name,
            contentCount: contentCount
          )
        }
    }
  }
}
