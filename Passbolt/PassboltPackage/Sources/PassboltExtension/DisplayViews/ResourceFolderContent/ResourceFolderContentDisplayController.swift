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

import Display
import FeatureScopes
import OSFeatures
import Resources
import SessionData

internal final class ResourceFolderContentDisplayController: ViewController {

  internal nonisolated let viewState: ViewStateSource<ViewState>

  internal var createFolder: (@Sendable () async throws -> Void)?
  internal var createResource: (@Sendable () async throws -> Void)?
  internal var selectFolder: @Sendable (ResourceFolder.ID) async throws -> Void
  internal var selectResource: @Sendable (Resource.ID) async throws -> Void
  internal var openResourceMenu: (@Sendable (Resource.ID) async throws -> Void)?

  private let sessionData: SessionData
  private let resourceFolders: ResourceFolders

  private let context: Context
  private let features: Features

  @MainActor public init(
    context: Context,
    features: Features
  ) throws {
    try features.ensureScope(SessionScope.self)

    self.context = context
    self.features = features

    self.sessionData = try features.instance()
    self.resourceFolders = try features.instance()

    self.createFolder = context.createFolder
    self.createResource = context.createResource
    self.selectFolder = context.selectFolder
    self.selectResource = context.selectResource
    self.openResourceMenu = context.openResourceMenu

    let pageSize: Int = context.pageSize

    self.viewState = .init(
      initial: .init(
        folderName: context.folderName,
        isSearchResult: false,
        directFolders: .init(),
        nestedFolders: .init(),
        suggestedResources: .init(),
        directResources: .init(),
        nestedResources: .init(),
        isLoadingMore: false,
        hasMoreFolders: true,
        hasMoreData: true,
        contentResetToken: 0,
        lastFilterText: ""
      ),
      updateFrom: ComputedVariable(
        combined: context.filter,
        with: self.sessionData.lastUpdate
      ),
      update: { [resourceFolders, context] updateView, update in
        let baseFilter: ResourceFoldersFilter = try update.value.0

        // fetch folders first
        var folderFilter: ResourceFoldersFilter = baseFilter
        folderFilter.limit = pageSize
        folderFilter.offset = 0

        let folderContent: ResourceFolderContent = try await resourceFolders.filteredFolderContent(folderFilter)
        let fetchedFolders: Array<ResourceFolderListItemDSV> = folderContent.subfolders
        let hasMoreFolders: Bool = fetchedFolders.count >= pageSize

        // fill remaining page slots with resources
        var fetchedResources: Array<ResourceListItemDSV> = .init()
        var hasMoreResources: Bool = false
        if !hasMoreFolders {
          let remaining: Int = pageSize - fetchedFolders.count
          if remaining > 0 {
            var resourceFilter: ResourceFoldersFilter = baseFilter
            resourceFilter.limit = remaining
            resourceFilter.offset = 0

            let resourceContent: ResourceFolderContent = try await resourceFolders.filteredFolderContent(
              resourceFilter
            )
            fetchedResources = resourceContent.resources
            hasMoreResources = fetchedResources.count >= remaining
          }
        }

        updateView { (viewState: inout ViewState) in
          viewState.isSearchResult = !baseFilter.text.isEmpty
          viewState.suggestedResources = fetchedResources.filter(context.suggestionFilter)
          viewState.directFolders =
            fetchedFolders
            .filter { $0.parentFolderID == baseFilter.folderID }
          viewState.nestedFolders =
            fetchedFolders
            .filter { $0.parentFolderID != baseFilter.folderID }
          viewState.directResources =
            fetchedResources
            .filter { $0.parentFolderID == baseFilter.folderID }
          viewState.nestedResources =
            fetchedResources
            .filter { $0.parentFolderID != baseFilter.folderID }
          viewState.hasMoreFolders = hasMoreFolders
          viewState.hasMoreData = hasMoreFolders || hasMoreResources
          viewState.isLoadingMore = false
          if viewState.lastFilterText != baseFilter.text {
            viewState.contentResetToken += 1
          }
          viewState.lastFilterText = baseFilter.text
        }
      }
    )
  }
}

extension ResourceFolderContentDisplayController {

  internal struct Context {

    internal var folderName: DisplayableString
    internal var filter: AnyUpdatable<ResourceFoldersFilter>
    internal var suggestionFilter: (ResourceListItemDSV) -> Bool
    internal var createFolder: (@Sendable () async throws -> Void)?
    internal var createResource: (@Sendable () async throws -> Void)?
    internal var selectFolder: @Sendable (ResourceFolder.ID) async throws -> Void
    internal var selectResource: @Sendable (Resource.ID) async throws -> Void
    internal var openResourceMenu: (@Sendable (Resource.ID) async throws -> Void)?
    internal var pageSize: Int

