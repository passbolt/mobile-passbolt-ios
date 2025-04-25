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

import Accounts
import CommonModels
import Crypto
import FeatureScopes
import NetworkOperations
import Resources
import Session
import Users

import struct Foundation.Data
import struct Foundation.Date
import class Foundation.JSONDecoder
import class Foundation.JSONEncoder

extension MetadataKeysService {

  private typealias KeysCache = Dictionary<CachedKeys.ID, CachedKeys>

  @MainActor static func load(
    features: Features
  ) throws -> Self {
    let context: SessionScope.Context = try features.context(of: SessionScope.self)
    let sessionCryptography: SessionCryptography = try features.instance()
    let fetchOperation: MetadataKeysFetchNetworkOperation = try features.instance()
    let userPGP: UsersPGPMessages = try features.instance()
    let jsonDecoder: JSONDecoder = .default
    let jsonEncoder: JSONEncoder = .default
    jsonEncoder.dateEncodingStrategy = .iso8601
    jsonDecoder.dateDecodingStrategy = .iso8601
    let pgp: PGP = features.instance()
    let refreshTask: CriticalState<Task<Void, Error>?> = .init(.none)

    let sessionKeysFetchNetworkOperation: MetadataSessionKeysFetchNetworkOperation = try features.instance()
    let sessionKeysUpdateNetworkOperation: MetadataSessionKeysUpdateNetworkOperation = try features.instance()

    let cachedKeys: CriticalState<KeysCache> = .init([:])
    let cachedSessionKeys: CriticalState<SessionKeysCache> = .init(.empty)

    @Sendable func decode(encryptedMessage: String) async throws -> MetadataDecryptedPrivateKey {
      let armoredMessage: ArmoredPGPMessage = .init(rawValue: encryptedMessage)
      let decryptedMessage: String = try await sessionCryptography.decryptMessage(armoredMessage, .none)
      let data: Data = .init(decryptedMessage.utf8)
      return try jsonDecoder.decode(MetadataDecryptedPrivateKey.self, from: data)
    }

    @Sendable func createCachedKey(
      publicKey: MetadataKeyDTO,
      privateKeys: Array<MetadataDecryptedPrivateKey>
    ) async throws -> CachedKeys {
      try publicKey.validate(withPrivateKeys: privateKeys)
      let privateKeys: Array<ArmoredPGPPrivateKey> = privateKeys.map(\.armoredKey)
      let keysPair: CachedKeys = .init(metadataKey: publicKey, privateKeys: privateKeys)
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
            let newCachedKeys: KeysCache = try await fetchKeys()
            cachedKeys.access { cachedKeys in
              cachedKeys = newCachedKeys
            }
            try await refreshSessionKeys()
          }
          task = runningTask
          return runningTask
        }
      }

      return try await task.value
    }

    @Sendable func fetchKeys() async throws -> KeysCache {
      let newKeys: Array<MetadataKeyDTO> = try await fetchOperation()

      var cachedKeys: KeysCache = .init()
      for key in newKeys {
        let privateKeys: Array<MetadataDecryptedPrivateKey> = try await key.privateKeys
          .map { $0.encryptedData }
          .asyncMap(decode(encryptedMessage:))
        do {
          let cached: CachedKeys = try await createCachedKey(publicKey: key, privateKeys: privateKeys)
          cachedKeys[key.id] = cached
        }
        catch {
          // log error, but don't break the process
          error.logged()
        }
      }
      return cachedKeys
    }

    @Sendable nonisolated func decrypt(
      message: String,
      reference: ForeignReference,
      decryptionKey: EncryptionType
    ) async throws -> Data? {
      if let sessionKeyData: SessionKeyData = cachedSessionKeys.get()[reference] {
        do {
          if let result: String = try pgp.decryptWithSessionKey(message, sessionKeyData.sessionKey) {
            return result.data(using: .utf8)
          }
        }
        catch {
          // don't break the process, try to use standard decryption method
          error.logged()
        }
      }

      let result: Data? = try await decrypt(message: message, decryptionKey: decryptionKey)
      if let sessionKey: SessionKey = try? await sessionCryptography.decryptSessionKey(.init(rawValue: message)) {
        cachedSessionKeys.access { keys in
          keys[reference] = .init(
            foreignModel: reference.model,
            foreignId: reference.id,
            sessionKey: sessionKey,
            modified: .now
          )
        }
      }

      return result
    }

    @Sendable nonisolated func decrypt(message: String, decryptionKey: EncryptionType) async throws -> Data? {
      if case .sharedKey(let keyId) = decryptionKey {
        guard let keys: CachedKeys = cachedKeys.get()[keyId] else { return .none }
        if let privateKey: ArmoredPGPPrivateKey = keys.privateKeys.first {
          let result: String = try pgp.decrypt(message, .empty, privateKey).get()
          return result.data(using: .utf8)
        }
      }

      return try await sessionCryptography.decryptMessage(.init(rawValue: message), .none).data(using: .utf8)
    }

    @Sendable func encrypt(message: String, with encryptionType: EncryptionType) async throws -> ArmoredPGPMessage? {
      if case .sharedKey(let keyId) = encryptionType {
        guard let keys: CachedKeys = cachedKeys.get()[keyId] else { return nil }
        let result: String = try pgp.encrypt(message, keys.publicKey).get()
        return .init(rawValue: result)
      }
      else {
        let userId: User.ID = context.account.userID
        return try await userPGP.encryptMessageForUsers([userId], message).first?.message
      }
    }

    @Sendable func encryptForSharing(message: String) async throws -> (ArmoredPGPMessage, MetadataKeyDTO.ID)? {
      guard
        let sharedKey: CachedKeys = cachedKeys.get()
          .values.first(where: { $0.expired == .none && $0.deleted == .none }),
        let result: ArmoredPGPMessage = try await encrypt(message: message, with: .sharedKey(sharedKey.id))
      else {
        return nil
      }

      return (result, sharedKey.id)
    }

    @Sendable func decryptSessionKeysBundle(encryptedMessage: ArmoredPGPMessage) async throws -> Array<SessionKeyData> {
      let decryptedMessage: String = try await sessionCryptography.decryptMessage(encryptedMessage, nil)
      return try jsonDecoder.decode(CachedSessionKeysMessage.self, from: Data(decryptedMessage.utf8))
        .validated()
        .sessionKeys
    }

    @Sendable func fetchSessionKeys() async throws -> SessionKeysCache {
      let sessionKeysResponse: Array<EncryptedSessionKeyBundle> = try await sessionKeysFetchNetworkOperation()
        .filter({ $0.userId == context.account.userID })
        .sorted(by: { $0.modifiedAt > $1.modifiedAt })

      var keys: Dictionary<ForeignReference, SessionKeyData> = .init()

      for sessionKeyBundle in sessionKeysResponse {
        do {
          let bundleKeysData: Array<SessionKeyData> = try await decryptSessionKeysBundle(
            encryptedMessage: sessionKeyBundle.data
          )

          for bundleKey in bundleKeysData where keys[bundleKey.key] == nil {
            keys[bundleKey.key] = bundleKey
          }
        }
        catch {
          error.logged()
        }
      }

      let newestBundle: EncryptedSessionKeyBundle? = keys.isEmpty ? nil : sessionKeysResponse.first
      let sessionKeysCache: SessionKeysCache = .init(
        id: newestBundle?.id,
        modifiedAt: newestBundle?.modifiedAt,
        keysByForeignReference: keys,
        localKeysByForeignReference: .init()
      )

      return sessionKeysCache
    }

    @Sendable func refreshSessionKeys() async throws {
      let newSessionKeysCache: SessionKeysCache = try await fetchSessionKeys()
      cachedSessionKeys.access { cachedSessionKeys in
        cachedSessionKeys.merge(with: newSessionKeysCache)
      }
    }

    @Sendable func prepareSessionKeysPayload() async throws -> EncryptedSessionKeysCache? {
      let currentCache: SessionKeysCache = cachedSessionKeys.get()
      let payload: CachedSessionKeysMessage = .init(sessionKeys: currentCache.allSessionKeys)
      let json: Data = try jsonEncoder.encode(payload)

      guard
        let jsonString: String = .init(data: json, encoding: .utf8),
        let encryptedMessage: ArmoredPGPMessage = try await encrypt(message: jsonString, with: .userKey)
      else { return nil }

      return .init(id: currentCache.id, modifiedAt: currentCache.modifiedAt, data: encryptedMessage)
    }

    @Sendable func trySendingSessionKeys() async throws {
      Diagnostics.logger.info("Preparing session keys for submission...")
      guard let payload: EncryptedSessionKeysCache = try await prepareSessionKeysPayload() else { return }
      Diagnostics.logger.info("Submitting session keys...")
      let response: EncryptedSessionKeysCache = try await sessionKeysUpdateNetworkOperation(payload)
      Diagnostics.logger.info("... session keys submitted.")
      let keys: Array<SessionKeyData> = try await decryptSessionKeysBundle(encryptedMessage: response.data)
      let keysByForeignReference: Dictionary<ForeignReference, SessionKeyData> = keys.reduce(into: .init()) {
        $0[$1.key] = $1
      }
      cachedSessionKeys.access { cachedSessionKeys in
        cachedSessionKeys = .init(
          id: cachedSessionKeys.id,
          modifiedAt: response.modifiedAt,
          keysByForeignReference: keysByForeignReference,
          localKeysByForeignReference: .init()
        )
      }
    }

    @Sendable func sendSessionKeys() async throws {
      do {
        try await trySendingSessionKeys()
      }
      catch is HTTPConflict {
        // possibly cache is updated by two different actors, attempt to refresh and re-submit - only once.
        Diagnostics.logger.info("Conflicting session keys cache - attempting to refresh and re-submit.")
        try await refreshSessionKeys()
        try await trySendingSessionKeys()
      }
    }

    return .init(
      initialize: initialize,
      decrypt: decrypt,
      encrypt: encrypt,
      encryptForSharing: encryptForSharing,
      sendSessionKeys: sendSessionKeys
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

  fileprivate var id: MetadataKeyDTO.ID
  fileprivate var publicKey: ArmoredPGPPublicKey
  fileprivate var privateKeys: Array<ArmoredPGPPrivateKey>
  fileprivate var expired: Date?
  fileprivate var deleted: Date?

  fileprivate init(metadataKey: MetadataKeyDTO, privateKeys: Array<ArmoredPGPPrivateKey>) {
    self.id = metadataKey.id
    self.publicKey = metadataKey.armoredKey
    self.privateKeys = privateKeys
    self.expired = metadataKey.expired
    self.deleted = metadataKey.deleted
  }
}

