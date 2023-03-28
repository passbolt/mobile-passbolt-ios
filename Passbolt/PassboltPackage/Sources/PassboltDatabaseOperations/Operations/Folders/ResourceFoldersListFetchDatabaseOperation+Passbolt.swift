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

extension ResourceFoldersListFetchDatabaseOperation {

  @Sendable fileprivate static func execute(
    _ input: ResourceFoldersDatabaseFilter,
    connection: SQLiteConnection
  ) throws -> Array<ResourceFolderListItemDSV> {
    var statement: SQLiteStatement

    // note that current filters application is not optimal,
    // it should be more performant if applied on recursive
    // select but it might be less readable
    // unless there is any performance issue it is preferred
    // to be left in this way

    if input.flattenContent {
      statement = """
        WITH RECURSIVE
          flattenedResourceFolders(
            id,
            name,
            permission,
            parentFolderID,
            shared
          ) AS (
            SELECT
              resourceFolders.id,
              resourceFolders.name,
              resourceFolders.permission,
              resourceFolders.parentFolderID,
              resourceFolders.shared
            FROM
              resourceFolders
            WHERE
              resourceFolders.parentFolderID IS ?

            UNION

            SELECT
              resourceFolders.id,
              resourceFolders.name,
              resourceFolders.permission,
              resourceFolders.parentFolderID,
              resourceFolders.shared
            FROM
              resourceFolders,
              flattenedResourceFolders
            WHERE
              resourceFolders.parentFolderID IS flattenedResourceFolders.id
          )
          SELECT DISTINCT
            flattenedResourceFolders.id AS id,
            flattenedResourceFolders.name AS name,
            flattenedResourceFolders.permission AS permission,
            flattenedResourceFolders.parentFolderID AS parentFolderID,
            flattenedResourceFolders.shared AS shared,
            (
              SELECT
                (
                  (
                    SELECT
                      COUNT(*)
                    FROM
                      resources
                    WHERE
                      resources.parentFolderID IS flattenedResourceFolders.id
                  )
                  +
                  (
                    SELECT
                      COUNT(*)
                    FROM
                      resourceFolders
                    WHERE
                      resourceFolders.parentFolderID IS flattenedResourceFolders.id
                  )
                )
            ) AS contentCount,
            (
              SELECT
                GROUP_CONCAT(name, ' > ') as pathString
              FROM
                (
                  WITH RECURSIVE
                    pathItems(
                      id,
                      name,
                      parentID,
                      depth
                    ) AS (
                      SELECT
                        resourceFolders.id AS id,
                        resourceFolders.name AS name,
                        resourceFolders.parentFolderID AS parentID,
                        1 as depth
                      FROM
                        resourceFolders
                      WHERE
                        resourceFolders.id == flattenedResourceFolders.parentFolderID

                      UNION

                      SELECT
                        resourceFolders.id AS id,
                        resourceFolders.name AS name,
                        resourceFolders.parentFolderID AS parentID,
                        pathItems.depth + 1
                      FROM
                        resourceFolders,
                        pathItems
                      WHERE
                        resourceFolders.id == pathItems.parentID
                    )
                    SELECT
                      pathItems.name
                    FROM
                      pathItems
                    ORDER BY
                      pathItems.depth DESC
              )
            ) as pathString
          FROM
            flattenedResourceFolders
          WHERE
            1 -- equivalent of true, used to simplify dynamic query building
        """
      statement.appendArgument(input.folderID)
    }
    else {
      statement = """
        SELECT
          resourceFolders.id AS id,
          resourceFolders.name AS name,
          resourceFolders.permission AS permission,
          resourceFolders.parentFolderID AS parentFolderID,
          resourceFolders.shared AS shared,
          (
            SELECT
              (
                (
                  SELECT
                    COUNT(*)
                  FROM
                    resources
                  WHERE
                    resources.parentFolderID IS resourceFolders.id
                )
                +
                (
                  SELECT
                    COUNT(*)
                  FROM
                    resourceFolders AS folders
                  WHERE
                    folders.parentFolderID IS resourceFolders.id
                )
              )
          ) AS contentCount,
          (
            SELECT
              GROUP_CONCAT(name, ' > ') as pathString
            FROM
              (
                WITH RECURSIVE
                  pathItems(
                    id,
                    name,
                    parentID,
                    depth
                  ) AS (
                    SELECT
                      resourceFolders.id AS id,
                      resourceFolders.name AS name,
                      resourceFolders.parentFolderID AS parentID,
                      1 as depth
                    FROM
                      resourceFolders
                    WHERE
                      resourceFolders.id == ?

                    UNION

                    SELECT
                      resourceFolders.id AS id,
                      resourceFolders.name AS name,
                      resourceFolders.parentFolderID AS parentID,
                      pathItems.depth + 1
                    FROM
                      resourceFolders,
                      pathItems
                    WHERE
                      resourceFolders.id == pathItems.parentID
                  )
                  SELECT
                    pathItems.name
                  FROM
                    pathItems
                  ORDER BY
                    pathItems.depth DESC
              )
          ) as pathString
        FROM
          resourceFolders
        WHERE
          resourceFolders.parentFolderID IS ?
        """
      statement.appendArgument(input.folderID)
      statement.appendArgument(input.folderID)
    }

    if !input.text.isEmpty {
      statement
        .append(
          """
          AND name LIKE '%' || ? || '%'
          """
        )
      statement.appendArgument(input.text)
    }
    else {
      /* NOP */
    }

    // since we cannot use array in query directly
    // we are preparing it manually as argument for each element
    if input.permissions.count > 1 {
      statement.append("AND permission IN (")
      for index in input.permissions.indices {
        if index == input.permissions.startIndex {
          statement.append("?")
        }
        else {
          statement.append(", ?")
        }
        statement.appendArgument(input.permissions[index])
      }
      statement.append(") ")
    }
    else if let permission: Permission = input.permissions.first {
      statement.append("AND permission == ? ")
      statement.appendArgument(permission)
    }
    else {
      /* NOP */
    }

    switch input.sorting {
    case .nameAlphabetically:
      statement.append("ORDER BY name COLLATE NOCASE ASC")
    }

    // end query
    statement.append(";")

    return try connection.fetch(using: statement) { dataRow -> ResourceFolderListItemDSV in
      guard
        let id: ResourceFolder.ID = dataRow.id.flatMap(ResourceFolder.ID.init(rawValue:)),
        let name: String = dataRow.name,
        let permission: Permission = dataRow.permission.flatMap(Permission.init(rawValue:)),
        let shared: Bool = dataRow.shared
      else {
        throw
          DatabaseIssue
          .error(
            underlyingError:
              DatabaseDataInvalid
              .error(for: ResourceFolderListItemDSV.self)
          )
          .recording(dataRow, for: "dataRow")
      }
      let pathString: String = dataRow.pathString ?? ""
      return ResourceFolderListItemDSV(
        id: id,
        name: name,
        permission: permission,
        shared: shared,
        parentFolderID: dataRow.parentFolderID.flatMap(ResourceFolder.ID.init(rawValue:)),
        location: pathString,
        contentCount: dataRow.contentCount ?? 0
      )
    }
  }
}

extension FeaturesRegistry {

  internal mutating func usePassboltResourceFoldersListFetchDatabaseOperation() {
    self.use(
      FeatureLoader.databaseOperation(
        of: ResourceFoldersListFetchDatabaseOperation.self,
        execute: ResourceFoldersListFetchDatabaseOperation.execute(_:connection:)
      ),
      in: SessionScope.self
    )
  }
}
