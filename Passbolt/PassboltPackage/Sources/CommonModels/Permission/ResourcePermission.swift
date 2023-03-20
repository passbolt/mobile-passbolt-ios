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

import Commons

public enum ResourcePermission {

  case user(
    id: User.ID,
    permission: Permission,
    permissionID: Permission.ID?  // none is local, not synchronized permission
  )
  case userGroup(
    id: UserGroup.ID,
    permission: Permission,
    permissionID: Permission.ID?  // none is local, not synchronized permission
  )
}

extension ResourcePermission: Hashable {}

extension ResourcePermission {

  public var userID: User.ID? {
    switch self {
    case let .user(id, _, _):
      return id

    case .userGroup:
      return .none
    }
  }

  public var userGroupID: UserGroup.ID? {
    switch self {
    case .user:
      return .none

    case .userGroup(let id, _, _):
      return id
    }
  }

  public var permissionID: Permission.ID? {
    switch self {
    case let .user(_, _, permissionID):
      return permissionID

    case let .userGroup(_, _, permissionID):
      return permissionID
    }
  }

  public var permission: Permission {
    switch self {
    case let .user(_, permission, _):
      return permission

    case let .userGroup(_, permission, _):
      return permission
    }
  }
}
