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
import NetworkOperations
import Resources
import SessionData

import class Foundation.JSONDecoder

// MARK: - Implementation

extension ResourceController {

  @MainActor fileprivate static func load(
    features: Features,
    cancellables: Cancellables
  ) throws -> Self {
    let resourceID: Resource.ID = try features.context(of: ResourceDetailsScope.self)

    let asyncExecutor: AsyncExecutor = try features.instance()

    let sessionData: SessionData = try features.instance()
    let sessionCryptography: SessionCryptography = try features.instance()
    let resourceDataFetchDatabaseOperation: ResourceDetailsFetchDatabaseOperation = try features.instance()
    let resourceUserPermissionsDetailsFetch: ResourceUserPermissionsDetailsFetchDatabaseOperation =
      try features.instance()
    let resourceUserGroupPermissionsDetailsFetch: ResourceUserGroupPermissionsDetailsFetchDatabaseOperation =
      try features.instance()
    let resourceSecretFetchNetworkOperation: ResourceSecretFetchNetworkOperation = try features.instance()
    let resourceDeleteNetworkOperation: ResourceDeleteNetworkOperation = try features.instance()
    let resourceFavoriteAddNetworkOperation: ResourceFavoriteAddNetworkOperation = try features.instance()
    let resourceFavoriteDeleteNetworkOperation: ResourceFavoriteDeleteNetworkOperation = try features.instance()
    let resourceSetFavoriteDatabaseOperation: ResourceSetFavoriteDatabaseOperation = try features.instance()

    let state: UpdatableVariable<Resource> = .init(
      using: sessionData.updates,
      compute: fetchMeta
    )

    @Sendable nonisolated func fetchMeta() async throws -> Resource {
      let resource: Resource = try await resourceDataFetchDatabaseOperation(
        resourceID
      )
      try resource.validate()
      return resource
    }

    @Sendable nonisolated func fetchSecretJSON(
      unstructured: Bool
    ) async throws -> JSON {
      let encryptedSecret: ArmoredPGPMessage =
        try await ArmoredPGPMessage(
          rawValue: resourceSecretFetchNetworkOperation(
            .init(
              resourceID: resourceID
            )
          )
          .data
        )

      let decryptedSecret: String =
        try await sessionCryptography
        // Skipping public key for signature verification.
        .decryptMessage(encryptedSecret, nil)

      // unstructured resource secret is just encrypted content
      // it is either for legacy password or unknown resource types
      if unstructured {
        return .string(decryptedSecret)
      }
      else {
        return try JSONDecoder()
          .decode(
            JSON.self,
            from:
              decryptedSecret
              .data(using: .utf8)
              ?? .init()
          )
      }
    }

    @Sendable nonisolated func fetchSecretIfNeeded(
      force: Bool
    ) async throws -> JSON {
      try await state.update { (resource: inout Resource) async throws -> JSON in
        guard force || !resource.secretAvailable
        else { return resource.secret }
        resource.secret = try await fetchSecretJSON(unstructured: resource.hasUnstructuredSecret)
        try resource.validate()  // validate resource with secret
        return resource.secret
      }
    }

    @Sendable func loadUserPermissionsDetails() async throws -> Array<UserPermissionDetailsDSV> {
      // there could be a cache if needed
      try await resourceUserPermissionsDetailsFetch(resourceID)
    }

    @Sendable func loadUserGroupPermissionsDetails() async throws -> Array<UserGroupPermissionDetailsDSV> {
      // there could be a cache if needed
      try await resourceUserGroupPermissionsDetailsFetch(resourceID)
    }

    @Sendable func toggleFavorite() async throws {
      if let favoriteID: Resource.Favorite.ID = try await state.current.favoriteID {
        try await resourceFavoriteDeleteNetworkOperation(.init(favoriteID: favoriteID))
        try await resourceSetFavoriteDatabaseOperation(.init(resourceID: resourceID, favoriteID: .none))
        state.mutate { (resource: inout Resource) in
          resource.favoriteID = .none
        }
      }
      else {
        let favoriteID: Resource.Favorite.ID = try await resourceFavoriteAddNetworkOperation(
          .init(resourceID: resourceID)
        )
        .favoriteID
        try await resourceSetFavoriteDatabaseOperation(.init(resourceID: resourceID, favoriteID: favoriteID))
        state.mutate { (resource: inout Resource) in
          resource.favoriteID = favoriteID
        }
      }
    }

    @Sendable nonisolated func delete() async throws {
      try await resourceDeleteNetworkOperation(.init(resourceID: resourceID))
      try await sessionData.refreshIfNeeded()
    }

    return Self(
      state: state,
      fetchSecretIfNeeded: fetchSecretIfNeeded,
      loadUserPermissionsDetails: loadUserPermissionsDetails,
      loadUserGroupPermissionsDetails: loadUserGroupPermissionsDetails,
      toggleFavorite: toggleFavorite,
      delete: delete
    )
  }
}

extension FeaturesRegistry {

  internal mutating func usePassboltResourceController() {
    self.use(
      .lazyLoaded(
        ResourceController.self,
        load: ResourceController.load(features:cancellables:)
      ),
      in: ResourceDetailsScope.self
    )
  }
}
