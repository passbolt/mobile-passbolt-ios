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

extension PermissionDSV {

  internal static func decode(
    from dataRow: SQLiteRow
  ) throws -> Self {
    guard
      let permissionID: Permission.ID = (dataRow.permissionID as String?).flatMap(Permission.ID.init(rawValue:))
    else {
      throw
      DatabaseIssue
        .error(
          underlyingError:
            DatabaseResultInvalid
            .error("Invalid Permission stored in the database")
        )
    }

    guard
      let rawPermission: Int = dataRow.permissionType as Int?,
      let permissionType: PermissionTypeDSV = .init(rawValue: rawPermission)
    else {
      throw
        DatabaseIssue
        .error(
          underlyingError:
            DatabaseResultInvalid
            .error("Invalid PermissionType stored in the database")
        )
    }

    if let userID: User.ID = dataRow.id.map(User.ID.init(rawValue:)) {
      if let resourceID: Resource.ID = dataRow.id.map(Resource.ID.init(rawValue:)) {
        return .userToResource(
          id: permissionID,
          userID: userID,
          resourceID: resourceID,
          type: permissionType
        )
      }
      else if let folderID: ResourceFolder.ID = dataRow.id.map(ResourceFolder.ID.init(rawValue:)) {
        return .userToFolder(
          id: permissionID,
          userID: userID,
          folderID: folderID,
          type: permissionType
        )
      }
      else {
        throw
          DatabaseIssue
          .error(
            underlyingError:
              DatabaseResultInvalid
              .error("Invalid Permission stored in the database")
          )
      }
    }
    else if let userGroupID: UserGroup.ID = dataRow.id.map(UserGroup.ID.init(rawValue:)) {
      if let resourceID: Resource.ID = dataRow.id.map(Resource.ID.init(rawValue:)) {
        return .userGroupToResource(
          id: permissionID,
          userGroupID: userGroupID,
          resourceID: resourceID,
          type: permissionType
        )
      }
      else if let folderID: ResourceFolder.ID = dataRow.id.map(ResourceFolder.ID.init(rawValue:)) {
        return .userGroupToFolder(
          id: permissionID,
          userGroupID: userGroupID,
          folderID: folderID,
          type: permissionType
        )
      }
      else {
        throw
          DatabaseIssue
          .error(
            underlyingError:
              DatabaseResultInvalid
              .error("Invalid Permission stored in the database")
          )
      }
    }
    else {
      throw
        DatabaseIssue
        .error(
          underlyingError:
            DatabaseResultInvalid
            .error("Invalid Permission stored in the database")
        )
    }
  }
}
