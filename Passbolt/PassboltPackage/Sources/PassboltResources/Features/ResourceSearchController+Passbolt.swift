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

extension ResourceSearchController {

  @MainActor fileprivate static func load(
    features: Features,
    context: Context
  ) throws -> Self {
    try features.ensureScope(SessionScope.self)

    let sessionData: SessionData = try features.instance()
    let resourcesListFetchDatabaseOperation: ResourcesListFetchDatabaseOperation = try features.instance()

    let filterState: Variable<ResourceSearchFilter> = .init(
      initial: context
    )
    let searchState: ComputedVariable<ResourceSearchState> = .init(
      combining: filterState,
      and: sessionData.lastUpdate,
      combine: { (filter: ResourceSearchFilter, _) -> ResourceSearchState in
        ResourceSearchState(
          filter: filter,
          result: try await resourcesListFetchDatabaseOperation(
            .init(
              sorting: .modifiedRecently,
              text: filter.text,
              includedTypeSlugs: filter.includedTypes
            )
          )
        )
      }
    )

    @Sendable func refreshIfNeeded() async throws {
      try await sessionData.refreshIfNeeded()
    }

    return .init(
      state: searchState,
      refreshIfNeeded: refreshIfNeeded,
      updateFilter: { $0(&filterState.current) }
    )
  }
}

extension FeaturesRegistry {

  internal mutating func usePassboltResourceSearchController() {
    self.use(
      .disposable(
        ResourceSearchController.self,
        load: ResourceSearchController.load(features:context:)
      ),
      in: SessionScope.self
    )
  }
}
