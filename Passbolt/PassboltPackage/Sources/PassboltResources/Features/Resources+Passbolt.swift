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

extension Resources {

  @MainActor fileprivate static func load(
    features: FeatureFactory,
    cancellables: Cancellables
  ) async throws -> Self {
    let diagnostics: Diagnostics = try await features.instance()
    let sessionData: SessionData = try await features.instance()
    let resourcesListFetchDatabaseOperation: ResourcesListFetchDatabaseOperation = try await features.instance()
    let resourceSecretFetchNetworkOperation: ResourceSecretFetchNetworkOperation = try await features.instance()
    let resourceDeleteNetworkOperation: ResourceDeleteNetworkOperation = try await features.instance()

    // initial refresh after loading
    // TODO: move to more appropriate place
    cancellables.executeAsync {
      do {
        try await sessionData.refreshIfNeeded()
      }
      catch {
        diagnostics.log(error)
      }
    }

    nonisolated func filteredResourcesListPublisher(
      _ filterPublisher: AnyPublisher<ResourcesFilter, Never>
    ) -> AnyPublisher<Array<ResourceListItemDSV>, Never> {
      // trigger refresh on data updates, publishes initially on subscription
      filterPublisher
        .map { filter -> AnyPublisher<Array<ResourceListItemDSV>, Error> in
          sessionData
            .updatesSequence
            .map { () async throws -> Array<ResourceListItemDSV> in
              try await resourcesListFetchDatabaseOperation(
                .init(
                  sorting: {
                    switch filter.sorting {
                    case .modifiedRecently:
                      return .modifiedRecently

                    case .nameAlphabetically:
                      return .nameAlphabetically
                    }
                  }(),
                  text: filter.text,
                  favoriteOnly: filter.favoriteOnly,
                  permissions: filter.permissions,
                  tags: filter.tags,
                  userGroups: filter.userGroups,
                  folders: filter.folders.map {
                    ResourcesFolderDatabaseFilter(
                      folderID: $0.folderID,
                      flattenContent: $0.flattenContent
                    )
                  }
                )
              )
            }
            .asThrowingPublisher()
            .eraseToAnyPublisher()
        }
        .switchToLatest()
        .replaceError(with: Array<ResourceListItemDSV>())
        .eraseToAnyPublisher()
    }

    @Sendable nonisolated func loadResourceSecret(
      _ resourceID: Resource.ID
    ) -> AnyPublisher<ResourceSecret, Error> {
      Just(Void())
        .eraseErrorType()
        .asyncMap { () async throws -> ResourceSecret in
          try await features
            .instance(
              of: ResourceDetails.self,
              context: resourceID
            )
            .secret()
        }
        .eraseToAnyPublisher()
    }

    @Sendable nonisolated func resourceDetailsPublisher(
      resourceID: Resource.ID
    ) -> AnyPublisher<ResourceDetailsDSV, Error> {
      sessionData
        .updatesSequence
        .map {
          try await features
            .instance(
              of: ResourceDetails.self,
              context: resourceID
            )
            .details()
        }
        .asThrowingPublisher()
    }

    @Sendable nonisolated func deleteResource(
      resourceID: Resource.ID
    ) -> AnyPublisher<Void, Error> {
      Just(Void())
        .eraseErrorType()
        .asyncMap {
          try await resourceDeleteNetworkOperation(
            .init(
              resourceID: resourceID
            )
          )

          try await sessionData.refreshIfNeeded()
        }
        .eraseToAnyPublisher()
    }

    return Self(
      filteredResourcesListPublisher: filteredResourcesListPublisher,
      loadResourceSecret: loadResourceSecret,
      resourceDetailsPublisher: resourceDetailsPublisher(resourceID:),
      deleteResource: deleteResource(resourceID:)
    )
  }
}

extension FeatureFactory {

  internal func usePassboltResources() {
    self.use(
      .lazyLoaded(
        Resources.self,
        load: Resources.load(features:cancellables:)
      )
    )
  }
}
