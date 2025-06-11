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
      let encryptedMetadata: ArmoredPGPMessage
      if sharing {
        guard
          let result:
            (
              encryptedMetadata: ArmoredPGPMessage,
              keyId: MetadataKeyDTO.ID
            ) = try await metadataKeysService.encryptForSharing(
              metadataString
            )
        else {
          throw MetadataEncryptionFailure.error()
        }
        metadataKeyId = result.keyId
        metadataKeyType = .shared
        encryptedMetadata = result.encryptedMetadata
      }
      else {
        guard let result = try await metadataKeysService.encrypt(metadataString, .userKey)
        else {
          throw MetadataEncryptionFailure.error()
        }
        encryptedMetadata = result
        metadataKeyId = resource.metadataKeyId
        metadataKeyType = .user
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
  public let metadataKeyId: MetadataKeyDTO.ID
  public let metadata: String
  public let metadataKeyType: MetadataKeyDTO.MetadataKeyType

  var encryptionType: MetadataKeysService.EncryptionType {
    metadataKeyType == .shared ? .sharedKey(metadataKeyId) : .userKey
  }

  init(resource: Resource) throws {
    var diagnostics: Array<DiagnosticsContext> = []
    if resource.metadataKeyId == nil {
      diagnostics.append(
        .context(.message("Missing metadata key ID"))
      )
    }
    if resource.meta.stringValue == nil {
      diagnostics.append(
        .context(.message("Missing metadata"))
      )
    }

    if resource.metadataKeyType == nil {
      diagnostics.append(
        .context(.message("Missing metadata key type"))
      )
    }
    guard
      let metadataKeyId = resource.metadataKeyId,
      let metadata = resource.meta.stringValue,
      let metadataKeyType = resource.metadataKeyType
    else {
      throw InvalidMetadataProperties.error(diagnostics)
    }
    self.metadataKeyId = metadataKeyId
    self.metadata = metadata
    self.metadataKeyType = metadataKeyType
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
