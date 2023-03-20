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
import OSFeatures
import Resources
import SessionData

// MARK: - Interface

internal struct ResourceFolderContentDisplayController {

  internal var viewState: MutableViewState<ViewState>
  internal var activate: @Sendable () async -> Void
  internal var refresh: @Sendable () async -> Void
  internal var create: (() -> Void)?
  internal var selectFolder: (ResourceFolder.ID) -> Void
  internal var selectResource: (Resource.ID) -> Void
  internal var openResourceMenu: ((Resource.ID) -> Void)?
}

extension ResourceFolderContentDisplayController: ViewController {

  internal struct Context {

    internal var folderName: DisplayableString
    internal var filter: ObservableViewState<ResourceFoldersFilter>
    internal var suggestionFilter: (ResourceListItemDSV) -> Bool
    internal var createFolder: (() -> Void)?
    internal var createResource: (() -> Void)?
    internal var selectFolder: (ResourceFolder.ID) -> Void
    internal var selectResource: (Resource.ID) -> Void
    internal var openResourceMenu: ((Resource.ID) -> Void)?
    internal var showMessage: (SnackBarMessage?) -> Void
  }

  internal struct ViewState: Hashable {

    internal var folderName: DisplayableString
    internal var isSearchResult: Bool
    internal var directFolders: Array<ResourceFolderListItemDSV>
    internal var nestedFolders: Array<ResourceFolderListItemDSV>
    internal var suggestedResources: Array<ResourceListItemDSV>
    internal var directResources: Array<ResourceListItemDSV>
    internal var nestedResources: Array<ResourceListItemDSV>
  }

  #if DEBUG
  nonisolated static var placeholder: Self {
    .init(
      viewState: .placeholder(),
      activate: { unimplemented() },
      refresh: { unimplemented() },
      create: { unimplemented() },
      selectFolder: { _ in unimplemented() },
      selectResource: { _ in unimplemented() },
      openResourceMenu: { _ in unimplemented() }
    )
  }
  #endif
}

// MARK: - Implementation

extension ResourceFolderContentDisplayController {

  @MainActor fileprivate static func load(
    features: Features,
    context: Context
  ) throws -> Self {
    try features.ensureScope(SessionScope.self)

    let diagnostics: OSDiagnostics = features.instance()
    let asyncExecutor: AsyncExecutor = try features.instance()
    let sessionData: SessionData = try features.instance()
    let resourceFolders: ResourceFolders = try features.instance()

    let viewState: MutableViewState<ViewState> = .init(
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

    context
      .filter
      .valuesPublisher()
      .sink { (filter: ResourceFoldersFilter) in
        updateDisplayedItems(filter)
      }
      .store(in: viewState.cancellables)

    @Sendable nonisolated func activate() async {
      await sessionData
        .updatesSequence
        .forEach {
          await updateDisplayedItems(
            context.filter.value
          )
        }
    }

    @Sendable nonisolated func refresh() async {
      do {
        try await sessionData.refreshIfNeeded()
      }
      catch {
        diagnostics.log(
          error: error,
          info: .message(
            "Failed to refresh session data."
          )
        )
        context.showMessage(.error(error))
      }
    }

    @Sendable nonisolated func updateDisplayedItems(
      _ filter: ResourceFoldersFilter
    ) {
      asyncExecutor.schedule(.replace) {
        do {
          try Task.checkCancellation()

          let filteredResourceFolderContent: ResourceFolderContent =
            try await resourceFolders.filteredFolderContent(filter)

          try Task.checkCancellation()

          await viewState.update { (viewState: inout ViewState) in
            viewState.isSearchResult = !filter.text.isEmpty
            viewState.suggestedResources = filteredResourceFolderContent.resources.filter(context.suggestionFilter)
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
        catch {
          diagnostics.log(
            error: error,
            info: .message(
              "Failed to access resources list."
            )
          )
          context.showMessage(.error(error))
        }
      }
    }

    return .init(
      viewState: viewState,
      activate: activate,
      refresh: refresh,
      create: context.createResource,
      selectFolder: context.selectFolder,
      selectResource: context.selectResource,
      openResourceMenu: context.openResourceMenu
    )
  }
}

extension FeaturesRegistry {

  public mutating func usePassboltResourceFolderContentDisplayController() {
    self.use(
      .disposable(
        ResourceFolderContentDisplayController.self,
        load: ResourceFolderContentDisplayController.load(features:context:)
      ),
      in: SessionScope.self
    )
  }
}
