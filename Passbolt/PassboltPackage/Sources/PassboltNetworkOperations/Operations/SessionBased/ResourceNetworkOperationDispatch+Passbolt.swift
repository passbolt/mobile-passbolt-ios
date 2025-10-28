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

import FeatureScopes
import Metadata
import NetworkOperations
import Resources

extension ResourceNetworkOperationDispatch {
  @MainActor static func load(
    features: Features
  ) throws -> Self {
    let resourceCreateNetworkOperationV4: ResourceCreateNetworkOperationV4 = try features.instance()
    let resourceCreateNetworkOperation: ResourceCreateNetworkOperation = try features.instance()
    let resourceEditNetworkOperationV4: ResourceEditNetworkOperationV4 = try features.instance()
    let resourceEditNetworkOperation: ResourceEditNetworkOperation = try features.instance()
    let metadataKeysService: MetadataKeysService = try features.instance()

    @Sendable func createResource(
      resource: Resource,
      secrets: Secrets,
      sharing: Bool
    ) async throws -> ResourceCreateNetworkOperationResult {
      if resource.type.isV4ResourceType {
        return try await createResourceV4(resource: resource, secrets: secrets)
      }
      else {
        return try await createResourceV5(resource: resource, secrets: secrets, sharing: sharing)
      }
    }

    @Sendable func editResource(
      resource: Resource,
      withID id: Resource.ID,
      secrets: Secrets
    ) async throws -> ResourceEditNetworkOperationResult {
      if resource.type.isV4ResourceType {
        return try await editResourceV4(resource: resource, withID: id, secrets: secrets)
      }
      else {
        return try await editResourceV5(resource: resource, withID: id, secrets: secrets)
      }
    }

    @Sendable func createResourceV4(
      resource: Resource,
      secrets: Secrets
    ) async throws -> ResourceCreateNetworkOperationResult {
      try await resourceCreateNetworkOperationV4(
        .init(
          resourceTypeID: resource.type.id,
          parentFolderID: resource.parentFolderID,
          name: resource.name,
          username: resource.meta.username.stringValue,
          url: resource.meta.uris.arrayValue?.first?.stringValue.flatMap(URLString.init(rawValue:)),
          description: resource.meta.description.stringValue,
          secrets: secrets
        )
      )
    }

    @Sendable func createResourceV5(
      resource: Resource,
      secrets: Secrets,
      sharing: Bool
    ) async throws -> ResourceCreateNetworkOperationResult {
      guard let metadataString: String = resource.meta.stringValue
      else {
        throw MetadataEncryptionFailure.error()
      }
      let metadataKeyId: MetadataKeyDTO.ID?
      let metadataKeyType: MetadataKeyDTO.MetadataKeyType

      guard
        let encryptionType: MetadataKeysService.EncryptionType = metadataKeysService.determineKeyType(sharing),
        let encryptedMetadata: ArmoredPGPMessage = try await metadataKeysService.encrypt(
          metadataString,
          encryptionType
        )
      else {
        throw MetadataEncryptionFailure.error()
      }

      if case .sharedKey(let keyId) = encryptionType {
        metadataKeyId = keyId
        metadataKeyType = .shared
      }
      else {
        metadataKeyType = .user
        metadataKeyId = nil
      }

      return try await resourceCreateNetworkOperation(
        .init(
          resourceTypeID: resource.type.id,
          parentFolderID: resource.parentFolderID,
          metadata: encryptedMetadata,
          metadataKeyID: metadataKeyId,
          metadataKeyType: metadataKeyType,
          secrets: secrets
        )
      )
    }

    @Sendable func editResourceV4(
      resource: Resource,
      withID id: Resource.ID,
      secrets: Secrets
    ) async throws -> ResourceEditNetworkOperationResult {
      try await resourceEditNetworkOperationV4(
        .init(
          resourceID: id,
          resourceTypeID: resource.type.id,
          parentFolderID: resource.parentFolderID,
          name: resource.name,
          username: resource.meta.username.stringValue,
          url: (resource.meta.uris.arrayValue).flatMap { $0.first?.stringValue }.flatMap(URLString.init(rawValue:)),
          description: resource.meta.description.stringValue,
          secrets: secrets.map { (userID: $0.recipient, data: $0.message) }
        )
      )
    }

    @Sendable func editResourceV5(
      resource: Resource,
      withID id: Resource.ID,
      secrets: Secrets
    ) async throws -> ResourceEditNetworkOperationResult {
      var resource = resource

      if let metadataKeyType = metadataKeysService.determineKeyType(resource.isShared) {
        resource.updateMetadataKey(metadataKeyType)
      }

      let validatedMetadataProperties: ValidatedMetadataProperties = try .init(resource: resource)

      let encryptionType: MetadataKeysService.EncryptionType = validatedMetadataProperties.encryptionType
      guard
        let encryptedMetadata: ArmoredPGPMessage = try await metadataKeysService.encrypt(
          validatedMetadataProperties.metadata,
          encryptionType
        )
      else {
        throw MetadataEncryptionFailure.error()
      }
      return try await resourceEditNetworkOperation(
        .init(
          resourceID: id,
          resourceTypeID: resource.type.id,
          parentFolderID: resource.parentFolderID,
          metadata: encryptedMetadata,
          metadataKeyID: validatedMetadataProperties.metadataKeyId,
          metadataKeyType: validatedMetadataProperties.metadataKeyType,
          secrets: secrets.map { (userID: $0.recipient, data: $0.message) }
        )
      )
    }

    return .init(
      createResource: createResource(resource:secrets:sharing:),
      editResource: editResource(resource:withID:secrets:)
    )
  }
}

