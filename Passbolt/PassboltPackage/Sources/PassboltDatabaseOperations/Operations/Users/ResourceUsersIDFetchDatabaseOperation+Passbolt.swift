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
import FeatureScopes
import Session

// MARK: - Implementation

extension ResourceUsersIDFetchDatabaseOperation {

  @Sendable fileprivate static func execute(
    _ input: Resource.ID,
    connection: SQLiteConnection
  ) throws -> Array<User.ID> {
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

          UNION

          SELECT DISTINCT
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
      try connection
      .fetch(using: statement) { dataRow -> User.ID in
        guard
          let id: User.ID = dataRow.id.flatMap(User.ID.init(rawValue:))
        else {
          throw
            DatabaseDataInvalid
            .error(for: User.ID.self)
            .recording(dataRow, for: "dataRow")
        }

        return id
      }
  }
}

extension FeaturesRegistry {

  internal mutating func usePassboltResourceUsersIDFetchDatabaseOperation() {
    self.use(
      FeatureLoader.databaseOperation(
        of: ResourceUsersIDFetchDatabaseOperation.self,
        execute: ResourceUsersIDFetchDatabaseOperation.execute(_:connection:)
      ),
      in: SessionScope.self
    )
  }
}
