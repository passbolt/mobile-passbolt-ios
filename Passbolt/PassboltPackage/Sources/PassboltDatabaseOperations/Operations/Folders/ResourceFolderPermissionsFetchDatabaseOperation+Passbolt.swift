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

extension ResourceFolderPermissionsFetchDatabaseOperation {
  @Sendable fileprivate static func execute(
    _ input: ResourceFolder.ID,
    connection: SQLiteConnection
  ) throws -> Array<ResourceFolderPermissionDSV> {
    let usersPermissionsStatement: SQLiteStatement =
      .statement(
        """
        SELECT
          usersResourceFolders.userID AS userID,
          usersResourceFolders.permissionType AS permissionType,
          usersResourceFolders.permissionID AS permissionID
        FROM
          usersResourceFolders
        WHERE
          usersResourceFolders.resourceFolderID == ?1;
        """,
        arguments: input
      )

    let userGroupsPermissionsStatement: SQLiteStatement =
      .statement(
        """
        SELECT
          userGroupsResourceFolders.userGroupID AS userGroupID,
          userGroupsResourceFolders.permissionType AS permissionType,
          userGroupsResourceFolders.permissionID AS permissionID
        FROM
          userGroupsResourceFolders
        WHERE
          userGroupsResourceFolders.resourceFolderID == ?1;
        """,
        arguments: input
      )

    let usersPermissions: Array<ResourceFolderPermissionDSV> =
      try connection
      .fetch(using: usersPermissionsStatement) { dataRow -> ResourceFolderPermissionDSV in
        guard
          let userID: User.ID = dataRow.userID.flatMap(User.ID.init(rawValue:)),
          let permissionType: PermissionTypeDSV = dataRow.permissionType.flatMap(PermissionTypeDSV.init(rawValue:)),
          let permissionID: Permission.ID = dataRow.permissionID.flatMap(Permission.ID.init(rawValue:))
        else {
          throw
            DatabaseIssue
            .error(
              underlyingError:
                DatabaseDataInvalid
                .error(for: ResourceUserGroupListItemDSV.self)
            )
        }

        return .user(
          id: userID,
          type: permissionType,
          permissionID: permissionID
        )
      }

    let userGroupsPermissions: Array<ResourceFolderPermissionDSV> =
      try connection
      .fetch(using: userGroupsPermissionsStatement) { dataRow -> ResourceFolderPermissionDSV in
        guard
          let userGroupID: UserGroup.ID = dataRow.userGroupID.flatMap(UserGroup.ID.init(rawValue:)),
          let permissionType: PermissionTypeDSV = dataRow.permissionType.flatMap(PermissionTypeDSV.init(rawValue:)),
          let permissionID: Permission.ID = dataRow.permissionID.flatMap(Permission.ID.init(rawValue:))
        else {
          throw
            DatabaseIssue
            .error(
              underlyingError:
                DatabaseDataInvalid
                .error(for: ResourceUserGroupListItemDSV.self)
            )
        }

        return .userGroup(
          id: userGroupID,
          type: permissionType,
          permissionID: permissionID
        )
      }

    return usersPermissions + userGroupsPermissions
  }
}

extension FeatureFactory {

  internal func usePassboltResourceFolderPermissionsFetchDatabaseOperation() {
    self.use(
      FeatureLoader.databaseOperation(
        of: ResourceFolderPermissionsFetchDatabaseOperation.self,
        execute: ResourceFolderPermissionsFetchDatabaseOperation.execute(_:connection:)
      )
    )
  }
}