extension ResourceNetworkOperationDispatch {

  enum InvalidMetadataProperties: Error {

    case missingMetadataKeyId
    case missingMetadata
    case missingMetadataKeyType
  }
}

private struct ValidatedMetadataProperties {
  public let metadata: String

  public let encryptionType: MetadataKeysService.EncryptionType

  public let metadataKeyId: MetadataKeyDTO.ID

  public var metadataKeyType: MetadataKeyDTO.MetadataKeyType {
    switch encryptionType {
    case .sharedKey:
      return .shared
    case .userKey:
      return .user
    }
  }

  init(resource: Resource) throws {
    var diagnostics: Array<DiagnosticsContext> = []
    var encryptionType: MetadataKeysService.EncryptionType?
    var metadataKeyId: MetadataKeyDTO.ID?
    if let keyId = resource.metadataKeyId {
      encryptionType = .sharedKey(keyId)
      metadataKeyId = keyId
    }
    else {
      diagnostics.append(
        .context(.message("Missing metadata key ID"))
      )
    }
    if resource.metadataKeyType == .shared, let keyId = metadataKeyId {
      encryptionType = .sharedKey(keyId)
    }
    else if resource.metadataKeyType == .user {
      encryptionType = .userKey
    }
    else {
      diagnostics.append(
        .context(.message("Invalid metadata key type"))
      )
    }

    if resource.meta.stringValue == nil {
      diagnostics.append(
        .context(.message("Missing metadata"))
      )
    }

    guard
      let encryptionType = encryptionType,
      let keyId = metadataKeyId,
      let metadata = resource.meta.stringValue
    else {
      throw InvalidMetadataProperties.error(diagnostics)
    }
    self.encryptionType = encryptionType
    self.metadata = metadata
    self.metadataKeyId = keyId
  }
}

extension Resource {

  fileprivate mutating func updateMetadataKey(_ encryptionType: MetadataKeysService.EncryptionType) {
    switch encryptionType {
    case .sharedKey(let keyId) where self.metadataKeyType != .shared:
      self.metadataKeyId = keyId
      self.metadataKeyType = .shared
    case .userKey where self.metadataKeyType != .user:
      self.metadataKeyId = nil
      self.metadataKeyType = .user
    default:
      break  // no change
    }
  }
}

struct InvalidMetadataProperties: TheError {

  var context: DiagnosticsContext

  static func error(_ contexts: [DiagnosticsContext]) -> Self {
    Self(context: .merging(contexts))
  }
}

struct MetadataEncryptionFailure: TheError {

  var context: DiagnosticsContext

  static func error() -> Self {
    Self(
      context: .context(
        .message(
          "Failed to encrypt metadata"
        )
      )
    )
  }
}

extension FeaturesRegistry {

  internal mutating func usePassboltResourceNetworkOperationDispatch() {
    self.use(
      .lazyLoaded(
        ResourceNetworkOperationDispatch.self,
        load: ResourceNetworkOperationDispatch.load(features:)
      ),
      in: SessionScope.self
    )
  }
}
