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

import TestExtensions

@testable import PassboltResources

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class ResourceFavoritesTests: LoadableFeatureTestCase<ResourceFavorites> {

  override class var testedImplementationRegister: (FeatureFactory) -> @MainActor () -> Void {
    FeatureFactory.usePassboltResourceFavorites
  }

  override func prepare() throws {
    patch(
      \SessionData.withLocalUpdate,
      with: { (update) async throws in
        try await update()
      }
    )
    use(ResourceSetFavoriteDatabaseOperation.placeholder)
    use(ResourceFavoriteAddNetworkOperation.placeholder)
    use(ResourceFavoriteDeleteNetworkOperation.placeholder)
  }

  func test_toggleFavorite_throws_whenNetworkRequestThrows_whenAddingFavorite() {
    var resourceDetails: ResourceDetailsDSV = .random()
    resourceDetails.favoriteID = .none
    patch(
      \ResourceDetails.details,
      context: resourceDetails.id,
      with: always(resourceDetails)
    )
    patch(
      \ResourceFavoriteAddNetworkOperation.execute,
      with: alwaysThrow(MockIssue.error())
    )

    withTestedInstanceThrows(
      MockIssue.self,
      context: resourceDetails.id
    ) { (testedInstance: ResourceFavorites) in
      try await testedInstance.toggleFavorite()
    }
  }

  func test_toggleFavorite_throws_whenDatabaseUpdateThrows_whenAddingFavorite() {
    var resourceDetails: ResourceDetailsDSV = .random()
    resourceDetails.favoriteID = .none
    patch(
      \ResourceDetails.details,
      context: resourceDetails.id,
      with: always(resourceDetails)
    )
    patch(
      \ResourceFavoriteAddNetworkOperation.execute,
      with: always(.init(favoriteID: .random()))
    )
    patch(
      \ResourceSetFavoriteDatabaseOperation.execute,
      with: alwaysThrow(MockIssue.error())
    )

    withTestedInstanceThrows(
      MockIssue.self,
      context: resourceDetails.id
    ) { (testedInstance: ResourceFavorites) in
      try await testedInstance.toggleFavorite()
    }
  }

  func test_toggleFavorite_throws_whenNetworkRequestThrows_whenRemovingFavorite() {
    var resourceDetails: ResourceDetailsDSV = .random()
    resourceDetails.favoriteID = .random()
    patch(
      \ResourceDetails.details,
      context: resourceDetails.id,
      with: always(resourceDetails)
    )
    patch(
      \ResourceFavoriteDeleteNetworkOperation.execute,
      with: alwaysThrow(MockIssue.error())
    )

    withTestedInstanceThrows(
      MockIssue.self,
      context: resourceDetails.id
    ) { (testedInstance: ResourceFavorites) in
      try await testedInstance.toggleFavorite()
    }
  }

  func test_toggleFavorite_throws_whenDatabaseUpdateThrows_whenRemovingFavorite() {
    var resourceDetails: ResourceDetailsDSV = .random()
    resourceDetails.favoriteID = .random()
    patch(
      \ResourceDetails.details,
      context: resourceDetails.id,
      with: always(resourceDetails)
    )
    patch(
      \ResourceFavoriteDeleteNetworkOperation.execute,
      with: always(Void())
    )
    patch(
      \ResourceSetFavoriteDatabaseOperation.execute,
      with: alwaysThrow(MockIssue.error())
    )

    withTestedInstanceThrows(
      MockIssue.self,
      context: resourceDetails.id
    ) { (testedInstance: ResourceFavorites) in
      try await testedInstance.toggleFavorite()
    }
  }

  func test_toggleFavorite_removesFavorite_whenCurrentDetailsHaveFavorite() {
    var resourceDetails: ResourceDetailsDSV = .random()
    resourceDetails.favoriteID = .random()
    patch(
      \ResourceDetails.details,
      context: resourceDetails.id,
      with: always(resourceDetails)
    )
    patch(
      \ResourceFavoriteDeleteNetworkOperation.execute,
      with: { (variable: ResourceFavoriteDeleteNetworkOperationVariable) async throws in
        self.executed(using: variable.favoriteID)
      }
    )
    patch(
      \ResourceSetFavoriteDatabaseOperation.execute,
      with: always(Void())
    )

    withTestedInstanceExecuted(
      using: resourceDetails.favoriteID,
      context: resourceDetails.id
    ) { (testedInstance: ResourceFavorites) in
      try await testedInstance.toggleFavorite()
    }
  }

  func test_toggleFavorite_removesFavoriteFromDatabase_whenCurrentDetailsHaveNoFavorite() {
    var resourceDetails: ResourceDetailsDSV = .random()
    resourceDetails.favoriteID = .random()
    patch(
      \ResourceDetails.details,
      context: resourceDetails.id,
      with: always(resourceDetails)
    )
    patch(
      \ResourceFavoriteDeleteNetworkOperation.execute,
      with: always(Void())
    )
    patch(
      \ResourceSetFavoriteDatabaseOperation.execute,
      with: { (variable) async throws in
        self.executed(using: variable.favoriteID)
      }
    )

    withTestedInstanceExecuted(
      using: Optional<Resource.FavoriteID>.none,
      context: resourceDetails.id
    ) { (testedInstance: ResourceFavorites) in
      try await testedInstance.toggleFavorite()
    }
  }

  func test_toggleFavorite_addsFavorite_whenCurrentDetailsHaveNoFavorite() {
    var resourceDetails: ResourceDetailsDSV = .random()
    resourceDetails.favoriteID = .none
    patch(
      \ResourceDetails.details,
      context: resourceDetails.id,
      with: always(resourceDetails)
    )
    patch(
      \ResourceFavoriteAddNetworkOperation.execute,
      with: always(
        self.executed(returning: .init(favoriteID: .random()))
      )
    )
    patch(
      \ResourceSetFavoriteDatabaseOperation.execute,
      with: always(Void())
    )

    withTestedInstanceExecuted(
      context: resourceDetails.id
    ) { (testedInstance: ResourceFavorites) in
      try await testedInstance.toggleFavorite()
    }
  }

  func test_toggleFavorite_addsFavoriteToDatabase_whenCurrentDetailsHaveNoFavorite() {
    let expectedFavoriteID: Resource.FavoriteID = .random()
    var resourceDetails: ResourceDetailsDSV = .random()
    resourceDetails.favoriteID = .none
    patch(
      \ResourceDetails.details,
      context: resourceDetails.id,
      with: always(resourceDetails)
    )
    patch(
      \ResourceFavoriteAddNetworkOperation.execute,
      with: always(.init(favoriteID: expectedFavoriteID))
    )
    patch(
      \ResourceSetFavoriteDatabaseOperation.execute,
      with: { (variable) async throws in
        self.executed(using: variable.favoriteID)
      }
    )

    withTestedInstanceExecuted(
      using: expectedFavoriteID,
      context: resourceDetails.id
    ) { (testedInstance: ResourceFavorites) in
      try await testedInstance.toggleFavorite()
    }
  }
}
