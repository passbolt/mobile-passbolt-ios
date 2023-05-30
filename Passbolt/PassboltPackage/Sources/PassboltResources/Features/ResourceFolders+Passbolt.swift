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

extension ResourceFolders {

  @MainActor fileprivate static func load(
    features: Features,
    cancellables: Cancellables
  ) throws -> Self {
    try features.ensureScope(SessionScope.self)

    let resourceFoldersListFetchDatabaseOperation: ResourceFoldersListFetchDatabaseOperation =
      try features.instance()
    let resourcesListFetchDatabaseOperation: ResourcesListFetchDatabaseOperation = try features.instance()

    @Sendable nonisolated func details(
      _ folderID: ResourceFolder.ID
    ) async throws -> ResourceFolder {
      try await features.instance(
        of: ResourceFolderController.self,
        context: folderID
      )
      .state.value
    }

    @Sendable nonisolated func filteredFolderContent(
      filter: ResourceFoldersFilter
    ) async throws -> ResourceFolderContent {
      try Task.checkCancellation()

      let folders: Array<ResourceFolderListItemDSV> =
        try await resourceFoldersListFetchDatabaseOperation(
          .init(
            sorting: .nameAlphabetically,
            text: filter.text,
            folderID: filter.folderID,
            flattenContent: filter.flattenContent,
            permissions: filter.permissions
          )
        )

      try Task.checkCancellation()

      let resources: Array<ResourceListItemDSV> =
        try await resourcesListFetchDatabaseOperation(
          .init(
            sorting: .nameAlphabetically,
            text: filter.text,
            excludedTypeSlugs: [.totp],
            folders: .init(
              folderID: filter.folderID,
              flattenContent: filter.flattenContent
            )
          )
        )

      return ResourceFolderContent(
        folderID: filter.folderID,
        flattened: filter.flattenContent,
        subfolders: folders,
        resources: resources
      )
    }

    return Self(
      details: details(_:),
      filteredFolderContent: filteredFolderContent(filter:)
    )
  }
}

extension FeaturesRegistry {

  internal mutating func usePassboltResourceFolders() {
    self.use(
      .lazyLoaded(
        ResourceFolders.self,
        load: ResourceFolders.load(features:cancellables:)
      ),
      in: SessionScope.self
    )
  }
}
