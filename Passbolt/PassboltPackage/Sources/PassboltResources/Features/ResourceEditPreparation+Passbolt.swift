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
import Features
import Resources

extension ResourceEditPreparation {

  @MainActor fileprivate static func load(
    using features: Features
  ) throws -> ResourceEditPreparation {
    let resourceTypesFetchDatabaseOperation: ResourceTypesFetchDatabaseOperation = try features.instance()
    let resourceFolderPathFetchDatabaseOperation: ResourceFolderPathFetchDatabaseOperation = try features.instance()

    @Sendable nonisolated func prepareNew(
      _ slug: ResourceSpecification.Slug,
      parentFolderID: ResourceFolder.ID?,
      uri: URLString?
    ) async throws -> ResourceEditingContext {
      let resourceTypes: Array<ResourceType> = try await resourceTypesFetchDatabaseOperation()

      guard let resourceType: ResourceType = resourceTypes.first(where: { $0.specification.slug == slug })
      else { throw InvalidResourceTypeError.error() }
      let folderPath: OrderedSet<ResourceFolderPathItem>
      if let parentFolderID {
        folderPath = try await resourceFolderPathFetchDatabaseOperation.execute(parentFolderID)
      }
      else {
        folderPath = .init()
      }
      var resource: Resource = .init(
        path: folderPath,
        type: resourceType,
        meta: ResourceMetadataDTO.initialResourceMetadataJSON(for: resourceType)
      )

      if let value: JSON = uri.map({ .string($0.rawValue) }) {
        resource.meta.uris = JSON(arrayLiteral: value)
      }  // else skip

      return .init(
        editedResource: resource,
        availableTypes: resourceTypes
      )
    }

    @Sendable nonisolated func prepareExisting(
      resourceID: Resource.ID
    ) async throws -> ResourceEditingContext {
      let features: Features =
        try await features.branchIfNeeded(
          scope: ResourceScope.self,
          context: resourceID
        )

      let resourceController: ResourceController = try await features.instance()

      try await resourceController.fetchSecretIfNeeded(force: true)

      let resource: Resource = try await resourceController.state.value

      guard resource.permission.canEdit
      else {
        throw
          InvalidResourcePermission
          .error(message: "Attempting to edit a resource without edit permission")
          .recording(resource, for: "resource")
      }

      let resourceTypes: Array<ResourceType> = try await resourceTypesFetchDatabaseOperation()

      return .init(
        editedResource: resource,
        availableTypes: resourceTypes
      )
    }

    @Sendable func availableTypes() async throws -> Array<ResourceType> {
      try await resourceTypesFetchDatabaseOperation()
    }

    return .init(
      prepareNew: prepareNew(_:parentFolderID:uri:),
      prepareExisting: prepareExisting(resourceID:),
      availableTypes: availableTypes
    )
  }
}

extension FeaturesRegistry {

  internal mutating func usePassboltResourceEditPreparation() {
    self.use(
      .disposable(
        ResourceEditPreparation.self,
        load: ResourceEditPreparation.load(using:)
      ),
      in: SessionScope.self
    )
  }
}
