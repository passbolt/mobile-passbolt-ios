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
import NetworkOperations
import Resources
import SessionData

// MARK: - Implementation

extension ResourceFavorites {

  @MainActor fileprivate static func load(
    features: FeatureFactory,
    context resourceID: Context,
    cancellables: Cancellables
  ) async throws -> Self {
    let sessionData: SessionData = try await features.instance()
    let resourceDetails: ResourceDetails = try await features.instance(context: resourceID)
    let resourceFavoriteAddNetworkOperation: ResourceFavoriteAddNetworkOperation = try await features.instance()
    let resourceFavoriteDeleteNetworkOperation: ResourceFavoriteDeleteNetworkOperation = try await features.instance()
    let resourceSetFavoriteDatabaseOperation: ResourceSetFavoriteDatabaseOperation = try await features.instance()

    @Sendable func toggleFavorite() async throws {
      if let favoriteID: Resource.FavoriteID = try await resourceDetails.details().favoriteID {
        try await sessionData.withLocalUpdate {
          try await resourceFavoriteDeleteNetworkOperation(.init(favoriteID: favoriteID))
          try await resourceSetFavoriteDatabaseOperation(.init(resourceID: resourceID, favoriteID: .none))
        }
      }
      else {
        try await sessionData.withLocalUpdate {
          let favoriteID: Resource.FavoriteID = try await resourceFavoriteAddNetworkOperation(
            .init(resourceID: resourceID)
          ).favoriteID
          try await resourceSetFavoriteDatabaseOperation(.init(resourceID: resourceID, favoriteID: favoriteID))
        }
      }
    }

    return .init(
      toggleFavorite: toggleFavorite
    )
  }
}

extension FeatureFactory {

  internal func usePassboltResourceFavorites() {
    self.use(
      .lazyLoaded(
        ResourceFavorites.self,
        load: ResourceFavorites.load(features:context:cancellables:)
      )
    )
  }
}
