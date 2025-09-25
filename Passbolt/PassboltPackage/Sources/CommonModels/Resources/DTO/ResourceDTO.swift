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
  public var permission: Permission
  public var permissions: OrderedSet<GenericPermissionDTO>
  public var favoriteID: Resource.Favorite.ID?
  public var tags: OrderedSet<ResourceTag>
  public let modified: Date
  public let expired: Date?
  public var metadata: ResourceMetadataDTO?
  public let metadataArmoredMessage: String?
  public let metadataKeyId: MetadataKeyDTO.ID?
  public let metadataKeyType: MetadataKeyDTO.MetadataKeyType?
  // V4 metadata fields
  public var name: String?
  public var uri: String?
  public var username: String?
  public var description: String?

  public init(
    id: Resource.ID,
    typeID: ResourceType.ID,
    parentFolderID: ResourceFolder.ID?,
    favoriteID: Resource.Favorite.ID?,
    name: String,
    permission: Permission,
    permissions: OrderedSet<GenericPermissionDTO>,
    uri: String?,
    username: String?,
    description: String?,
    tags: OrderedSet<ResourceTag>,
    modified: Date,
    expired: Date?,
    metadataArmoredMessage: String? = nil,
    metadataKeyId: MetadataKeyDTO.ID? = nil,
    metadataKeyType: MetadataKeyDTO.MetadataKeyType? = nil
  ) {
    self.id = id
    self.typeID = typeID
    self.parentFolderID = parentFolderID
    self.favoriteID = favoriteID
    self.name = name
    self.permission = permission
    self.permissions = permissions
    self.uri = uri
    self.username = username
    self.description = description
    self.tags = tags
    self.modified = modified
    self.expired = expired
    self.metadataArmoredMessage = metadataArmoredMessage
    self.metadataKeyId = metadataKeyId
    self.metadataKeyType = metadataKeyType
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
        UUID.self,
        forKey: .parentFolderID
      )
      .map(ResourceFolder.ID.init(rawValue:))
    do {
      let favoriteContainer = try container.nestedContainer(
        keyedBy: FavoriteCodingKeys.self,
        forKey: .favorite
      )
      self.favoriteID = try favoriteContainer.decode(Resource.Favorite.ID.self, forKey: .id)
    }
    catch {  // if decoding favorite fails there is no favorite
      self.favoriteID = .none
    }
    let permissionContainer =
      try container
      .nestedContainer(
        keyedBy: PermissionCodingKeys.self,
        forKey: .permission
      )
    self.permission =
      try permissionContainer
      .decode(
        Permission.self,
        forKey: .permission
      )
    self.permissions =
      try container
      .decode(
        OrderedSet<GenericPermissionDTO>.self,
        forKey: .permissions
      )
    self.tags =
      try container.decodeIfPresent(
        OrderedSet<ResourceTag>.self,
        forKey: .tags
      )
      ?? .init()
    self.modified =
      try container
      .decode(
        Date.self,
        forKey: .modified
      )
    self.expired =
      try container
      .decodeIfPresent(
        Date.self,
        forKey: .expired
      )
    // V4 metadata fields
    self.name = try container.decodeIfPresent(
      String.self,
      forKey: .name
    )
    self.uri = try container.decodeIfPresent(
      String.self,
      forKey: .uri
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
    self.metadataArmoredMessage = try container.decodeIfPresent(String.self, forKey: .metadataArmoredMessage)
    self.metadataKeyId = try container.decodeIfPresent(MetadataKeyDTO.ID.self, forKey: .metadataKeyId)
    self.metadataKeyType = try container.decodeIfPresent(MetadataKeyDTO.MetadataKeyType.self, forKey: .metadataKeyType)
  }

  private enum CodingKeys: String, CodingKey {

    case id = "id"
    case typeID = "resource_type_id"
    case parentFolderID = "folder_parent_id"
    case favorite = "favorite"
    case name = "name"
    case permission = "permission"
    case permissions = "permissions"
    case uri = "uri"
    case username = "username"
    case description = "description"
    case tags = "tags"
    case modified = "modified"
    case expired = "expired"
    case metadataArmoredMessage = "metadata"
    case metadataKeyId = "metadata_key_id"
    case metadataKeyType = "metadata_key_type"
  }

  private enum PermissionCodingKeys: String, CodingKey {

    case permission = "type"
  }

  private enum FavoriteCodingKeys: String, CodingKey {

    case id = "id"
  }

  // Use to validate resource DTO before insertion on DB
  public func validate(resourceTypes: Array<ResourceTypeDTO>) throws -> ResourceDTO {
    let uuidValidator = Validator<String>.uuid()
    do {
      //First validate ID to avoid log injection
      try uuidValidator.ensureValid(self.id.rawValue.rawValue.uuidString.lowercased())
    }
    catch {
      throw EntityValidationError.error(
        message: "Resource id is not a valid UUID",
        underlyingError: .none,
        details: [
          "id": [
            "type": "The id is not a valid UUID"
          ]
        ]
      )
    }

    do {
      //First validate type ID to avoid log injection
      try uuidValidator.ensureValid(self.typeID.rawValue.rawValue.uuidString.lowercased())
    }
    catch {
      throw EntityValidationError.error(
        message: "Resource type id is not a valid UUID",
        underlyingError: .none,
        details: [
          "id": [
            "type": "The type id is not a valid UUID"
          ]
        ]
      )
    }

    guard let resourceType = resourceTypes.first(where: { $0.id == self.typeID }) else {
      throw EntityValidationError.error(
        message: "Cannot find the resource type associated",
        underlyingError: .none,
        details: [
          "resourceId": self.id,
          "typeId": [
            "id": self.typeID,
            "exist": "The type does not match any stored type id",
          ],
        ]
      )
    }

    let path: OrderedSet<ResourceFolderPathItem> =
      self.parentFolderID.map {
        .init(arrayLiteral: .init(id: $0, name: "Unknown", shared: false))
      } ?? .init()

    //Reuse Resource type for validation
    var resource = Resource(
      id: self.id,
      path: path,
      favoriteID: self.favoriteID,
      type: ResourceType(id: self.typeID, slug: resourceType.specification.slug),
      permission: self.permission,
      tags: self.tags,
      modified: self.modified.asTimestamp,
      expired: self.expired?.asTimestamp
    )

    // Apply meta fields
    if let name = self.metadata?.name {
      resource.meta.name = .string(name)
    }
    if let uri = self.uri {
      resource.meta.uri = .string(uri)
    }
    if let username = self.metadata?.username {
      resource.meta.username = .string(username)
    }
    if let description = self.metadata?.description {
      resource.meta.description = .string(description)
    }

    do {
      // Validate field based on type
      try resource.validate()
    }
    catch {
      var details: Dictionary<String, Any> = ["id": self.id]
      if let errorDetails = error.asTheError().getDetails() {
        details.merge(errorDetails) { (current, _) in current }  // Retains existing values in case of conflict
      }
      throw EntityValidationError.error(
        message: error.asTheError().getMessage(),
        underlyingError: .none,
        details: details
      )
    }

    return self
  }
}
