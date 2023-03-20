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

extension ResourceFolderPathFetchDatabaseOperation {

  @Sendable fileprivate static func execute(
    _ input: ResourceFolder.ID,
    connection: SQLiteConnection
  ) throws -> OrderedSet<ResourceFolderPathItem> {
    let selectPathStatement: SQLiteStatement =
      .statement(
        """
        WITH RECURSIVE
          pathItems(
            id,
            name,
            shared,
            parentID
          )
        AS
        (
          SELECT
            resourceFolders.id AS id,
            resourceFolders.name AS name,
            resourceFolders.shared AS shared,
            resourceFolders.parentFolderID AS parentID
          FROM
            resourceFolders
          WHERE
            resourceFolders.id == ?

          UNION

          SELECT
            resourceFolders.id AS id,
            resourceFolders.name AS name,
            resourceFolders.shared AS shared,
            resourceFolders.parentFolderID AS parentID
          FROM
            resourceFolders,
            pathItems
          WHERE
            resourceFolders.id == location.parentID
        )
        SELECT
          pathItems.id,
          pathItems.shared,
          pathItems.name AS name
        FROM
          pathItems;
        """,
        arguments: input
      )

    return try connection
      .fetch(
        using: selectPathStatement
      ) { dataRow in
      guard
        let id: ResourceFolder.ID = dataRow.id.flatMap(ResourceFolder.ID.init(rawValue:)),
        let name: String = dataRow.name,
        let shared: Bool = dataRow.shared
      else {
        throw
        DatabaseIssue
          .error(
            underlyingError:
              DatabaseDataInvalid
              .error(for: ResourceFolderPathItem.self)
          )
      }

      return ResourceFolderPathItem(
        id: id,
        name: name,
        shared: shared
      )
    }
    .reversed()
    .asOrderedSet()
  }
}

extension FeaturesRegistry {

  internal mutating func usePassboltResourceFolderPathFetchDatabaseOperation() {
    self.use(
      FeatureLoader.databaseOperation(
        of: ResourceFolderPathFetchDatabaseOperation.self,
        execute: ResourceFolderPathFetchDatabaseOperation.execute(_:connection:)
      ),
      in: SessionScope.self
    )
  }
}
