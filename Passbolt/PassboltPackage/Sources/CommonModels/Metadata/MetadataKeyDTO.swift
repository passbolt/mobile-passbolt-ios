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

public struct MetadataKeyDTO: Identifiable, Decodable {
  public typealias ID = Tagged<PassboltID, Self>
  
  public let id: ID
  public let fingerprint: String
  public let created: Date
  public let modified: Date
  public let deleted: Date?
  public let armoredKey: ArmoredPGPPublicKey
  public let privateKeys: [MetadataPrivateKey]
  
  public init(
    id: ID,
    fingerprint: String,
    created: Date,
    modified: Date,
    deleted: Date?,
    armoredKey: ArmoredPGPPublicKey,
    privateKeys: [MetadataPrivateKey]
  ) {
    self.id = id
    self.fingerprint = fingerprint
    self.created = created
    self.modified = modified
    self.deleted = deleted
    self.armoredKey = armoredKey
    self.privateKeys = privateKeys
  }
}

extension MetadataKeyDTO {
  enum CodingKeys: String, CodingKey {
    case id
    case fingerprint
    case created
    case modified
    case deleted
    case armoredKey = "armored_key"
    case privateKeys = "metadata_private_keys"
  }
}

extension MetadataKeyDTO {
  public struct MetadataPrivateKey: Decodable {
    public let id: MetadataKeyDTO.ID
    public let userId: Tagged<PassboltID, Self>
    public let encryptedData: String
    
    public init(
      id: MetadataKeyDTO.ID,
      userId: Tagged<PassboltID, Self>,
      encryptedData: String
    ) {
      self.id = id
      self.userId = userId
      self.encryptedData = encryptedData
    }
    
    enum CodingKeys: String, CodingKey {
      case id = "metadata_key_id"
      case userId = "user_id"
      case encryptedData = "data"
    }
  }
}
