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

import CommonModels
import NetworkOperations
import Resources
import FeatureScopes
import Crypto
import Session
import class Foundation.JSONDecoder
import struct Foundation.Data

extension MetadataKeysService {
  @MainActor static func load(
    features: Features
  ) throws -> Self {
    let context: SessionScope.Context = try features.context(of: SessionScope.self)
    let accountsDataStore: AccountsDataStore = try features.instance()
    let sessionCryptography: SessionCryptography = try features.instance()
    let fetchOperation: MetadataKeysFetchNetworkOperation = try features.instance()
    let decryptor: SessionCryptography = try features.instance()
    let jsonDecoder: JSONDecoder = .default
    let pgp: PGP = features.instance()
    let refreshTask: CriticalState<Task<Void, Error>?> = .init(.none)
    
    
    let cachedKeys: CriticalState<[CachedKeys.ID: CachedKeys]> = .init([:])
    
    @Sendable func decode(encryptedMessage: String) async throws -> MetadataDecryptedPrivateKey {
      let armoredMessage = ArmoredPGPMessage(rawValue: encryptedMessage)
      let decryptedMessage = try await decryptor.decryptMessage(armoredMessage, nil)
      let data = decryptedMessage.data(using: .utf8) ?? Data()
      return try jsonDecoder.decode(MetadataDecryptedPrivateKey.self, from: data)
    }
   
    @Sendable func createCachedKey(publicKey: MetadataKeyDTO, privateKeys: [MetadataDecryptedPrivateKey]) async throws -> CachedKeys {
      try publicKey.validate(withPrivateKeys: privateKeys)
      let privateKeys = privateKeys.map(\.armoredKey)
      let keysPair: CachedKeys = .init(id: publicKey.id, publicKey: publicKey.armoredKey, privateKeys: privateKeys)
      return keysPair
    }

    @Sendable nonisolated func initialize() async throws {
      let task: Task<Void, Error> = refreshTask.access { (task: inout Task<Void, Error>?) -> Task<Void, Error> in
        if let runningTask: Task<Void, Error> = task {
          return runningTask
        }
        else {
          let runningTask: Task<Void, Error> = .init {
            defer {
              refreshTask.access { task in
                task = .none
              }
            }
            let newCachedKeys = try await fetchKeys()
            cachedKeys.access { cachedKeys in
              cachedKeys = newCachedKeys
            }
          }
          task = runningTask
          return runningTask
        }
      }

      return try await task.value
    }
    
    @Sendable func fetchKeys() async throws -> [CachedKeys.ID: CachedKeys] {
      let newKeys = try await fetchOperation()
      
      var cachedKeys: [CachedKeys.ID: CachedKeys] = [:]
      for key in newKeys {
        let privateKeys: [MetadataDecryptedPrivateKey] = try await key.privateKeys.map { $0.encryptedData }.asyncMap(decode(encryptedMessage:))
        do {
          let cached = try await createCachedKey(publicKey: key, privateKeys: privateKeys)
          cachedKeys[key.id] = cached
        } catch {
          // log error, but don't break the process
          error.logged()
        }
      }
      return cachedKeys
    }
    
    @Sendable nonisolated func decryptWithSharedKey(message: String, keyId: MetadataKeyDTO.ID) async throws -> Data? {
      guard let keys = cachedKeys.get()[keyId] else { return nil }
      if let privateKey = keys.privateKeys.first {
        let result = try pgp.decrypt(message, "", privateKey).get()
        return result.data(using: .utf8)
      } else {
        let result = try await decryptor.decryptMessage(ArmoredPGPMessage(rawValue: message), nil)
        return result.data(using: .utf8)
      }
    }
    
    @Sendable nonisolated func decryptWithUserKey(message: String) async throws -> Data? {
      try await sessionCryptography.decryptMessage(.init(rawValue: message), nil).data(using: .utf8)
    }

    return .init(
      initialize: initialize,
      decryptWithSharedKey: decryptWithSharedKey,
      decryptWithUserKey: decryptWithUserKey
    )
  }
}

extension FeaturesRegistry {
  internal mutating func usePassboltMetadataKeysService() {
    self.use(
      .lazyLoaded(
        MetadataKeysService.self,
        load: MetadataKeysService.load(features:)
      ),
      in: SessionScope.self
    )
  }
}

private struct CachedKeys: Identifiable {
  let id: MetadataKeyDTO.ID
  let publicKey: ArmoredPGPPublicKey
  let privateKeys: [ArmoredPGPPrivateKey]
}

internal struct MetadataDecryptedPrivateKey: Decodable {
  let fingerprint: String
  let armoredKey: ArmoredPGPPrivateKey
  
  enum CodingKeys: String, CodingKey {
    case fingerprint
    case armoredKey = "armored_key"
  }
}

extension MetadataKeyDTO {
  func validate(withPrivateKeys privateKeys: [MetadataDecryptedPrivateKey]) throws {
    let maxLength: Int = 10_000
      
    guard armoredKey.count <= maxLength
    else {
      throw InvalidValue.tooLong(validationRule: ValidationRule.publicKeyTooLong, value: id, displayable: "Public key too long.")
    }
    for privateKey in privateKeys {
      guard privateKey.armoredKey.count <= maxLength
      else {
        throw InvalidValue.tooLong(validationRule: ValidationRule.privateKeyTooLong, value: id, displayable: "Private key too long.")
      }
      guard privateKey.fingerprint == fingerprint
      else {
        throw InvalidValue.invalid(
          validationRule: ValidationRule.fingerprintsMismatch,
          value: [
            "publicKeyFingerprint": fingerprint,
            "privateKeyFingerprint": privateKey.fingerprint
          ],
          displayable: "Public and private key fingerprints mismatch."
        )
      }
    }
  }
  
  struct ValidationRule {
    static let publicKeyTooLong: StaticString = "publicKeyTooLong"
    static let privateKeyTooLong: StaticString = "privateKeyTooLong"
    static let fingerprintsMismatch: StaticString = "fingerprintsMismatch"
  }
}