internal struct MetadataDecryptedPrivateKey: Decodable {

  internal var fingerprint: String
  internal var armoredKey: ArmoredPGPPrivateKey
  internal var objectType: MetadataObjectType

  private enum CodingKeys: String, CodingKey {

    case fingerprint
    case armoredKey = "armored_key"
    case objectType = "object_type"
  }
}

extension MetadataKeyDTO {

  func validate(withPrivateKeys privateKeys: Array<MetadataDecryptedPrivateKey>) throws {
    let maxLength: Int = 10_000

    guard armoredKey.count <= maxLength
    else {
      throw InvalidValue.tooLong(
        validationRule: ValidationRule.publicKeyTooLong,
        value: id,
        displayable: "Public key too long."
      )
    }
    for privateKey in privateKeys {
      guard privateKey.armoredKey.count <= maxLength
      else {
        throw InvalidValue.tooLong(
          validationRule: ValidationRule.privateKeyTooLong,
          value: id,
          displayable: "Private key too long."
        )
      }
      guard privateKey.fingerprint == fingerprint
      else {
        throw InvalidValue.invalid(
          validationRule: ValidationRule.fingerprintsMismatch,
          value: [
            "publicKeyFingerprint": fingerprint,
            "privateKeyFingerprint": privateKey.fingerprint,
          ],
          displayable: "Public and private key fingerprints mismatch."
        )
      }
      guard privateKey.objectType == .privateKeyMetadata
      else {
        throw InvalidValue.invalid(
          validationRule: ValidationRule.invalidObjectType,
          value: privateKey.objectType,
          displayable: "Invalid object type."
        )
      }
    }
  }

