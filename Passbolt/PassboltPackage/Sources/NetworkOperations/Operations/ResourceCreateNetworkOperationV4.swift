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

import Features
import struct Foundation.Date

import struct Foundation.Date

// MARK: - Interface

public typealias ResourceCreateNetworkOperationV4 =
  NetworkOperation<ResourceCreateNetworkOperationV4Description>

public enum ResourceCreateNetworkOperationV4Description: NetworkOperationDescription {

  public typealias Input = ResourceCreateNetworkOperationV4Variable
  public typealias Output = ResourceCreateNetworkOperationResult
}

public struct ResourceCreateNetworkOperationV4Variable: Encodable, Sendable {

  public var resourceTypeID: ResourceType.ID
  public var parentFolderID: ResourceFolder.ID?
  public var name: String
  public var username: String?
  public var url: URLString?
  public var description: String?
  public var secrets: Array<Secret>
  public var expired: Date?

  public struct Secret: Encodable, Sendable {

    public var userID: User.ID
    public var data: ArmoredPGPMessage

    public enum CodingKeys: String, CodingKey {

      case userID = "user_id"
      case data = "data"
    }
  }

  public init(
    resourceTypeID: ResourceType.ID,
    parentFolderID: ResourceFolder.ID?,
    name: String,
    username: String?,
    url: URLString?,
    description: String?,
    secrets: OrderedSet<EncryptedMessage>,
    expired: Date? = .none
  ) {
    self.resourceTypeID = resourceTypeID
    self.parentFolderID = parentFolderID
    self.name = name
    self.username = username
    self.url = url
    self.description = description
    self.secrets = secrets.map { Secret(userID: $0.recipient, data: $0.message) }
    self.expired = expired
  }

  public enum CodingKeys: String, CodingKey {

    case name = "name"
    case parentFolderID = "folder_parent_id"
    case description = "description"
    case username = "username"
    case url = "uri"
    case resourceTypeID = "resource_type_id"
    case secrets = "secrets"
    case expired = "expired"
  }
}

public struct ResourceCreateNetworkOperationResult: Decodable, Sendable {

  public let resource: ResourceDTO
  public let ownerPermissionID: Permission.ID

  public var resourceID: Resource.ID { self.resource.id }

  public init(
    resource: ResourceDTO,
    ownerPermissionID: Permission.ID
  ) {
    self.resource = resource
    self.ownerPermissionID = ownerPermissionID
  }

  public init(
    from decoder: Decoder
  ) throws {
    self.resource = try ResourceDTO(from: decoder)

    let container: KeyedDecodingContainer<ResourceCreateNetworkOperationResult.CodingKeys> =
      try decoder.container(keyedBy: CodingKeys.self)
    let permissionContainer: KeyedDecodingContainer<ResourceCreateNetworkOperationResult.PermissionCodingKeys> =
      try container.nestedContainer(keyedBy: PermissionCodingKeys.self, forKey: .permission)
    self.ownerPermissionID = try permissionContainer.decode(Permission.ID.self, forKey: .permissionID)
  }

  public enum CodingKeys: String, CodingKey {

    case permission = "permission"
  }

  public enum PermissionCodingKeys: String, CodingKey {

    case permissionID = "id"
  }
}
