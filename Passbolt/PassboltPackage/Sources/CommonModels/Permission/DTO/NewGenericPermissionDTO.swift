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

public enum NewGenericPermissionDTO {

  case userToResource(
    userID: User.ID,
    resourceID: Resource.ID,
    permission: Permission
  )
  case userToFolder(
    userID: User.ID,
    folderID: ResourceFolder.ID,
    permission: Permission
  )

  case userGroupToResource(
    userGroupID: UserGroup.ID,
    resourceID: Resource.ID,
    permission: Permission
  )
  case userGroupToFolder(
    userGroupID: UserGroup.ID,
    folderID: ResourceFolder.ID,
    permission: Permission
  )
}

extension NewGenericPermissionDTO {

  public var userID: User.ID? {
    switch self {
    case .userToResource(let userID, _, _),
      .userToFolder(let userID, _, _):
      return userID
    case .userGroupToResource,
      .userGroupToFolder:
      return .none
    }
  }

  public var userGroupID: UserGroup.ID? {
    switch self {
    case .userGroupToResource(let userGroupID, _, _),
      .userGroupToFolder(let userGroupID, _, _):
      return userGroupID
    case .userToResource,
      .userToFolder:
      return .none
    }
  }

  public var permission: Permission {
    switch self {
    case .userToResource(_, _, let permission),
      .userToFolder(_, _, let permission),
      .userGroupToResource(_, _, let permission),
      .userGroupToFolder(_, _, let permission):
      return permission
    }
  }
}

extension NewGenericPermissionDTO: Encodable {

  public func encode(
    to encoder: Encoder
  ) throws {
    var container: KeyedEncodingContainer<CodingKeys> = encoder.container(keyedBy: CodingKeys.self)

    switch self {
    case .userToResource(let userID, let resourceID, let permission):
      try container.encode("User", forKey: .subject)
      try container.encode(userID, forKey: .subjectID)
      try container.encode("Resource", forKey: .item)
      try container.encode(resourceID, forKey: .itemID)
      try container.encode(permission, forKey: .permission)

    case .userToFolder(let userID, let folderID, let permission):
      try container.encode("User", forKey: .subject)
      try container.encode(userID, forKey: .subjectID)
      try container.encode("Folder", forKey: .item)
      try container.encode(folderID, forKey: .itemID)
      try container.encode(permission, forKey: .permission)

    case .userGroupToResource(let userGroupID, let resourceID, let permission):
      try container.encode("Group", forKey: .subject)
      try container.encode(userGroupID, forKey: .subjectID)
      try container.encode("Resource", forKey: .item)
      try container.encode(resourceID, forKey: .itemID)
      try container.encode(permission, forKey: .permission)

    case .userGroupToFolder(let userGroupID, let folderID, let permission):
      try container.encode("Group", forKey: .subject)
      try container.encode(userGroupID, forKey: .subjectID)
      try container.encode("Folder", forKey: .item)
      try container.encode(folderID, forKey: .itemID)
      try container.encode(permission, forKey: .permission)
    }
  }
}

extension NewGenericPermissionDTO {

  private enum CodingKeys: String, CodingKey {

    case subject = "aro"
    case subjectID = "aro_foreign_key"
    case item = "aco"
    case itemID = "aco_foreign_key"
    case permission = "type"
  }
}

extension NewGenericPermissionDTO: Hashable {}
