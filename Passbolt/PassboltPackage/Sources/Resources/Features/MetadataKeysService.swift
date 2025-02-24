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
import struct Foundation.Data

public struct MetadataKeysService {
  public var initialize: @Sendable () async throws -> Void
  public var decrypt: @Sendable (String, EncryptionType) async throws -> Data?
  public var encrypt: @Sendable (String, EncryptionType) async throws -> ArmoredPGPMessage?
  public var encryptForSharing: @Sendable (String) async throws -> (ArmoredPGPMessage, MetadataKeyDTO.ID)?

  public init(
    initialize: @escaping @Sendable () async throws -> Void,
    decrypt: @escaping @Sendable (String, EncryptionType) async throws -> Data?,
    encrypt: @escaping @Sendable (String, EncryptionType) async throws -> ArmoredPGPMessage?,
    encryptForSharing: @escaping @Sendable (String) async throws -> (ArmoredPGPMessage, MetadataKeyDTO.ID)?
  ) {
    self.initialize = initialize
    self.decrypt = decrypt
    self.encrypt = encrypt
    self.encryptForSharing = encryptForSharing
  }
  
  public func decrypt(message: String, withSharedKeyId sharedKeyId: MetadataKeyDTO.ID) async throws -> Data? {
    try await decrypt(message, .sharedKey(sharedKeyId))
  }
  
  public enum EncryptionType {
    case sharedKey(MetadataKeyDTO.ID)
    case userKey
  }
}

extension MetadataKeysService: LoadableFeature {

  #if DEBUG
  public nonisolated static var placeholder: Self {
    .init(
      initialize: unimplemented0(),
      decrypt: unimplemented2(),
      encrypt: unimplemented2(),
      encryptForSharing: unimplemented1()
    )
  }
  #endif
}
