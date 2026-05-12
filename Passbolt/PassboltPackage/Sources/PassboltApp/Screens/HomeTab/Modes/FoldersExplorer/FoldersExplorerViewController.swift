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

import Commons
import Display
import Resources
import SessionData
import SharedUIComponents

internal final class FoldersExplorerViewController: ViewController {

  internal typealias Context = ResourceFolderListItemDSV?

  internal struct ViewState: Equatable {
    internal var title: DisplayableString
    internal var folderID: ResourceFolder.ID?
    internal var folderShared: Bool
    internal var canCreateResources: Bool
    internal var searchText: String = ""
    internal var directFolders: Array<ResourceFolderListItemDSV> = .init()
    internal var nestedFolders: Array<ResourceFolderListItemDSV> = .init()
    internal var directResources: Array<ResourceListItemDSV> = .init()
    internal var nestedResources: Array<ResourceListItemDSV> = .init()
    internal var isLoadingMore: Bool = false
    internal var hasMoreFolders: Bool = true
    internal var hasMoreData: Bool = true
    internal var contentResetToken: Int = 0
  }

  internal nonisolated let viewState: ViewStateSource<ViewState>
  internal nonisolated let refreshIndicatorSource: AnyUpdatable<Bool>

  internal let searchController: ResourceSearchDisplayController
  internal let features: Features
  internal let sessionData: SessionData

  fileprivate let navigationToResourceDetails: NavigationToResourceDetails
  fileprivate let navigationToFolderContent: NavigationToFolderContent
  fileprivate let navigationToResouceCreateMenu: NavigationToResourceCreateMenu
  fileprivate let navigationToFolderMenu: NavigationToResourceFolderMenu

  private let folders: ResourceFolders
  private let pageSize: Int = 50

  internal let context: Context

  init(context: Context, features: Features) throws {
    self.features = features
    self.context = context

    self.navigationToResourceDetails = try features.instance()
    self.navigationToFolderContent = try features.instance()
    self.navigationToResouceCreateMenu = try features.instance()
    self.navigationToFolderMenu = try features.instance()

    let navigationToAccountMenu: NavigationToAccountMenu = try features.instance()
    let navigationToHomePresentationMenu: NavigationToHomePresentationMenu = try features.instance()

    self.searchController = try features.instance(
      context: .init(
        searchPrompt: .localized(key: "resources.search.placeholder"),
        onPresentationMenuTap: {
          await consumingErrors {
            try await navigationToHomePresentationMenu.perform()
          }
        },
        onAvatarTap: {
          await consumingErrors {
            try await navigationToAccountMenu.perform()
          }
        }
      )
    )

    self.sessionData = try features.instance()
    self.refreshIndicatorSource = self.sessionData.isRefreshing
    let folders: ResourceFolders = try features.instance()
    self.folders = folders

    let pageSize: Int = self.pageSize

    self.viewState = .init(
      initial: context.initialState,
      updateFrom: ComputedVariable(
        combined: sessionData.lastUpdate,
        with: searchController.searchText
      ),
      update: { updateState, updates in
        let searchText: String = try updates.value.1

        // fetch folders first
        let folderFilter: ResourceFoldersFilter = .init(
          sorting: .nameAlphabetically,
          text: searchText,
          folderID: context?.id,
          flattenContent: !searchText.isEmpty,
          permissions: .init(),
          limit: pageSize,
          offset: 0
        )

        let folderContent: ResourceFolderContent = try await folders.filteredFolderContent(folderFilter)
        let fetchedFolders: Array<ResourceFolderListItemDSV> = folderContent.subfolders
        let hasMoreFolders: Bool = fetchedFolders.count >= pageSize

        // fill remaining page slots with resources
        var fetchedResources: Array<ResourceListItemDSV> = .init()
        var hasMoreResources: Bool = false
        if !hasMoreFolders {
          let remaining: Int = pageSize - fetchedFolders.count
          if remaining > 0 {
            let resourceFilter: ResourceFoldersFilter = .init(
              sorting: .nameAlphabetically,
              text: searchText,
              folderID: context?.id,
              flattenContent: !searchText.isEmpty,
              permissions: .init(),
              limit: remaining,
              offset: 0
            )
            let resourceContent: ResourceFolderContent = try await folders.filteredFolderContent(resourceFilter)
            fetchedResources = resourceContent.resources
            hasMoreResources = fetchedResources.count >= remaining
          }
        }

        updateState { viewState in
          viewState.searchText = searchText
          viewState.directFolders =
            fetchedFolders
            .filter { $0.parentFolderID == context?.id }
          viewState.nestedFolders =
            fetchedFolders
            .filter { $0.parentFolderID != context?.id }
          viewState.directResources =
            fetchedResources
            .filter { $0.parentFolderID == context?.id }
          viewState.nestedResources =
            fetchedResources
            .filter { $0.parentFolderID != context?.id }
          viewState.hasMoreFolders = hasMoreFolders
          viewState.hasMoreData = hasMoreFolders || hasMoreResources
          viewState.isLoadingMore = false
          if viewState.searchText != searchText {
            viewState.contentResetToken += 1
          }
        }
      }
    )
  }
}

