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
    features: FeatureFactory,
    cancellables: Cancellables
  ) async throws -> Self {
    let diagnostics: Diagnostics = features.instance()
    let sessionData: SessionData = try await features.instance()
    let resourceFolderDetailsFetchDatabaseOperation: ResourceFolderDetailsFetchDatabaseOperation =
      try await features.instance()
    let resourceFoldersListFetchDatabaseOperation: ResourceFoldersListFetchDatabaseOperation =
      try await features.instance()
    let resourcesListFetchDatabaseOperation: ResourcesListFetchDatabaseOperation = try await features.instance()

    @Sendable nonisolated func details(
      _ folderID: ResourceFolder.ID
    ) async throws -> ResourceFolderDetails? {
      let folder: ResourceFolderDetailsDSV = try await resourceFolderDetailsFetchDatabaseOperation(folderID)
      return .init(
        folderID: folder.id,
        name: folder.name,
        permissionType: folder.permissionType
      )
    }

    @Sendable nonisolated func filteredFolderContent(
      filters: AnyAsyncSequence<ResourceFoldersFilter>
    ) -> AnyAsyncSequence<ResourceFolderContent> {
      AsyncCombineLatestSequence(sessionData.updatesSequence, filters)
        .map { (_, filter: ResourceFoldersFilter) async -> ResourceFolderContent in
          let folders: Array<ResourceFolderListItemDSV>
          do {
            folders =
              try await resourceFoldersListFetchDatabaseOperation(
                .init(
                  sorting: .nameAlphabetically,
                  text: filter.text,
                  folderID: filter.folderID,
                  flattenContent: filter.flattenContent,
                  permissions: filter.permissions
                )
              )
          }
          catch {
            diagnostics.log(error: error)
            folders = .init()
          }

          let resources: Array<ResourceListItemDSV>
          do {
            resources =
              try await resourcesListFetchDatabaseOperation(
                .init(
                  sorting: .nameAlphabetically,
                  text: filter.text,
                  folders: .init(
                    folderID: filter.folderID,
                    flattenContent: filter.flattenContent
                  )
                )
              )
          }
          catch {
            diagnostics.log(error: error)
            resources = .init()
          }

          return ResourceFolderContent(
            folderID: filter.folderID,
            flattened: filter.flattenContent,
            subfolders: folders,
            resources: resources
          )
        }
        .asAnyAsyncSequence()
    }

    return Self(
      details: details(_:),
      filteredFolderContent: filteredFolderContent(filters:)
    )
  }
}

extension FeatureFactory {

  internal func usePassboltResourceFolders() {
    self.use(
      .lazyLoaded(
        ResourceFolders.self,
        load: ResourceFolders.load(features:cancellables:)
      )
    )
  }
}
