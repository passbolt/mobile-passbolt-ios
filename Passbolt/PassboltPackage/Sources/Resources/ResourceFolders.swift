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

import Accounts
import CommonModels
import Features
import NetworkClient

public struct ResourceFolders {

  public var details: (ResourceFolder.ID) async throws -> FolderDetails?
  public var filteredFolderContent: (AnyAsyncSequence<ResourceFoldersFilter>) -> AnyAsyncSequence<FolderContent>
  public var featureUnload: @FeaturesActor () async throws -> Void
}

public struct FolderContent {

  public var folderID: ResourceFolder.ID?  // none means root
  public var flattened: Bool
  public var subfolders: Array<ResourceFolderListItemDSV>
  public var resources: Array<ResourceListItemDSV>
}

public struct FolderDetails {

  public var folderID: ResourceFolder.ID
  public var name: String
  public var permissionType: PermissionType
}

extension FolderContent: Hashable {}

extension ResourceFolders: Feature {

  public static func load(
    in environment: AppEnvironment,
    using features: FeatureFactory,
    cancellables: Cancellables
  ) async throws -> Self {
    let diagnostics: Diagnostics = try await features.instance()
    let accountDatabase: AccountDatabase = try await features.instance()
    let sessionData: AccountSessionData = try await features.instance()

    nonisolated func details(
      _ folderID: ResourceFolder.ID
    ) async throws -> FolderDetails? {
      guard let folder: ResourceFolderDetailsDSV = try await accountDatabase.fetchFolder(folderID)
      else { return nil }
      return .init(
        folderID: folder.id,
        name: folder.name,
        permissionType: folder.permissionType
      )
    }

    nonisolated func filteredFolderContent(
      filters: AnyAsyncSequence<ResourceFoldersFilter>
    ) -> AnyAsyncSequence<FolderContent> {
      AsyncCombineLatestSequence(sessionData.updatesSequence(), filters)
        .map { (_, filter: ResourceFoldersFilter) async -> FolderContent in
          let folders: Array<ResourceFolderListItemDSV>
          do {
            folders =
              try await accountDatabase
              .fetchResourceFolderListItemDSVs(filter)
          }
          catch {
            diagnostics.log(error)
            folders = .init()
          }

          let resources: Array<ResourceListItemDSV>
          do {
            resources =
              try await accountDatabase
              .fetchResourceListItemDSVs(
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
            diagnostics.log(error)
            resources = .init()
          }

          return FolderContent(
            folderID: filter.folderID,
            flattened: filter.flattenContent,
            subfolders: folders,
            resources: resources
          )
        }
        .asAnyAsyncSequence()
    }

    @FeaturesActor func featureUnload() async throws {
      // always succeed
    }

    return Self(
      details: details(_:),
      filteredFolderContent: filteredFolderContent(filters:),
      featureUnload: featureUnload
    )
  }
}

#if DEBUG

extension ResourceFolders {

  public static var placeholder: Self {
    Self(
      details: unimplemented("You have to provide mocks for used methods"),
      filteredFolderContent: unimplemented("You have to provide mocks for used methods"),
      featureUnload: unimplemented("You have to provide mocks for used methods")
    )
  }
}
#endif