extension FoldersExplorerViewController {

  @Sendable
  internal func refreshIfNeeded() async {
    await consumingErrors {
      try await sessionData.refreshIfNeeded()
    }
  }

  @Sendable
  @MainActor internal func loadMore() async {
    let currentState: ViewState = await viewState.current

    guard currentState.hasMoreData, !currentState.isLoadingMore else { return }

    self.viewState.update { state in
      state.isLoadingMore = true
    }

    do {
      let totalFolders: Int = currentState.directFolders.count + currentState.nestedFolders.count
      let totalResources: Int = currentState.directResources.count + currentState.nestedResources.count
      let searchText: String = currentState.searchText
      let folderID: ResourceFolder.ID? = context?.id

      var newFolders: Array<ResourceFolderListItemDSV> = .init()
      var newResources: Array<ResourceListItemDSV> = .init()
      var hasMoreFolders: Bool = currentState.hasMoreFolders
      var hasMoreResources: Bool = false

      if hasMoreFolders {
        // try loading more folders
        let folderFilter: ResourceFoldersFilter = .init(
          sorting: .nameAlphabetically,
          text: searchText,
          folderID: folderID,
          flattenContent: !searchText.isEmpty,
          permissions: .init(),
          limit: pageSize,
          offset: totalFolders
        )
        let folderContent: ResourceFolderContent = try await folders.filteredFolderContent(folderFilter)
        newFolders = folderContent.subfolders
        hasMoreFolders = newFolders.count >= pageSize

        // fill remaining page slots with resources
        if !hasMoreFolders {
          let remaining: Int = pageSize - newFolders.count
          if remaining > 0 {
            let resourceFilter: ResourceFoldersFilter = .init(
              sorting: .nameAlphabetically,
              text: searchText,
              folderID: folderID,
              flattenContent: !searchText.isEmpty,
              permissions: .init(),
              limit: remaining,
              offset: totalResources
            )
            let resourceContent: ResourceFolderContent = try await folders.filteredFolderContent(resourceFilter)
            newResources = resourceContent.resources
            hasMoreResources = newResources.count >= remaining
          }
        }
      }
      else {
        // folders exhausted, load only resources
        let resourceFilter: ResourceFoldersFilter = .init(
          sorting: .nameAlphabetically,
          text: searchText,
          folderID: folderID,
          flattenContent: !searchText.isEmpty,
          permissions: .init(),
          limit: pageSize,
          offset: totalResources
        )
        let resourceContent: ResourceFolderContent = try await folders.filteredFolderContent(resourceFilter)
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

  internal func presentFolderContent(_ folder: ResourceFolderListItemDSV) async {
    await consumingErrors {
      try await navigationToFolderContent
        .perform(context: folder)
    }
  }

  internal func presentAddNew(
    folderID: ResourceFolder.ID?
  ) async {
    await consumingErrors {
      let resourceCreatePreparation: ResourceCreatePreparation = try await features.instance()
      let resourceCreatingContext: ResourceCreatingContext = try await resourceCreatePreparation.prepare()
      try await navigationToResouceCreateMenu.perform(
        context: .init(
          resourceCreatingContext: resourceCreatingContext,
          folderID: folderID,
          allowFolderCreation: true
        )
      )
    }
  }

  internal func presentResourceDetails(_ resourceID: Resource.ID) async {
    await consumingErrors {
      try await navigationToResourceDetails
        .perform(context: resourceID)
    }
  }

  internal func presentResourceMenu(_ resourceID: Resource.ID) async {
    await consumingErrors {
      let features: Features =
        try await features
        .branchIfNeeded(
          scope: ResourceScope.self,
          context: resourceID
        )

      let navigationToResourceContextualMenu: NavigationToResourceContextualMenu = try await features.instance()
      try await navigationToResourceContextualMenu.perform(
        context: .init()
      )
    }
  }

  nonisolated func presentResourceFolderMenu() async {
    guard let folderItem: ResourceFolderListItemDSV = context
    else { return assertionFailure("Can't show folder menu for root") }
    do {
      try await navigationToFolderMenu.perform(
        context: .init(
          folderID: folderItem.id,
          folderName: folderItem.name
        )
      )
    }
    catch {
      error.logged()
    }
  }
}

extension FoldersExplorerViewController.Context {

  fileprivate var initialState: FoldersExplorerViewController.ViewState {
    if let folder: ResourceFolderListItemDSV = self {
      return .init(
        title: .raw(folder.name),
        folderID: folder.id,
        folderShared: folder.shared,
        canCreateResources: folder.permission != .read  // write / owned
      )
    }
    else {
      return .init(
        title: .localized(key: "home.presentation.mode.folders.explorer.title"),
        folderShared: false,
        canCreateResources: true
      )
    }
  }
}
