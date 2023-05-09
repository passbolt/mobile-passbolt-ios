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
import Database

extension ResourcePermission {

  internal static func decode(
    from dataRow: SQLiteRow
  ) throws -> Self {
    guard
      let permissionID: Permission.ID = (dataRow.permissionID as String?).flatMap(Permission.ID.init(uuidString:))
    else {
      throw
        DatabaseDataInvalid
        .error(
          for: ResourcePermission.self,
          "Invalid or missing ID"
        )
        .recording(dataRow, for: "dataRow")
    }

    guard
      let rawPermission: Int = dataRow.permission as Int?,
      let permission: Permission = .init(rawValue: rawPermission)
    else {
      throw
        DatabaseDataInvalid
        .error(
          for: ResourcePermission.self,
          "Invalid or missing permission"
        )
        .recording(dataRow, for: "dataRow")
    }

    if let userID: User.ID = dataRow.userID.flatMap(User.ID.init(uuidString:)) {
      return .user(
        id: userID,
        permission: permission,
        permissionID: permissionID
      )
    }
    else if let userGroupID: UserGroup.ID = dataRow.userGroupID.flatMap(UserGroup.ID.init(uuidString:)) {
      return .userGroup(
        id: userGroupID,
        permission: permission,
        permissionID: permissionID
      )
    }
    else {
      throw
        DatabaseDataInvalid
        .error(
          for: ResourcePermission.self,
          "Invalid or missing user/group"
        )
        .recording(dataRow, for: "dataRow")
    }
  }
}
