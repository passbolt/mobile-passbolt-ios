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
  }

  internal nonisolated let viewState: ViewStateSource<ViewState>

  internal let searchController: ResourceSearchDisplayController
  internal let features: Features
  internal let sessionData: SessionData

  fileprivate let navigationToResourceDetails: NavigationToResourceDetails
  fileprivate let navigationToFolderContent: NavigationToFolderContent
  fileprivate let navigationToResouceCreateMenu: NavigationToResourceCreateMenu
  fileprivate let navigationToFolderMenu: NavigationToResourceFolderMenu

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
    let folders: ResourceFolders = try features.instance()

    self.viewState = .init(
      initial: context.initialState,
      updateFrom: ComputedVariable(
        combined: sessionData.lastUpdate,
        with: searchController.searchText
      ),
      update: { updateState, updates in
        let searchText: String = try updates.value.1

        let filter: ResourceFoldersFilter = .init(
          sorting: .nameAlphabetically,
          text: searchText,
          folderID: context?.id,
          flattenContent: !searchText.isEmpty,
          permissions: .init()
        )

        let folders: ResourceFolderContent = try await folders.filteredFolderContent(filter)

        updateState { viewState in
          viewState.searchText = searchText
          viewState.directFolders = folders
            .subfolders
            .filter { $0.parentFolderID == context?.id }
          viewState.nestedFolders = folders
            .subfolders
            .filter { $0.parentFolderID != context?.id }
          viewState.directResources = folders
            .resources
            .filter { $0.parentFolderID == context?.id }
          viewState.nestedResources = folders
            .resources
            .filter { $0.parentFolderID != context?.id }
        }
      }
    )
  }
}

extension FoldersExplorerViewController {

  internal func refreshIfNeeded() async {
    await consumingErrors {
      try await sessionData.refreshIfNeeded()
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
      let resourceCreatePreparation: ResourceCreatePreparation = try features.instance()
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
        try features
        .branchIfNeeded(
          scope: ResourceScope.self,
          context: resourceID
        )

      let navigationToResourceContextualMenu: NavigationToResourceContextualMenu = try features.instance()
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
