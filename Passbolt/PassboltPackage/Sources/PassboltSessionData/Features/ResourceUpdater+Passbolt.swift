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
    let resourceStorePermissionsOperation: ResourceStorePermissionsDatabaseOperation = try features.instance()
    let resourceTagsRemoveUnusedDatabaseOperation: ResourceTagsRemoveUnusedDatabaseOperation = try features.instance()
    let resourcesRemoveDatabaseOperation: ResourceRemoveWithStateDatabaseOperation = try features.instance()
    let resourceUpdateFolderDatabaseOperation: ResourceUpdateFolderDatabaseOperation = try features.instance()
    let resourcesModificationDatesDatabaseOperation: ResourcesFetchModificationDateDatabaseOperation =
      try features.instance()
    let resourceSetFavoriteDatabaseOperation: ResourceSetFavoriteDatabaseOperation = try features.instance()
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

      let modificationDates: Array<ResourceModificationDate> = try await resourcesModificationDatesDatabaseOperation(
        supportedResources.map(\.id).asSet()
      )
      let modificationDatesById: [Resource.ID: ResourceModificationDate] = Dictionary(
        uniqueKeysWithValues: modificationDates.map { ($0.resourceId, $0) }
      )

      let processedResources: Array<ResourceDTO> = try await supportedResources.asyncCompactMap {
        resource in
        // verify if shared metadata key is required and is available - otherwise resource has to be dropped
        if resource.metadataKeyType == .shared,
          let keyId: MetadataKeyDTO.ID = resource.metadataKeyId,
          try await metadataKeysService.hasAccessToSharedKey(keyId) == false
        {
          return nil
        }
        if let existingModificationDate: ResourceModificationDate = modificationDatesById[resource.id],
          existingModificationDate.modificationDate >= resource.modified
        {
          do {
            try await resourceStateUpdateOperation.execute(.init(state: .none, filter: resource.id))
            // users table is truncated before resources are updated, so permissions must be re-stored
            try await resourceStorePermissionsOperation.execute(resource.permissions)
            // similarly, folder relation and favorite status must be re-applied
            try await resourceUpdateFolderDatabaseOperation.execute(
              .init(resourceID: resource.id, folderID: resource.parentFolderID)
            )
            try await resourceSetFavoriteDatabaseOperation.execute(
              .init(resourceID: resource.id, favoriteID: resource.favoriteID)
            )
          }
          catch {
            ResourceUpdateFailed
              .error()
              .recording(
                values: [
                  "resource_id": resource.id.rawValue,
                  "underlying_error": error.asTheError().diagnosticsDescription,
                ]
              )
              .logged()
          }
          return nil
        }
        return await process(resource: resource)
      }
      let validatedResources: Array<ResourceDTO> =
        try processedResources
        .compactMap { try $0.validate(resourceTypes: resourceTypes.get()) }

      guard validatedResources.isEmpty == false else { return }
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

      try await resourceStateUpdateOperation.execute(.init(state: .waitingForUpdate))
      let batchExecutor: BatchExecutor = .init(maxConcurrentTasks: configuration.maximumConcurrentTasks)
      let firstPage: PaginatedResponse<Array<ResourceDTO>> =
        try await resourceFetchOperation
        .execute(
          .init(
            page: 1,
            limit: configuration.maximumChunkSize
          )
        )
      let totalPages: Int = firstPage.totalPages
      await batchExecutor.addOperation {
        try await process(resources: firstPage.items)
      }
      if totalPages > 1 {
        for page in 2 ... totalPages {
          await batchExecutor.addOperation {
            try await fetchAndProcess(limit: configuration.maximumChunkSize, page: page)
          }
        }
      }
      try await batchExecutor.execute()

      try await metadataKeysService.cleanupDecryptionCache()
      try await resourcesRemoveDatabaseOperation.execute(.waitingForUpdate)
      try await resourceStateUpdateOperation.execute(.init(state: .none))
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
