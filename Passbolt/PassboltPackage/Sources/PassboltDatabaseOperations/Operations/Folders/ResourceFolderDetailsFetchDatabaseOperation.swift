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

extension ResourceFolderDetailsFetchDatabaseOperation {

  @Sendable fileprivate static func execute(
    _ input: (folderID: ResourceFolder.ID, userID: User.ID),
    connection: SQLiteConnection
  ) throws -> ResourceFolder {
    let userID: User.ID = input.userID
    let selectFolderStatement: SQLiteStatement =
      .statement(
        """
        SELECT
          resourceFolders.id AS id,
          resourceFolders.name AS name,
          resourceFolders.permission AS permission,
          (
            EXISTS (
              SELECT 1 FROM usersResourceFolders
              WHERE usersResourceFolders.resourceFolderID = resourceFolders.id
                AND usersResourceFolders.userID != ?
            )
            OR EXISTS (
              SELECT 1 FROM userGroupsResourceFolders
              INNER JOIN usersGroups
                ON usersGroups.userGroupID = userGroupsResourceFolders.userGroupID
              WHERE userGroupsResourceFolders.resourceFolderID = resourceFolders.id
              GROUP BY userGroupsResourceFolders.userGroupID
              HAVING COUNT(usersGroups.userID) > 1
            )
          ) AS shared,
          resourceFolders.parentFolderID AS parentFolderID
        FROM
          resourceFolders
        WHERE
          resourceFolders.id == ?;
        """,
        arguments: userID,
        input.folderID
      )

    let selectResourceFolderPathStatement: SQLiteStatement =
      .statement(
        """
        WITH RECURSIVE
          pathItems(
            id,
            name,
            parentID
          )
        AS
        (
          SELECT
            resourceFolders.id AS id,
            resourceFolders.name AS name,
            resourceFolders.parentFolderID AS parentID
          FROM
            resourceFolders
          WHERE
            resourceFolders.id == ?

          UNION

          SELECT
            resourceFolders.id AS id,
            resourceFolders.name AS name,
            resourceFolders.parentFolderID AS parentID
          FROM
            resourceFolders,
            pathItems
          WHERE
            resourceFolders.id == pathItems.parentID
        )
        SELECT
          pathItems.id,
          (
            EXISTS (
              SELECT 1 FROM usersResourceFolders
              WHERE usersResourceFolders.resourceFolderID = pathItems.id
                AND usersResourceFolders.userID != ?
            )
            OR EXISTS (
              SELECT 1 FROM userGroupsResourceFolders
              INNER JOIN usersGroups
                ON usersGroups.userGroupID = userGroupsResourceFolders.userGroupID
              WHERE userGroupsResourceFolders.resourceFolderID = pathItems.id
              GROUP BY userGroupsResourceFolders.userGroupID
              HAVING COUNT(usersGroups.userID) > 1
            )
          ) AS shared,
          pathItems.name AS name
        FROM
          pathItems;
        """
      )

    let selectFolderUsersPermissionsStatement: SQLiteStatement =
      .statement(
        """
        SELECT
          usersResourceFolders.userID AS userID,
          usersResourceFolders.resourceFolderID AS folderID,
          usersResourceFolders.permission AS permission,
          usersResourceFolders.permissionID AS permissionID
        FROM
          usersResourceFolders
        WHERE
          usersResourceFolders.resourceFolderID == ?;
        """,
        arguments: input.folderID
      )

    let selectFolderUserGroupsPermissionsStatement: SQLiteStatement =
      .statement(
        """
        SELECT
          userGroupsResourceFolders.userGroupID AS userGroupID,
          userGroupsResourceFolders.resourceFolderID AS folderID,
          userGroupsResourceFolders.permission AS permission,
          userGroupsResourceFolders.permissionID AS permissionID
        FROM
          userGroupsResourceFolders
        WHERE
          userGroupsResourceFolders.resourceFolderID == ?;
        """,
        arguments: input.folderID
      )

    return
      try connection
      .fetchFirst(using: selectFolderStatement) { dataRow in
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
                .error(for: ResourceFolder.self)
            )
            .recording(dataRow, for: "dataRow")
        }

        let usersPermissions: Array<ResourceFolderPermission> = try connection.fetch(
          using: selectFolderUsersPermissionsStatement
        ) {
          dataRow in
          guard
            let userID: User.ID = dataRow.userID.flatMap(User.ID.init(rawValue:)),
            let permission: Permission = dataRow.permission.flatMap(Permission.init(rawValue:)),
            let permissionID: Permission.ID = dataRow.permissionID.flatMap(Permission.ID.init(rawValue:))
          else {
            throw
              DatabaseIssue
              .error(
                underlyingError:
                  DatabaseDataInvalid
                  .error(for: Permission.self)
              )
          }

          return .user(
            id: userID,
            permission: permission,
            permissionID: permissionID
          )
        }

        let userGroupsPermissions: Array<ResourceFolderPermission> = try connection.fetch(
          using: selectFolderUserGroupsPermissionsStatement
        ) { dataRow in
          guard
            let userGroupID: UserGroup.ID = dataRow.userGroupID.flatMap(UserGroup.ID.init(rawValue:)),
            let permission: Permission = dataRow.permission.flatMap(Permission.init(rawValue:)),
            let permissionID: Permission.ID = dataRow.permissionID.flatMap(Permission.ID.init(rawValue:))
          else {
            throw
              DatabaseIssue
              .error(
                underlyingError:
                  DatabaseDataInvalid
                  .error(for: Permission.self)
              )
          }

          return .userGroup(
            id: userGroupID,
            permission: permission,
            permissionID: permissionID
          )
        }

        let parentFolderID: ResourceFolder.ID? = dataRow.parentFolderID.flatMap(ResourceFolder.ID.init(rawValue:))

        let path: Array<ResourceFolderPathItem>
        if let parentFolderID: ResourceFolder.ID = parentFolderID {
          path =
            try connection.fetch(
              using:
                selectResourceFolderPathStatement
                .appendingArgument(parentFolderID)
                .appendingArgument(userID)
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
        }
        else {
          path = .init()
        }

        return ResourceFolder(
          id: id,
          name: name,
          path: path.asOrderedSet(),
          permission: permission,
          permissions: OrderedSet(usersPermissions + userGroupsPermissions),
          shared: shared
        )
      }
  }
}

extension FeaturesRegistry {

  internal mutating func usePassboltResourceFolderDetailsFetchDatabaseOperation() {
    self.use(
      FeatureLoader.databaseOperation(
        of: ResourceFolderDetailsFetchDatabaseOperation.self,
        execute: ResourceFolderDetailsFetchDatabaseOperation.execute(_:connection:)
      ),
      in: SessionScope.self
    )
  }
}
