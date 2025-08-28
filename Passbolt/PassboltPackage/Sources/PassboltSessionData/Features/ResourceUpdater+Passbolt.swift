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

import DatabaseOperations
import FeatureScopes
import Metadata
import NetworkOperations
import SessionData

import struct Foundation.Data
import class Foundation.NSLock

extension ResourceUpdater {

  @MainActor fileprivate static func load(
    features: Features
  ) throws -> Self {
    let resourceTypesFetchNetworkOperation: ResourceTypesFetchNetworkOperation = try features.instance()
    let resourceTypesStoreDatabaseOperation: ResourceTypesStoreDatabaseOperation = try features.instance()
    let resourceStateUpdateOperation: ResourceUpdateStateDatabaseOperation = try features.instance()
    let resourcesStoreDatabaseOperation: ResourcesStoreDatabaseOperation = try features.instance()
    let resourceFetchOperation: ResourcesFetchNetworkOperation = try features.instance()
    let resourceTagsRemoveUnusedDatabaseOperation: ResourceTagsRemoveUnusedDatabaseOperation = try features.instance()
    let resourcesRemoveDatabaseOperation: ResourceRemoveWithStateDatabaseOperation = try features.instance()
    let configuration: SessionConfiguration = try features.sessionConfiguration()
    let metadataKeysService: MetadataKeysService = try features.instance()

    let resourceTypes: CriticalState<Array<ResourceTypeDTO>> = .init(.init())
    let serialOperationExecutor: SerialDatabaseOperationExecutor = .init(
      resourcesStoreDatabaseOperation
    )

    @Sendable nonisolated func process(resource: ResourceDTO) async -> ResourceDTO? {
      do {
        if let armored = resource.metadataArmoredMessage,
          let keyId = resource.metadataKeyId,
          let keyType = resource.metadataKeyType
        {
          guard configuration.metadata.enabled else { return ResourceDTO?.none }
          var resource = resource
          let decryptionType: MetadataKeysService.EncryptionType = keyType == .shared ? .sharedKey(keyId) : .userKey
          if let decryptedMetadataData: Data = try await metadataKeysService.decrypt(
            armored,
            .resource(resource.id),
            decryptionType
          ) {
            let metadata: ResourceMetadataDTO = try .init(resourceId: resource.id, data: decryptedMetadataData)
            try metadata.validate(with: resource)
            resource.metadata = metadata
          }

          return resource
        }
        else {
          var resource = resource
          let metadata: ResourceMetadataDTO = try .init(resource: resource)
          try metadata.validate(with: resource)
          resource.metadata = metadata
          return resource
        }
      }
      catch {
        InternalInconsistency.error("Cannot decode metadata").logged()
      }
      return nil
    }

    @Sendable func process(resources: Array<ResourceDTO>) async throws {
      let supportedResources: Array<ResourceDTO> = resources.filter { resource in
        resourceTypes.get().contains { $0.id == resource.typeID }
      }

      let processedResources: Array<ResourceDTO> = await supportedResources.asyncCompactMap(process(resource:))
      let validatedResources: Array<ResourceDTO> =
        try processedResources
        .compactMap { try $0.validate(resourceTypes: resourceTypes.get()) }

      try await serialOperationExecutor.execute(validatedResources)
    }

    @Sendable func fetchAndProcess(limit: Int, page: Int) async throws {
      let page: PaginatedResponse<Array<ResourceDTO>> =
        try await resourceFetchOperation
        .execute(
          .init(
            page: page,
            limit: limit
          )
        )
      try await process(resources: page.items)
    }

    @Sendable func updateResources(_ configuration: Configuration) async throws {
      let allResourceTypes: Array<ResourceTypeDTO> = try await resourceTypesFetchNetworkOperation()
      let supportedResourceTypes: Array<ResourceTypeDTO> = allResourceTypes.filter { $0.isSupported }
      try await resourceTypesStoreDatabaseOperation(
        supportedResourceTypes
      )
      resourceTypes.set(supportedResourceTypes)

      try await resourceStateUpdateOperation.execute(.waitingForUpdate)

      let firstPage: PaginatedResponse<Array<ResourceDTO>> =
        try await resourceFetchOperation
        .execute(
          .init(
            page: 1,
            limit: configuration.maximumChunkSize
          )
        )
      let totalPages: Int = firstPage.totalPages

      if configuration.allowConcurrency {
        await withThrowingTaskGroup(of: Void.self) { group in
          group.addTask { try await process(resources: firstPage.items) }
          guard totalPages > 1 else {
            // No more pages to fetch
            return
          }
          for page in 2 ... totalPages {
            group.addTask { try await fetchAndProcess(limit: configuration.maximumChunkSize, page: page) }
          }
        }
      }
      else {
        try await process(resources: firstPage.items)
        if totalPages > 1 {
          for page in 2 ... totalPages {
            try await fetchAndProcess(limit: configuration.maximumChunkSize, page: page)
          }
        }
      }

      try await metadataKeysService.cleanupDecryptionCache()
      try await resourcesRemoveDatabaseOperation.execute(.waitingForUpdate)
      try await resourceStateUpdateOperation.execute(.none)
      try await resourceTagsRemoveUnusedDatabaseOperation()
    }

    return .init(updateResources: updateResources)
  }
}

extension FeaturesRegistry {

  internal mutating func usePassboltResourceUpdater() {
    self.use(
      .lazyLoaded(
        ResourceUpdater.self,
        load: ResourceUpdater.load(features:)
      ),
      in: SessionScope.self
    )
  }
}
