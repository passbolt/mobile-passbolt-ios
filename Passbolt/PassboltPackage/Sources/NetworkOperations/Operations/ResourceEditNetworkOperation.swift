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

public typealias ResourceEditNetworkOperation =
  NetworkOperation<ResourceEditNetworkOperationDescription>

public enum ResourceEditNetworkOperationDescription: NetworkOperationDescription {

  public typealias Input = ResourceEditNetworkOperationVariable
  public typealias Output = ResourceEditNetworkOperationResult
}

public struct ResourceEditNetworkOperationVariable: Encodable, Sendable {

  public var resourceID: Resource.ID
  public var resourceTypeID: ResourceType.ID
  public var parentFolderID: ResourceFolder.ID?
  public var secrets: Array<Secret>
  public var metadataKeyID: MetadataKeyDTO.ID?
  public var metadataKeyType: MetadataKeyDTO.MetadataKeyType
  public var metadata: ArmoredPGPMessage
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
    resourceID: Resource.ID,
    resourceTypeID: ResourceType.ID,
    parentFolderID: ResourceFolder.ID?,
    metadata: ArmoredPGPMessage,
    metadataKeyID: MetadataKeyDTO.ID?,
    metadataKeyType: MetadataKeyDTO.MetadataKeyType,
    secrets: Array<(userID: User.ID, data: ArmoredPGPMessage)>,
    expired: Date? = .none
  ) {
    self.resourceID = resourceID
    self.resourceTypeID = resourceTypeID
    self.parentFolderID = parentFolderID
    self.metadata = metadata
    self.metadataKeyID = metadataKeyID
    self.metadataKeyType = metadataKeyType
    self.secrets = secrets.map { Secret(userID: $0.userID, data: $0.data) }
    self.expired = expired
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encodeIfPresent(self.parentFolderID, forKey: .parentFolderID)
    try container.encode(self.resourceTypeID, forKey: .resourceTypeID)
    try container.encode(self.metadata, forKey: .metadata)
    try container.encode(self.metadataKeyID, forKey: .metadataKeyID)
    try container.encode(self.metadataKeyType, forKey: .metadataKeyType)
    try container.encode(self.secrets, forKey: .secrets)
    try container.encode(self.expired, forKey: .expired)
  }

  public enum CodingKeys: String, CodingKey {

    case parentFolderID = "folder_parent_id"
    case resourceTypeID = "resource_type_id"
    case metadata
    case metadataKeyID = "metadata_key_id"
    case metadataKeyType = "metadata_key_type"
    case secrets = "secrets"
    case expired = "expired"
  }
}
