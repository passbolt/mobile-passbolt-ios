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

public enum GenericPermissionDTO {

  case userToResource(
    id: Permission.ID,
    userID: User.ID,
    resourceID: Resource.ID,
    permission: Permission
  )
  case userToFolder(
    id: Permission.ID,
    userID: User.ID,
    folderID: ResourceFolder.ID,
    permission: Permission
  )

  case userGroupToResource(
    id: Permission.ID,
    userGroupID: UserGroup.ID,
    resourceID: Resource.ID,
    permission: Permission
  )
  case userGroupToFolder(
    id: Permission.ID,
    userGroupID: UserGroup.ID,
    folderID: ResourceFolder.ID,
    permission: Permission
  )
}

extension GenericPermissionDTO {

  public var id: Permission.ID {
    switch self {
    case let .userToResource(id, _, _, _),
      let .userToFolder(id, _, _, _),
      let .userGroupToResource(id, _, _, _),
      let .userGroupToFolder(id, _, _, _):
      return id
    }
  }

  public var userID: User.ID? {
    switch self {
    case let .userToResource(_, userID, _, _),
      let .userToFolder(_, userID, _, _):
      return userID
    case .userGroupToResource,
      .userGroupToFolder:
      return .none
    }
  }

  public var userGroupID: UserGroup.ID? {
    switch self {
    case let .userGroupToResource(_, userGroupID, _, _),
      let .userGroupToFolder(_, userGroupID, _, _):
      return userGroupID
    case .userToResource,
      .userToFolder:
      return .none
    }
  }

  public var permission: Permission {
    switch self {
    case let .userToResource(_, _, _, permission),
      let .userToFolder(_, _, _, permission),
      let .userGroupToResource(_, _, _, permission),
      let .userGroupToFolder(_, _, _, permission):
      return permission
    }
  }
}

extension GenericPermissionDTO: Decodable {

  public init(
    from decoder: Decoder
  ) throws {
    let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)
    switch try (container.decode(String.self, forKey: .subject), container.decode(String.self, forKey: .item)) {
    case ("User", "Resource"):
      self = .userToResource(
        id: try container.decode(Permission.ID.self, forKey: .id),
        userID: try container.decode(User.ID.self, forKey: .subjectID),
        resourceID: try container.decode(Resource.ID.self, forKey: .itemID),
        permission: try container.decode(Permission.self, forKey: .permission)
      )

    case ("User", "Folder"):
      self = .userToFolder(
        id: try container.decode(Permission.ID.self, forKey: .id),
        userID: try container.decode(User.ID.self, forKey: .subjectID),
        folderID: try container.decode(ResourceFolder.ID.self, forKey: .itemID),
        permission: try container.decode(Permission.self, forKey: .permission)
      )

    case ("Group", "Resource"):
      self = .userGroupToResource(
        id: try container.decode(Permission.ID.self, forKey: .id),
        userGroupID: try container.decode(UserGroup.ID.self, forKey: .subjectID),
        resourceID: try container.decode(Resource.ID.self, forKey: .itemID),
        permission: try container.decode(Permission.self, forKey: .permission)
      )

    case ("Group", "Folder"):
      self = .userGroupToFolder(
        id: try container.decode(Permission.ID.self, forKey: .id),
        userGroupID: try container.decode(UserGroup.ID.self, forKey: .subjectID),
        folderID: try container.decode(ResourceFolder.ID.self, forKey: .itemID),
        permission: try container.decode(Permission.self, forKey: .permission)
      )

    case _:
      throw
        DecodingError
        .dataCorrupted(
          .init(
            codingPath: decoder.codingPath,
            debugDescription: "Undefined permission type"
          )
        )
    }
  }
}

extension GenericPermissionDTO: Encodable {

  public func encode(
    to encoder: Encoder
  ) throws {
    var container: KeyedEncodingContainer<CodingKeys> = encoder.container(keyedBy: CodingKeys.self)

    switch self {
    case let .userToResource(id, userID, resourceID, permission):
      try container.encode(id, forKey: .id)
      try container.encode("User", forKey: .subject)
      try container.encode(userID, forKey: .subjectID)
      try container.encode("Resource", forKey: .item)
      try container.encode(resourceID, forKey: .itemID)
      try container.encode(permission, forKey: .permission)

    case let .userToFolder(id, userID, folderID, permission):
      try container.encode(id, forKey: .id)
      try container.encode("User", forKey: .subject)
      try container.encode(userID, forKey: .subjectID)
      try container.encode("Folder", forKey: .item)
      try container.encode(folderID, forKey: .itemID)
      try container.encode(permission, forKey: .permission)

    case let .userGroupToResource(id, userGroupID, resourceID, permission):
      try container.encode(id, forKey: .id)
      try container.encode("Group", forKey: .subject)
      try container.encode(userGroupID, forKey: .subjectID)
      try container.encode("Resource", forKey: .item)
      try container.encode(resourceID, forKey: .itemID)
      try container.encode(permission, forKey: .permission)

    case let .userGroupToFolder(id, userID, folderID, permission):
      try container.encode(id, forKey: .id)
      try container.encode("Group", forKey: .subject)
      try container.encode(userID, forKey: .subjectID)
      try container.encode("Folder", forKey: .item)
      try container.encode(folderID, forKey: .itemID)
      try container.encode(permission, forKey: .permission)
    }
  }
}

extension GenericPermissionDTO {

  private enum CodingKeys: String, CodingKey {

    case id = "id"
    case subject = "aro"
    case subjectID = "aro_foreign_key"
    case item = "aco"
    case itemID = "aco_foreign_key"
    case permission = "type"
  }
}

extension GenericPermissionDTO: Hashable {}
