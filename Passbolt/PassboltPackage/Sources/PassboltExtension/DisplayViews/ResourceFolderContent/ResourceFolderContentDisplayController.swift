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

  internal var createFolder: (() -> Void)?
  internal var createResource: (() -> Void)?
  internal var selectFolder: (ResourceFolder.ID) -> Void
  internal var selectResource: (Resource.ID) -> Void
  internal var openResourceMenu: ((Resource.ID) -> Void)?

  private let asyncExecutor: AsyncExecutor
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

    self.asyncExecutor = try features.instance()
    self.sessionData = try features.instance()
    self.resourceFolders = try features.instance()

    self.viewState = .init(
      initial: .init(
        folderName: context.folderName,
        isSearchResult: false,
        directFolders: .init(),
        nestedFolders: .init(),
        suggestedResources: .init(),
        directResources: .init(),
        nestedResources: .init()
      )
    )

    self.createFolder = context.createFolder
    self.createResource = context.createResource
    self.selectFolder = context.selectFolder
    self.selectResource = context.selectResource
    self.openResourceMenu = context.openResourceMenu

    self.asyncExecutor.scheduleIteration(
      over: combineLatest(context.filter.asAnyAsyncSequence(), sessionData.lastUpdate.asAnyAsyncSequence()),
      failMessage: "Resource folders list updates broken!",
      failAction: { [context] (error: Error) in
        context.showMessage(.error(error))
      }
    ) { [viewState, resourceFolders] (filter: ResourceFoldersFilter, _) in
      let filteredResourceFolderContent: ResourceFolderContent = try await resourceFolders.filteredFolderContent(filter)

      await viewState.update { (viewState: inout ViewState) in
        viewState.isSearchResult = !filter.text.isEmpty
        viewState.suggestedResources = filteredResourceFolderContent.resources.filter(self.context.suggestionFilter)
        viewState.directFolders = filteredResourceFolderContent.subfolders
          .filter { $0.parentFolderID == filter.folderID }
        viewState.nestedFolders = filteredResourceFolderContent.subfolders
          .filter { $0.parentFolderID != filter.folderID }
        viewState.directResources = filteredResourceFolderContent.resources
          .filter { $0.parentFolderID == filter.folderID }
        viewState.nestedResources = filteredResourceFolderContent.resources
          .filter { $0.parentFolderID != filter.folderID }
      }
    }
  }
}

extension ResourceFolderContentDisplayController {

  internal struct Context {

    internal var folderName: DisplayableString
    internal var filter: AnyAsyncSequence<ResourceFoldersFilter>
    internal var suggestionFilter: (ResourceListItemDSV) -> Bool
    internal var createFolder: (() -> Void)?
    internal var createResource: (() -> Void)?
    internal var selectFolder: (ResourceFolder.ID) -> Void
    internal var selectResource: (Resource.ID) -> Void
    internal var openResourceMenu: ((Resource.ID) -> Void)?
    internal var showMessage: (SnackBarMessage?) -> Void
  }

  internal struct ViewState: Equatable {

    internal var folderName: DisplayableString
    internal var isSearchResult: Bool
    internal var directFolders: Array<ResourceFolderListItemDSV>
    internal var nestedFolders: Array<ResourceFolderListItemDSV>
    internal var suggestedResources: Array<ResourceListItemDSV>
    internal var directResources: Array<ResourceListItemDSV>
    internal var nestedResources: Array<ResourceListItemDSV>
  }
}

extension ResourceFolderContentDisplayController {

  internal final func refresh() async {
    do {
      try await self.sessionData.refreshIfNeeded()
    }
    catch {
      Diagnostics.log(
        error: error,
        info: .message(
          "Failed to refresh session data."
        )
      )
      self.context.showMessage(.error(error))
    }
  }
}
