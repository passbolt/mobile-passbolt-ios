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

public struct Folders {

  // WARNING: to refresh data use Resources.refreshIfNeeded instead
  // this function is called by Resources if needed
  internal var refreshIfNeeded: () async throws -> Void
  // WARNING: do not call manually, it is intended to be called after
  // refreshing resources it is called by Resources if needed
  internal var resourcesUpdated: () async -> Void
  public var updates: () -> AnyAsyncSequence<Void>
  public var details: (Folder.ID) async throws -> FolderDetails?
  public var filteredFolderContent: (AnyAsyncSequence<FoldersFilter>) -> AnyAsyncSequence<FolderContent>
  public var featureUnload: @FeaturesActor () async throws -> Void
}

public struct FolderContent {

  public var folderID: Folder.ID?  // none means root
  public var flattened: Bool
  public var subfolders: Array<ListViewFolder>
  public var resources: Array<ListViewResource>
}

public struct FolderDetails {

  public var folderID: Folder.ID
  public var name: String
  public var permission: Permission
}

extension FolderContent: Hashable {}

extension Folders: Feature {

  public static func load(
    in environment: AppEnvironment,
    using features: FeatureFactory,
    cancellables: Cancellables
  ) async throws -> Self {
    let diagnostics: Diagnostics = try await features.instance()
    let networkClient: NetworkClient = try await features.instance()
    let accountDatabase: AccountDatabase = try await features.instance()

    let updatesSequence: AsyncValue<Void> = .init(initial: Void())

    nonisolated func refreshIfNeeded() async throws {
      let foldersResponse: FoldersRequestResponse =
        try await networkClient
        .foldersRequest
        .makeAsync()

      // TODO: when diffing endpoint becomes available
      // there should be some additional logic deciding
      // if to do the refresh or not

      try await accountDatabase
        .storeFolders(
          foldersResponse
            .body
            .map { responseFolder in
              let permission: Permission = {
                switch responseFolder.permission {
                case .read:
                  return .read

                case .write:
                  return .write

                case .owner:
                  return .owner
                }
              }()
              return Folder(
                id: .init(rawValue: responseFolder.id),
                name: responseFolder.name,
                permission: permission,
                shared: responseFolder.shared,
                parentFolderID: responseFolder
                  .parentFolderID
                  .map(Folder.ID.init(rawValue:))
              )
            }
        )
    }

    nonisolated func resourcesUpdated() async {
      updatesSequence.value = Void()
    }

    nonisolated func updates() -> AnyAsyncSequence<Void> {
      updatesSequence
        .asAnyAsyncSequence()
    }

    nonisolated func details(
      _ folderID: Folder.ID
    ) async throws -> FolderDetails? {
      guard let folder: Folder = try await accountDatabase.fetchFolder(folderID)
      else { return nil }
      return .init(
        folderID: folder.id,
        name: folder.name,
        permission: folder.permission
      )
    }

    nonisolated func filteredFolderContent(
      filters: AnyAsyncSequence<FoldersFilter>
    ) -> AnyAsyncSequence<FolderContent> {
      AsyncCombineLatestSequence(updatesSequence, filters)
        .map { (_: Void, filter: FoldersFilter) -> FoldersFilter in
          filter
        }
        .map { (filter: FoldersFilter) async -> FolderContent in
          let folders: Array<ListViewFolder>
          do {
            folders =
              try await accountDatabase
              .fetchListViewFolders(filter)
          }
          catch {
            diagnostics.log(error)
            folders = .init()
          }

          let resources: Array<ListViewResource>
          do {
            resources =
              try await accountDatabase
              .fetchListViewResources(
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
      refreshIfNeeded: refreshIfNeeded,
      resourcesUpdated: resourcesUpdated,
      updates: updates,
      details: details(_:),
      filteredFolderContent: filteredFolderContent(filters:),
      featureUnload: featureUnload
    )
  }
}

#if DEBUG

extension Folders {

  public static var placeholder: Self {
    Self(
      refreshIfNeeded: unimplemented("You have to provide mocks for used methods"),
      resourcesUpdated: unimplemented("You have to provide mocks for used methods"),
      updates: unimplemented("You have to provide mocks for used methods"),
      details: unimplemented("You have to provide mocks for used methods"),
      filteredFolderContent: unimplemented("You have to provide mocks for used methods"),
      featureUnload: unimplemented("You have to provide mocks for used methods")
    )
  }
}
#endif
