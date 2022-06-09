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

public enum NewPermissionDTO {

  case userToResource(
    userID: User.ID,
    resourceID: Resource.ID,
    type: PermissionTypeDTO
  )
  case userToFolder(
    userID: User.ID,
    folderID: ResourceFolder.ID,
    type: PermissionTypeDTO
  )

  case userGroupToResource(
    userGroupID: UserGroup.ID,
    resourceID: Resource.ID,
    type: PermissionTypeDTO
  )
  case userGroupToFolder(
    userGroupID: UserGroup.ID,
    folderID: ResourceFolder.ID,
    type: PermissionTypeDTO
  )
}

extension NewPermissionDTO {

  public var type: PermissionTypeDTO {
    switch self {
    case let .userToResource(_, _, type),
      let .userToFolder(_, _, type),
      let .userGroupToResource(_, _, type),
      let .userGroupToFolder(_, _, type):
      return type
    }
  }
}

extension NewPermissionDTO: DTO {}

extension NewPermissionDTO: Encodable {

  public func encode(
    to encoder: Encoder
  ) throws {
    var container: KeyedEncodingContainer<CodingKeys> = encoder.container(keyedBy: CodingKeys.self)

    switch self {
    case let .userToResource(userID, resourceID, type):
      try container.encode("User", forKey: .subject)
      try container.encode(userID, forKey: .subjectID)
      try container.encode("Resource", forKey: .item)
      try container.encode(resourceID, forKey: .itemID)
      try container.encode(type, forKey: .type)

    case let .userToFolder(userID, folderID, type):
      try container.encode("User", forKey: .subject)
      try container.encode(userID, forKey: .subjectID)
      try container.encode("Folder", forKey: .item)
      try container.encode(folderID, forKey: .itemID)
      try container.encode(type, forKey: .type)

    case let .userGroupToResource(userGroupID, resourceID, type):
      try container.encode("Group", forKey: .subject)
      try container.encode(userGroupID, forKey: .subjectID)
      try container.encode("Resource", forKey: .item)
      try container.encode(resourceID, forKey: .itemID)
      try container.encode(type, forKey: .type)

    case let .userGroupToFolder(userID, folderID, type):
      try container.encode("Group", forKey: .subject)
      try container.encode(userID, forKey: .subjectID)
      try container.encode("Folder", forKey: .item)
      try container.encode(folderID, forKey: .itemID)
      try container.encode(type, forKey: .type)
    }
  }
}

extension NewPermissionDTO {

  private enum CodingKeys: String, CodingKey {

    case subject = "aro"
    case subjectID = "aro_foreign_key"
    case item = "aco"
    case itemID = "aco_foreign_key"
    case type = "type"
  }
}

extension NewPermissionDTO: Hashable {}

#if DEBUG

extension NewPermissionDTO: RandomlyGenerated {

  public static func randomGenerator(
    using randomnessGenerator: RandomnessGenerator
  ) -> Generator<Self> {
    Generator<NewPermissionDTO>
      .any(
        of: zip(
          with: NewPermissionDTO.userToResource(userID:resourceID:type:),
          User.ID
            .randomGenerator(using: randomnessGenerator),
          Resource.ID
            .randomGenerator(using: randomnessGenerator),
          PermissionTypeDTO
            .randomGenerator(using: randomnessGenerator)
        ),
        zip(
          with: NewPermissionDTO.userToFolder(userID:folderID:type:),
          User.ID
            .randomGenerator(using: randomnessGenerator),
          ResourceFolder.ID
            .randomGenerator(using: randomnessGenerator),
          PermissionTypeDTO
            .randomGenerator(using: randomnessGenerator)
        ),
        zip(
          with: NewPermissionDTO.userGroupToResource(userGroupID:resourceID:type:),
          UserGroup.ID
            .randomGenerator(using: randomnessGenerator),
          Resource.ID
            .randomGenerator(using: randomnessGenerator),
          PermissionTypeDTO
            .randomGenerator(using: randomnessGenerator)
        ),
        zip(
          with: NewPermissionDTO.userGroupToFolder(userGroupID:folderID:type:),
          UserGroup.ID
            .randomGenerator(using: randomnessGenerator),
          ResourceFolder.ID
            .randomGenerator(using: randomnessGenerator),
          PermissionTypeDTO
            .randomGenerator(using: randomnessGenerator)
        ),
        using: randomnessGenerator
      )
  }
}
#endif

