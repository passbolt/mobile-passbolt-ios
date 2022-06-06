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

public struct ResourceUsersIDDatabaseFetch {

  public var execute: @StorageAccessActor (Resource.ID) async throws -> Array<User.ID>

  public init(
    execute: @escaping @StorageAccessActor (Input) async throws -> Output
  ) {
    self.execute = execute
  }
}

extension ResourceUsersIDDatabaseFetch: DatabaseOperationFeature {

  public static func using(
    _ connection: @escaping () async throws -> SQLiteConnection
  ) -> Self {
    withConnection(
      using: connection
    ) { conn, input in
      var statement: SQLiteStatement =
        .statement(
          """
          SELECT DISTINCT
            id
          FROM (
            SELECT
              usersResources.userID AS id
            FROM
              usersResources
            WHERE
              usersResources.resourceID == ?1

            UNION ALL

            SELECT
              usersGroups.userID AS id
            FROM
              userGroupsResources
            INNER JOIN
              usersGroups
            ON
              usersGroups.userGroupID == userGroupsResources.userGroupID
            WHERE
              userGroupsResources.resourceID == ?1
          )
          ;
          """,
          arguments: input
        )

      return
        try conn
        .fetch(using: statement) { dataRow -> User.ID in
          guard
            let id: User.ID = dataRow.id.flatMap(User.ID.init(rawValue:))
          else {
            throw
              DatabaseIssue
              .error(
                underlyingError:
                  DatabaseDataInvalid
                  .error(for: ResourceUserGroupListItemDSV.self)
              )
          }

          return id
        }
    }
  }
}
