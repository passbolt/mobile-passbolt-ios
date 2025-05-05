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
import OSFeatures
import Resources
import SessionData

// MARK: - Implementation

extension ResourcesController {

  @MainActor fileprivate static func load(
    features: Features
  ) throws -> Self {
    try features.ensureScope(SessionScope.self)

    let sessionData: SessionData = try features.instance()
    let resourcesListFetchDatabaseOperation: ResourcesListFetchDatabaseOperation = try features.instance()
    let resourceDeleteNetworkOperation: ResourceDeleteNetworkOperation = try features.instance()

    @Sendable nonisolated func filteredResourcesList(
      _ filter: ResourcesFilter
    ) async throws -> Array<ResourceListItemDSV> {
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
          includedTypeSlugs: filter.otpOnly
            ? [.totp, .passwordWithTOTP, .v5StandaloneTOTP, .v5DefaultWithTOTP]
            : [],
          excludedTypeSlugs: [],
          permissions: Set(filter.permissions),
          tags: filter.tags,
          userGroups: filter.userGroups,
          folders: filter.folders.map {
            ResourcesFolderDatabaseFilter(
              folderID: $0.folderID,
              flattenContent: $0.flattenContent
            )
          },
          expiredOnly: filter.expiredOnly
        )
      )
    }

    @Sendable nonisolated func delete(
      resourceID: Resource.ID
    ) async throws {
      try await resourceDeleteNetworkOperation(.init(resourceID: resourceID))
      try await sessionData.refreshIfNeeded()
    }

    return Self(
      lastUpdate: sessionData.lastUpdate,
      filteredResourcesList: filteredResourcesList(_:),
      delete: delete(resourceID:)
    )
  }
}

extension FeaturesRegistry {

  internal mutating func usePassboltResources() {
    self.use(
      .lazyLoaded(
        ResourcesController.self,
        load: ResourcesController.load(features:)
      ),
      in: SessionScope.self
    )
  }
}
