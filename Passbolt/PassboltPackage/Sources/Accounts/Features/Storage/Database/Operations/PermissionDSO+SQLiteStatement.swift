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

extension PermissionDSO {

  internal var storeStatement: SQLiteStatement {
    switch self {
    case let .userToResource(userID, resourceID, permissionType):
      return .statement(
        """
        INSERT INTO
          usersResources(
            resourceID,
            userID,
            permissionType
          )
        SELECT
          resources.id,
          users.id,
          ?3
        FROM
          resources,
          users
        WHERE
          resources.id == ?1
        AND
          users.id == ?2
        ;
        """,
        arguments: resourceID,
        userID,
        permissionType.rawValue
      )

    case let .userToFolder(userID, resourceFolderID, type):
      return .statement(
        """
        INSERT INTO
          usersResourceFolders(
            resourceFolderID,
            userID,
            permissionType
          )
        SELECT
          resourceFolders.id,
          users.id,
          ?3
        FROM
          resourceFolders,
          users
        WHERE
          resourceFolders.id == ?1
        AND
          users.id == ?2
        ;
        """,
        arguments: resourceFolderID,
        userID,
        type.rawValue
      )

    case let .userGroupToResource(userGroupID, resourceID, type):
      return .statement(
        """
        INSERT INTO
          userGroupsResources(
            resourceID,
            userGroupID,
            permissionType
          )
        SELECT
          resources.id,
          userGroups.id,
          ?3
        FROM
          resources,
          userGroups
        WHERE
          resources.id == ?1
        AND
          userGroups.id == ?2
        ;
        """,
        arguments: resourceID,
        userGroupID,
        type.rawValue
      )

    case let .userGroupToFolder(userGroupID, resourceFolderID, type):
      return .statement(
        """
        INSERT INTO
          userGroupsResourceFolders(
            resourceFolderID,
            userGroupID,
            permissionType
          )
        SELECT
          resourceFolders.id,
          userGroups.id,
          ?3
        FROM
          resourceFolders,
          userGroups
        WHERE
          resourceFolders.id == ?1
        AND
          userGroups.id == ?2
        ;
        """,
        arguments: resourceFolderID,
        userGroupID,
        type.rawValue
      )
    }
  }
}