  internal struct ValidationRule {

    internal static let publicKeyTooLong: StaticString = "publicKeyTooLong"
    internal static let privateKeyTooLong: StaticString = "privateKeyTooLong"
    internal static let fingerprintsMismatch: StaticString = "fingerprintsMismatch"
    internal static let invalidObjectType: StaticString = "invalidObjectType"
  }
}

extension MetadataKeysService {

  fileprivate struct SessionKeyData: Codable, Sendable {

    fileprivate var foreignModel: ForeignModel
    fileprivate var foreignId: PassboltID
    fileprivate var sessionKey: SessionKey
    fileprivate var modified: Date?

    fileprivate var key: ForeignReference {
      .init(model: foreignModel, id: foreignId)
    }

    private enum CodingKeys: String, CodingKey {

      case foreignModel = "foreign_model"
      case foreignId = "foreign_id"
      case sessionKey = "session_key"
      case modified = "modified"
    }

    fileprivate struct Key: Hashable {

      fileprivate let foreignModel: ForeignModel
      fileprivate let foreignId: PassboltID
    }

    fileprivate func validate() throws {
      guard foreignModel != .unknown
      else {
        throw InvalidValue.invalid(
          validationRule: ValidationRule.invalidForeignModel,
          value: foreignModel,
          displayable: "Invalid foreign model."
        )
      }
    }

    fileprivate struct ValidationRule {

      static let invalidForeignModel: StaticString = "invalidForeignModel"
    }

    fileprivate func with(modifiedAt: Date) -> Self {
      if self.modified != nil {
        return self
      }

      return .init(
        foreignModel: foreignModel,
        foreignId: foreignId,
        sessionKey: sessionKey,
        modified: modifiedAt
      )
    }
  }

