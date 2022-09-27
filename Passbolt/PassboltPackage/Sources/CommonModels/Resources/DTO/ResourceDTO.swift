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

import struct Foundation.Date

public struct ResourceDTO {

  public let id: Resource.ID
  public var typeID: ResourceType.ID
  public var parentFolderID: ResourceFolder.ID?
  public var name: String
  public var url: String?
  public var username: String?
  public var description: String?
  public var favoriteID: Resource.FavoriteID?
  public var permissionType: PermissionTypeDTO
  public var tags: Set<ResourceTagDTO>
  public var permissions: OrderedSet<PermissionDTO>
  public var modified: Date

  public init(
    id: Resource.ID,
    typeID: ResourceType.ID,
    parentFolderID: ResourceFolder.ID?,
    name: String,
    url: String?,
    username: String?,
    description: String?,
    favoriteID: Resource.FavoriteID?,
    permissionType: PermissionTypeDTO,
    tags: Set<ResourceTagDTO>,
    permissions: OrderedSet<PermissionDTO>,
    modified: Date
  ) {
    self.id = id
    self.typeID = typeID
    self.parentFolderID = parentFolderID
    self.name = name
    self.url = url
    self.username = username
    self.description = description
    self.favoriteID = favoriteID
    self.permissionType = permissionType
    self.tags = tags
    self.permissions = permissions
    self.modified = modified
  }
}

extension ResourceDTO: DTO {}

extension ResourceDTO {

  internal static let validator: Validator<Self> = Resource.ID
    .validator
    .contraMap(\.id)

  public var isValid: Bool {
    Self
      .validator
      .validate(self)
      .isValid
  }
}

extension ResourceDTO: Decodable {

  public init(
    from decoder: Decoder
  ) throws {
    let container: KeyedDecodingContainer<ResourceDTO.CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)

    self.id =
      try container
      .decode(
        Resource.ID.self,
        forKey: .id
      )
    self.typeID =
      try container
      .decode(
        ResourceType.ID.self,
        forKey: .typeID
      )
    self.parentFolderID =
      try container
      .decodeIfPresent(
        String.self,
        forKey: .parentFolderID
      )
      .map(ResourceFolder.ID.init(rawValue:))
    self.name = try container.decode(
      String.self,
      forKey: .name
    )
    self.url = try container.decodeIfPresent(
      String.self,
      forKey: .url
    )
    self.username =
      try container
      .decodeIfPresent(
        String.self,
        forKey: .username
      )
    self.description =
      try container
      .decodeIfPresent(
        String.self,
        forKey: .description
      )
    do {
      let favoriteConteiner = try container.nestedContainer(
        keyedBy: FavoriteCodingKeys.self,
        forKey: .favorite
      )
      self.favoriteID = try favoriteConteiner.decode(Resource.FavoriteID.self, forKey: .id)
    }
    catch {
      self.favoriteID = .none
    }
    let permissionContainer =
      try container
      .nestedContainer(
        keyedBy: PermissionCodingKeys.self,
        forKey: .permissionType
      )

    self.permissionType =
      try permissionContainer
      .decode(
        PermissionTypeDTO.self,
        forKey: .type
      )
    self.tags =
      try container.decodeIfPresent(
        Set<ResourceTagDTO>.self,
        forKey: .tags
      )
      ?? .init()

    self.permissions =
      try container
      .decode(
        OrderedSet<PermissionDTO>.self,
        forKey: .permissions
      )
    self.modified =
      try container
      .decode(
        Date.self,
        forKey: .modified
      )
  }

  private enum CodingKeys: String, CodingKey {

    case id = "id"
    case typeID = "resource_type_id"
    case parentFolderID = "folder_parent_id"
    case name = "name"
    case url = "uri"
    case username = "username"
    case description = "description"
    case favorite = "favorite"
    case permissionType = "permission"
    case tags = "tags"
    case permissions = "permissions"
    case modified = "modified"
  }

  private enum PermissionCodingKeys: String, CodingKey {

    case type = "type"
  }

  private enum FavoriteCodingKeys: String, CodingKey {

    case id = "id"
  }
}

#if DEBUG

extension ResourceDTO: RandomlyGenerated {

  public static func randomGenerator(
    using randomnessGenerator: RandomnessGenerator
  ) -> Generator<Self> {
    zip(
      with: ResourceDTO.init(
        id:
        typeID:
        parentFolderID:
        name:
        url:
        username:
        description:
        favoriteID:
        permissionType:
        tags:
        permissions:
        modified:
      ),
      Resource.ID
        .randomGenerator(using: randomnessGenerator),
      ResourceType.ID
        .randomGenerator(using: randomnessGenerator),
      ResourceFolder.ID
        .randomGenerator(using: randomnessGenerator)
        .optional(using: randomnessGenerator),
      Generator<String>
        .randomResourceName(using: randomnessGenerator),
      Generator<String>
        .randomURL(using: randomnessGenerator)
        .optional(using: randomnessGenerator),
      Generator<String>
        .randomEmail(using: randomnessGenerator)
        .optional(using: randomnessGenerator),
      Generator<String>
        .randomLongText(using: randomnessGenerator)
        .optional(using: randomnessGenerator),
      Resource.FavoriteID
        .randomGenerator(using: randomnessGenerator),
      PermissionTypeDTO
        .randomGenerator(using: randomnessGenerator),
      ResourceTagDTO
        .randomGenerator(using: randomnessGenerator)
        .array(withCountIn: 0..<3, using: randomnessGenerator)
        .map { Set($0) },
      PermissionDTO
        .randomGenerator(using: randomnessGenerator)
        .array(withCountIn: 0..<3, using: randomnessGenerator)
        .map { OrderedSet($0) },
      Int
        .randomGenerator(min: 0, max: 1024, using: randomnessGenerator)
        .map { Date(timeIntervalSince1970: .init($0)) }
    )
  }
}
#endif