    internal init(
      folderName: DisplayableString,
      filter: AnyUpdatable<ResourceFoldersFilter>,
      suggestionFilter: @escaping (ResourceListItemDSV) -> Bool,
      createFolder: (@Sendable () async throws -> Void)? = .none,
      createResource: (@Sendable () async throws -> Void)? = .none,
      selectFolder: @Sendable @escaping (ResourceFolder.ID) async throws -> Void,
      selectResource: @Sendable @escaping (Resource.ID) async throws -> Void,
      openResourceMenu: (@Sendable (Resource.ID) async throws -> Void)? = .none,
      pageSize: Int = 50
    ) {
      self.folderName = folderName
      self.filter = filter
      self.suggestionFilter = suggestionFilter
      self.createFolder = createFolder
      self.createResource = createResource
      self.selectFolder = selectFolder
      self.selectResource = selectResource
      self.openResourceMenu = openResourceMenu
      self.pageSize = pageSize
    }
  }

  internal struct ViewState: Equatable {

    internal var folderName: DisplayableString
    internal var isSearchResult: Bool
    internal var directFolders: Array<ResourceFolderListItemDSV>
    internal var nestedFolders: Array<ResourceFolderListItemDSV>
    internal var suggestedResources: Array<ResourceListItemDSV>
    internal var directResources: Array<ResourceListItemDSV>
    internal var nestedResources: Array<ResourceListItemDSV>
    internal var isLoadingMore: Bool
    internal var hasMoreFolders: Bool
    internal var hasMoreData: Bool
    internal var contentResetToken: Int
    internal var lastFilterText: String
  }
}

extension ResourceFolderContentDisplayController {

  internal final func refresh() async {
    do {
      try await self.sessionData.refreshIfNeeded()
    }
    catch {
      error.consume(
        context: "Failed to refresh session data."
      )
    }
  }

  @MainActor internal final func loadMore() async {
    let currentState: ViewState = await viewState.current

    guard currentState.hasMoreData, !currentState.isLoadingMore else { return }

    self.viewState.update { state in
      state.isLoadingMore = true
    }

    do {
      let pageSize: Int = self.context.pageSize
      let currentFilter: ResourceFoldersFilter = try await self.context.filter.value

      let totalFolders: Int = currentState.directFolders.count + currentState.nestedFolders.count
      let totalResources: Int = currentState.directResources.count + currentState.nestedResources.count
      let folderID: ResourceFolder.ID? = currentFilter.folderID

      var newFolders: Array<ResourceFolderListItemDSV> = .init()
      var newResources: Array<ResourceListItemDSV> = .init()
      var hasMoreFolders: Bool = currentState.hasMoreFolders
      var hasMoreResources: Bool = false

      if hasMoreFolders {
        // try loading more folders
        var folderFilter: ResourceFoldersFilter = currentFilter
        folderFilter.limit = pageSize
        folderFilter.offset = totalFolders

        let folderContent: ResourceFolderContent = try await self.resourceFolders.filteredFolderContent(folderFilter)
        newFolders = folderContent.subfolders
        hasMoreFolders = newFolders.count >= pageSize

        // fill remaining page slots with resources
        if !hasMoreFolders {
          let remaining: Int = pageSize - newFolders.count
          if remaining > 0 {
            var resourceFilter: ResourceFoldersFilter = currentFilter
            resourceFilter.limit = remaining
            resourceFilter.offset = totalResources

            let resourceContent: ResourceFolderContent = try await self.resourceFolders.filteredFolderContent(
              resourceFilter
            )
            newResources = resourceContent.resources
            hasMoreResources = newResources.count >= remaining
          }
        }
      }
      else {
        // folders exhausted, load only resources
        var resourceFilter: ResourceFoldersFilter = currentFilter
        resourceFilter.limit = pageSize
        resourceFilter.offset = totalResources

        let resourceContent: ResourceFolderContent = try await self.resourceFolders.filteredFolderContent(
          resourceFilter
        )
        newResources = resourceContent.resources
        hasMoreResources = newResources.count >= pageSize
      }

      self.viewState.update { viewState in
        viewState.directFolders.append(
          contentsOf: newFolders.filter { $0.parentFolderID == folderID }
        )
        viewState.nestedFolders.append(
          contentsOf: newFolders.filter { $0.parentFolderID != folderID }
        )
        viewState.directResources.append(
          contentsOf: newResources.filter { $0.parentFolderID == folderID }
        )
        viewState.nestedResources.append(
          contentsOf: newResources.filter { $0.parentFolderID != folderID }
        )
        viewState.hasMoreFolders = hasMoreFolders
        viewState.hasMoreData = hasMoreFolders || hasMoreResources
        viewState.isLoadingMore = false
      }
    }
    catch {
      error.consume(context: "Failed to load more folder content.")
      self.viewState.update { state in
        state.isLoadingMore = false
      }
    }
  }
}