  fileprivate struct CachedSessionKeysMessage: Codable, Sendable {

    private var objectType: MetadataObjectType
    fileprivate var sessionKeys: Array<SessionKeyData>

    fileprivate init(sessionKeys: Array<SessionKeyData>) {
      self.objectType = .sessionKeys
      self.sessionKeys = sessionKeys
    }

    private enum CodingKeys: String, CodingKey {

      case objectType = "object_type"
      case sessionKeys = "session_keys"
    }

    fileprivate func validated() throws -> Self {
      guard objectType == .sessionKeys
      else {
        throw InvalidValue.invalid(
          validationRule: ValidationRule.invalidObjectType,
          value: objectType,
          displayable: "Invalid object type."
        )
      }

      var validSessionKeys: Array<SessionKeyData> = .init()

      for sessionKey in sessionKeys {
        do {
          try sessionKey.validate()
          validSessionKeys.append(sessionKey)
        }
        catch {
          // consume error, but don't break process
          error.logged()
        }
      }

      return .init(sessionKeys: validSessionKeys)
    }

    fileprivate struct ValidationRule {

      static let invalidObjectType: StaticString = "invalidObjectType"
    }
  }

  private struct SessionKeysCache {

    fileprivate let id: PassboltID?
    fileprivate var modifiedAt: Date?
    fileprivate var keysByForeignReference: Dictionary<ForeignReference, SessionKeyData>
    fileprivate var localKeysByForeignReference: Dictionary<ForeignReference, SessionKeyData>

    static fileprivate var empty: Self = .init(
      id: nil,
      keysByForeignReference: .init(),
      localKeysByForeignReference: .init()
    )

    fileprivate var allSessionKeys: Array<SessionKeyData> {
      keysByForeignReference.merging(localKeysByForeignReference) { remote, local in
        if let remoteModifiedAt = remote.modified,
          let localModifiedAt = local.modified
        {
          return remoteModifiedAt > localModifiedAt ? remote : local
        }

        return local
      }
      .values.map { $0 }
    }

    subscript(key: ForeignReference) -> SessionKeyData? {
      get {
        localKeysByForeignReference[key] ?? keysByForeignReference[key]
      }
      set(newValue) {
        keysByForeignReference[key] = newValue
      }
    }

    mutating func merge(with newCache: Self) {
      self = .init(
        id: newCache.id,
        modifiedAt: newCache.modifiedAt,
        keysByForeignReference: newCache.keysByForeignReference,
        localKeysByForeignReference: localKeysByForeignReference
      )
    }
  }
}
