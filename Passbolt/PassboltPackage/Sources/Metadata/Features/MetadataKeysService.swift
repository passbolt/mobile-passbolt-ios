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

import struct Foundation.Data

public struct MetadataKeysService {
  public var initialize: @Sendable () async throws -> Void
  public var decrypt: @Sendable (String, ForeignReference, EncryptionType) async throws -> Data?
  public var encrypt: @Sendable (String, EncryptionType) async throws -> ArmoredPGPMessage?
  public var encryptForSharing: @Sendable (String) async throws -> (ArmoredPGPMessage, MetadataKeyDTO.ID)?
  public var sendSessionKeys: @Sendable () async throws -> Void
  public var validatePinnedKey: @Sendable () async throws -> KeyValidationResult
  public var trustCurrentKey: @Sendable () async throws -> Void
  public var removePinnedKey: @Sendable () async throws -> Void
  public var cleanupDecryptionCache: @Sendable () async throws -> Void

  public init(
    initialize: @escaping @Sendable () async throws -> Void,
    decrypt: @escaping @Sendable (String, ForeignReference, EncryptionType) async throws -> Data?,
    encrypt: @escaping @Sendable (String, EncryptionType) async throws -> ArmoredPGPMessage?,
    encryptForSharing: @escaping @Sendable (String) async throws -> (ArmoredPGPMessage, MetadataKeyDTO.ID)?,
    sendSessionKeys: @escaping @Sendable () async throws -> Void,
    validatePinnedKey: @escaping @Sendable () async throws -> KeyValidationResult,
    trustCurrentKey: @escaping @Sendable () async throws -> Void,
    removePinnedKey: @escaping @Sendable () async throws -> Void,
    cleanupDecryptionCache: @escaping @Sendable () async throws -> Void
  ) {
    self.initialize = initialize
    self.decrypt = decrypt
    self.encrypt = encrypt
    self.encryptForSharing = encryptForSharing
    self.sendSessionKeys = sendSessionKeys
    self.validatePinnedKey = validatePinnedKey
    self.trustCurrentKey = trustCurrentKey
    self.removePinnedKey = removePinnedKey
    self.cleanupDecryptionCache = cleanupDecryptionCache
  }

  public func decrypt(
    message: String,
    resourceId: Resource.ID,
    withSharedKeyId sharedKeyId: MetadataKeyDTO.ID
  ) async throws -> Data? {
    try await decrypt(message, .resource(resourceId), .sharedKey(sharedKeyId))
  }

  public enum EncryptionType: Hashable {
    case sharedKey(MetadataKeyDTO.ID)
    case userKey
  }
}

extension MetadataKeysService: LoadableFeature {

  #if DEBUG
  public nonisolated static var placeholder: Self {
    .init(
      initialize: unimplemented0(),
      decrypt: unimplemented3(),
      encrypt: unimplemented2(),
      encryptForSharing: unimplemented1(),
      sendSessionKeys: unimplemented0(),
      validatePinnedKey: unimplemented0(),
      trustCurrentKey: unimplemented0(),
      removePinnedKey: unimplemented0(),
      cleanupDecryptionCache: unimplemented0()
    )
  }
  #endif
}

extension MetadataKeysService {

  public struct ForeignReference: Hashable, Sendable {

    public var model: ForeignModel
    public var id: PassboltID

    public init(model: ForeignModel, id: PassboltID) {
      self.model = model
      self.id = id
    }

    public static func resource(_ resourceId: Resource.ID) -> Self {
      .init(model: .resource, id: resourceId.rawValue)
    }
  }

  public enum ForeignModel: String, Codable, Sendable {

    case resource = "Resource"
    case unknown

    public init(from decoder: Decoder) throws {
      let container = try decoder.singleValueContainer()
      let rawValue = try container.decode(String.self)
      self = Self(rawValue: rawValue) ?? .unknown
    }
  }

  public enum KeyValidationResult: Sendable, Equatable {

    case valid
    case invalid(FailureReason)

    public enum FailureReason: Sendable, Equatable {

      public typealias ModifiedBy = Tagged<String, Self>

      case changed(ModifiedBy, Fingerprint)
      case deleted
      case unknown
    }
  }
}
