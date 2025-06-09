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
import Resources
import SessionData

extension ResourceSharePreparation {
  @MainActor fileprivate static func load(
    using features: Features
  ) throws -> ResourceSharePreparation {
    let metadataKeysService: MetadataKeysService = try features.instance()
    let resourceDetailsFetch: ResourceDetailsFetchDatabaseOperation = try features.instance()
    let shareSimulate: ResourceSimulateShareNetworkOperation = try features.instance()
    let resourceUpdateNetworkOperation: ResourceEditNetworkOperation = try features.instance()
    let resourceUpdatePreparation: ResourceUpdatePreparation = try features.instance()
    let sessionData: SessionData = try features.instance()

    @Sendable nonisolated func prepareResourceForSharing(resourceID: Resource.ID, changes: PermissionChanges) async throws {
      var resource: Resource = try await resourceDetailsFetch.execute(resourceID)

      guard
        resource.type.isV4ResourceType == false,
        resource.metadataKeyType == .user
      else { return }  // resource does not qualify for preparing or is already prepared

      guard
        let metadata: String = resource.meta.stringValue,
        let (encryptedMetadata, usedKey): (ArmoredPGPMessage, MetadataKeyDTO.ID) =
          try await metadataKeysService.encryptForSharing(metadata)
      else {
        throw
          InternalInconsistency
          .error("Failed to encrypt metadata for sharing")
      }
      resource.secret = try await resourceUpdatePreparation.fetchSecret(resourceID, resource.hasUnstructuredSecret)
      guard let resourceSecret: String = resource.secret.resourceSecretString
      else {
        throw
          InvalidInputData
          .error(message: "Invalid or missing resource secret")
      }
      let sharingSimulation: ResourceSimulateShareNetworkOperation.Output = try await shareSimulate.execute(
        .init(
          foreignModelId: resourceID.rawValue,
          editedPermissions: changes.changed.asOrderedSet(),
          removedPermissions: changes.removed.asOrderedSet()
        )
      )
      let userIDs: OrderedSet<User.ID> = sharingSimulation.changes[.added]?.asOrderedSet() ?? .init()

      _ = try await resourceUpdateNetworkOperation.execute(
        .init(
          resourceID: resourceID,
          resourceTypeID: resource.type.id,
          parentFolderID: resource.parentFolderID,
          metadata: encryptedMetadata,
          metadataKeyID: usedKey,
          metadataKeyType: .shared,
          secrets: try await resourceUpdatePreparation.prepareSecret(userIDs, resourceSecret)
            .map { (userID: $0.recipient, data: $0.message) }
        )
      )
      try await sessionData.refreshIfNeeded()
    }

    return .init(
      prepareResourceForSharing: prepareResourceForSharing
    )
  }
}

extension FeaturesRegistry {

  internal mutating func usePassboltResourceSharePreparation() {
    self.use(
      .disposable(
        ResourceSharePreparation.self,
        load: ResourceSharePreparation.load(using:)
      ),
      in: SessionScope.self
    )
  }
}
