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
import DatabaseOperations
import FeatureScopes
import Metadata
import NetworkOperations
import SessionData

import struct Foundation.Data

/// Outcome of inspecting a fetched resource: `changed` was decrypted for a full store, `unchanged` only
/// needs access/folder/favorite reconciled. Droppable resources map to `nil` instead.
private enum ResourceProcessingOutcome: Sendable {
  case changed(ResourceDTO)
  case unchanged(ResourceDTO)
}

extension ResourceUpdater {

  @MainActor fileprivate static func load(
    features: Features
  ) throws -> Self {
    let resourceTypesFetchNetworkOperation: ResourceTypesFetchNetworkOperation = try features.instance()
    let resourceTypesStoreDatabaseOperation: ResourceTypesStoreDatabaseOperation = try features.instance()
    let resourceTypesFetchDatabaseOperation: ResourceTypesFetchDatabaseOperation = try features.instance()
    let resourceStateUpdateOperation: ResourceUpdateStateDatabaseOperation = try features.instance()
    let resourcesStoreDatabaseOperation: ResourcesStoreDatabaseOperation = try features.instance()
    let resourceFetchOperation: ResourcesFetchNetworkOperation = try features.instance()
    let resourceTagsRemoveUnusedDatabaseOperation: ResourceTagsRemoveUnusedDatabaseOperation = try features.instance()
    let resourcesRemoveDatabaseOperation: ResourceRemoveWithStateDatabaseOperation = try features.instance()
    let resourcesModificationDatesDatabaseOperation: ResourcesFetchModificationDateDatabaseOperation =
      try features.instance()
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

    @Sendable func process(resources: Array<ResourceDTO>, concurrency: Int) async throws {
      let supportedResources: Array<ResourceDTO> = resources.filter { resource in
        resourceTypes.get().contains { $0.id == resource.typeID }
      }

      let modificationDates: Array<ResourceModificationDate> = try await resourcesModificationDatesDatabaseOperation(
        supportedResources.map(\.id).asSet()
      )
      let modificationDatesById: [Resource.ID: ResourceModificationDate] = Dictionary(
        uniqueKeysWithValues: modificationDates.map { ($0.resourceId, $0) }
      )

      // Decrypt only resources whose `modified` advanced; the rest are reconcile-only. One with an
      // unavailable shared metadata key is dropped (left `waitingForUpdate` for post-refresh cleanup).
      let outcomes: Array<ResourceProcessingOutcome> = try await supportedResources.asyncConcurrentCompactMap(
        maximumConcurrentTasks: concurrency
      ) {
        resource -> ResourceProcessingOutcome? in
        if resource.metadataKeyType == .shared,
          let keyId: MetadataKeyDTO.ID = resource.metadataKeyId,
          try await metadataKeysService.hasAccessToSharedKey(keyId) == false
        {
          return nil
        }
        if let existingModificationDate: ResourceModificationDate = modificationDatesById[resource.id],
          existingModificationDate.modificationDate >= resource.modified
        {
          return .unchanged(resource)
        }
        guard let processed: ResourceDTO = await process(resource: resource)
        else { return nil }
        return .changed(processed)
      }

      var decryptedResources: Array<ResourceDTO> = .init()
      var unchangedResources: Array<ResourceDTO> = .init()
      for outcome: ResourceProcessingOutcome in outcomes {
        switch outcome {
        case .changed(let resource):
          decryptedResources.append(resource)
        case .unchanged(let resource):
          unchangedResources.append(resource)
        }
      }
      let validatedResources: Array<ResourceDTO> =
        try decryptedResources
        .compactMap { try $0.validate(resourceTypes: resourceTypes.get()) }

      if validatedResources.isEmpty == false || unchangedResources.isEmpty == false {
        try await serialOperationExecutor.execute(
          .init(changed: validatedResources, unchanged: unchangedResources)
        )
      }
    }

    @Sendable func fetchAndProcess(limit: Int, page: Int, concurrency: Int) async throws {
      let page: PaginatedResponse<Array<ResourceDTO>> =
        try await resourceFetchOperation
        .execute(
          .init(
            page: page,
            limit: limit
          )
        )
      try await process(resources: page.items, concurrency: concurrency)
    }

    @Sendable func ensureResourceTypesLoaded() async throws -> Array<ResourceTypeDTO> {
      let allResourceTypes: Array<ResourceTypeDTO> = try await resourceTypesFetchNetworkOperation()
      let supportedResourceTypes: Array<ResourceTypeDTO> = allResourceTypes.filter { $0.isSupported }
      try await resourceTypesStoreDatabaseOperation(
        supportedResourceTypes
      )
      resourceTypes.set(supportedResourceTypes)
      return supportedResourceTypes
    }

    @Sendable func updateResource(_ resource: ResourceDTO) async throws {
      let supportedResourceTypes: Array<ResourceTypeDTO> = try await resourceTypesFetchDatabaseOperation()
        .filter { $0.isSupported }
      guard supportedResourceTypes.contains(where: { $0.id == resource.typeID })
      else {
        throw
          ResourceUpdateFailed
          .error()
          .recording(values: ["resource_id": resource.id.rawValue, "reason": "unsupported_resource_type"])
      }

      if resource.metadataKeyType == .shared,
        let keyId: MetadataKeyDTO.ID = resource.metadataKeyId,
        try await metadataKeysService.hasAccessToSharedKey(keyId) == false
      {
        throw
          ResourceUpdateFailed
          .error()
          .recording(values: ["resource_id": resource.id.rawValue, "reason": "shared_metadata_key_unavailable"])
      }

      guard let processed: ResourceDTO = await process(resource: resource)
      else {
        throw
          ResourceUpdateFailed
          .error()
          .recording(values: ["resource_id": resource.id.rawValue, "reason": "metadata_processing_failed"])
      }

      let validated: ResourceDTO = try processed.validate(resourceTypes: supportedResourceTypes)
      try await serialOperationExecutor.execute(.init(changed: [validated]))
    }

    @Sendable func updateResources(_ configuration: Configuration) async throws {
      _ = try await ensureResourceTypesLoaded()

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
        try await process(resources: firstPage.items, concurrency: configuration.maximumConcurrentDecryptions)
      }
      if totalPages > 1 {
        for page in 2 ... totalPages {
          await batchExecutor.addOperation {
            try await fetchAndProcess(
              limit: configuration.maximumChunkSize,
              page: page,
              concurrency: configuration.maximumConcurrentDecryptions
            )
          }
        }
      }
      try await batchExecutor.execute()

      try await metadataKeysService.cleanupDecryptionCache()
      try await resourcesRemoveDatabaseOperation.execute(.waitingForUpdate)
      try await resourceStateUpdateOperation.execute(.init(state: .none))
      try await resourceTagsRemoveUnusedDatabaseOperation()
    }

    return .init(
      updateResources: updateResources,
      updateResource: updateResource
    )
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
