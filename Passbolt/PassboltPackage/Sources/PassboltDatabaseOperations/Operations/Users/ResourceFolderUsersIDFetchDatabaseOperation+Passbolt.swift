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

import DatabaseOperations
import Session

// MARK: - Implementation

extension ResourceFolderUsersIDFetchDatabaseOperation {

  @Sendable fileprivate static func execute(
    _ input: ResourceFolder.ID,
    connection: SQLiteConnection
  ) throws -> Array<User.ID> {
    var statement: SQLiteStatement =
      .statement(
        """
        SELECT DISTINCT
          id
        FROM (
          SELECT
            usersResourceFolders.userID AS id
          FROM
            usersResourceFolders
          WHERE
            usersResourceFolders.resourceFolderID == ?1

          UNION

          SELECT DISTINCT
            usersGroups.userID AS id
          FROM
            userGroupsResourceFolders
          INNER JOIN
            usersGroups
          ON
            usersGroups.userGroupID == userGroupsResourceFolders.userGroupID
          WHERE
            userGroupsResourceFolders.resourceFolderID == ?1
        )
        ;
        """,
        arguments: input
      )

    return
      try connection
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

extension FeatureFactory {

  internal func usePassboltResourceFolderUsersIDFetchDatabaseOperation() {
    self.use(
      FeatureLoader.databaseOperation(
        of: ResourceFolderUsersIDFetchDatabaseOperation.self,
        execute: ResourceFolderUsersIDFetchDatabaseOperation.execute(_:connection:)
      )
    )
  }
}
