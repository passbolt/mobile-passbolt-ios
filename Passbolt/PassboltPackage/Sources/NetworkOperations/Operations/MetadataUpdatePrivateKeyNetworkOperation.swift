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

public typealias MetadataUpdatePrivateKeyNetworkOperation =
  NetworkOperation<MetadataUpdatePrivateKeyNetworkOperationDescription>

public enum MetadataUpdatePrivateKeyNetworkOperationDescription: NetworkOperationDescription {

  public struct Input: Encodable {

    public let privateKeyId: MetadataKeyDTO.ID
    public let data: String

    public init(
      privateKeyId: MetadataKeyDTO.ID,
      data: String
    ) {
      self.privateKeyId = privateKeyId
      self.data = data
    }

    public enum CodingKeys: String, CodingKey {
      // ignoring `privateKeyId` field as it is part of the URL
      case data
    }
  }

  public struct Output: Decodable {

    public let userId: User.ID
    public let data: String
    public let createdBy: User.ID?
    public let modifiedBy: User.ID?

    public init(
      userId: User.ID,
      data: String,
      createdBy: User.ID?,
      modifiedBy: User.ID?
    ) {
      self.userId = userId
      self.data = data
      self.createdBy = createdBy
      self.modifiedBy = modifiedBy
    }
  }
}
