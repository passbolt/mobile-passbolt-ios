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

import Environment

public typealias FetchFolderOperation = DatabaseOperation<ResourceFolder.ID, ResourceFolderDetailsDSV?>

extension FetchFolderOperation {

  internal static func using(
    _ connection: @escaping () async throws -> SQLiteConnection
  ) -> Self {
    withConnection(
      using: connection
    ) { conn, input in
      let selectFolderStatement: SQLiteStatement =
        .statement(
          """
          SELECT
            resourceFolders.id AS id,
            resourceFolders.name AS name,
            resourceFolders.permissionType AS permissionType,
            resourceFolders.shared AS shared,
            resourceFolders.parentFolderID AS parentFolderID
          FROM
            resourceFolders
          WHERE
            resourceFolders.id == ?;
          """,
          arguments: input
        )

      let selectFolderUsersPermissionsStatement: SQLiteStatement =
        .statement(
          """
          SELECT
            usersResourceFolders.userID AS userID,
            usersResourceFolders.resourceFolderID AS folderID,
            usersResourceFolders.permissionType AS permissionType,
            usersResourceFolders.permissionID AS permissionID
          FROM
            usersResourceFolders
          WHERE
            usersResourceFolders.resourceFolderID == ?;
          """,
          arguments: input
        )

      let selectFolderUserGroupsPermissionsStatement: SQLiteStatement =
        .statement(
          """
          SELECT
            userGroupsResourceFolders.userGroupID AS userID,
            userGroupsResourceFolders.resourceFolderID AS folderID,
            userGroupsResourceFolders.permissionType AS permissionType,
            userGroupsResourceFolders.permissionID AS permissionID
          FROM
            userGroupsResourceFolders
          WHERE
            userGroupsResourceFolders.resourceFolderID == ?;
          """,
          arguments: input
        )

      return
        try conn
        .fetchFirst(using: selectFolderStatement) { dataRow in
          guard
            let id: ResourceFolder.ID = dataRow.id.flatMap(ResourceFolder.ID.init(rawValue:)),
            let name: String = dataRow.name,
            let shared: Bool = dataRow.shared,
            let permissionType: PermissionTypeDSV = dataRow.permissioType.flatMap(PermissionTypeDSV.init(rawValue:))
          else {
            throw
              DatabaseIssue
              .error(
                underlyingError:
                  DatabaseDataInvalid
                  .error(for: ResourceFolderDetailsDSV.self)
              )
          }

          let usersPermissions: Array<PermissionDSV> = try conn.fetch(using: selectFolderUsersPermissionsStatement) {
            dataRow in
            guard
              let userID: User.ID = dataRow.userID.flatMap(User.ID.init(rawValue:)),
              let folderID: ResourceFolder.ID = dataRow.folderID.flatMap(ResourceFolder.ID.init(rawValue:)),
              let permissionType: PermissionTypeDSV = dataRow.permissionType.flatMap(PermissionTypeDSV.init(rawValue:)),
              let permissionID: Permission.ID = dataRow.permissionID.flatMap(Permission.ID.init(rawValue:))
            else {
              throw
                DatabaseIssue
                .error(
                  underlyingError:
                    DatabaseDataInvalid
                    .error(for: PermissionTypeDSV.self)
                )
            }

            return .userToFolder(
              id: permissionID,
              userID: userID,
              folderID: folderID,
              type: permissionType
            )
          }

          let userGroupsPermissions: Array<PermissionDSV> = try conn.fetch(
            using: selectFolderUserGroupsPermissionsStatement
          ) { dataRow in
            guard
              let userGroupID: UserGroup.ID = dataRow.userGroupID.flatMap(UserGroup.ID.init(rawValue:)),
              let folderID: ResourceFolder.ID = dataRow.folderID.flatMap(ResourceFolder.ID.init(rawValue:)),
              let permissionType: PermissionTypeDSV = dataRow.permissioType.flatMap(PermissionTypeDSV.init(rawValue:)),
              let permissionID: Permission.ID = dataRow.permissionID.flatMap(Permission.ID.init(rawValue:))
            else {
              throw
                DatabaseIssue
                .error(
                  underlyingError:
                    DatabaseDataInvalid
                    .error(for: PermissionDSV.self)
                )
            }

            return .userGroupToFolder(
              id: permissionID,
              userGroupID: userGroupID,
              folderID: folderID,
              type: permissionType
            )
          }

          return ResourceFolderDetailsDSV(
            id: id,
            name: name,
            permissionType: permissionType,
            shared: shared,
            parentFolderID: dataRow.parentFolderID.flatMap(ResourceFolder.ID.init(rawValue:)),
            permissions: Set(usersPermissions + userGroupsPermissions)
          )
        }
    }
  }
}
