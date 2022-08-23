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
import Resources
import SessionData

// MARK: - Implementation

extension ResourceTags {

  @MainActor fileprivate static func load(
    features: FeatureFactory,
    cancellables: Cancellables
  ) async throws -> Self {
    let diagnostics: Diagnostics = features.instance()
    let sessionData: SessionData = try await features.instance()
    let resourceTagsListFetchDatabaseOperation: ResourceTagsListFetchDatabaseOperation = try await features.instance()

    nonisolated func filteredTagsList(
      filters: AnyAsyncSequence<String>
    ) -> AnyAsyncSequence<Array<ResourceTagListItemDSV>> {
      AsyncCombineLatestSequence(sessionData.updatesSequence, filters)
        .map { (_, filter: String) async -> Array<ResourceTagListItemDSV> in
          let tags: Array<ResourceTagListItemDSV>
          do {
            tags =
              try await resourceTagsListFetchDatabaseOperation(filter)
          }
          catch {
            diagnostics.log(error: error)
            tags = .init()
          }

          return tags
        }
        .asAnyAsyncSequence()
    }

    return Self(
      filteredTagsList: filteredTagsList(filters:)
    )
  }
}

extension FeatureFactory {

  internal func usePassboltResourceTags() {
    self.use(
      .lazyLoaded(
        ResourceTags.self,
        load: ResourceTags.load(features:cancellables:)
      )
    )
  }
}
