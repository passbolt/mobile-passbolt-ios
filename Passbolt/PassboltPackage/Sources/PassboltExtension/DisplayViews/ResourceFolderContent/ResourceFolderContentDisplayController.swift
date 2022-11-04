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

// MARK: - Interface

internal struct ResourceFolderContentDisplayController {

  @IID internal var id
  internal var viewState: ViewStateBinding<ViewState>
  internal var viewActions: ViewActions
}

extension ResourceFolderContentDisplayController: ViewController {

  internal struct Context: LoadableFeatureContext {
    // feature is disposable, we don't care about ID
    internal let identifier: AnyHashable = IID()

    internal var folderName: DisplayableString
    internal var filter: StateView<ResourceFoldersFilter>
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
    @StateView internal var isSearchResult: Bool
    internal var directFolders: Array<ResourceFolderListItemDSV>
    internal var nestedFolders: Array<ResourceFolderListItemDSV>
    internal var suggestedResources: Array<ResourceListItemDSV>
    internal var directResources: Array<ResourceListItemDSV>
    internal var nestedResources: Array<ResourceListItemDSV>
  }

  internal struct ViewActions: ViewControllerActions {

    internal var activate: @Sendable () async -> Void
    internal var refresh: @Sendable () async -> Void
    internal var create: (() -> Void)?
    internal var selectFolder: (ResourceFolder.ID) -> Void
    internal var selectResource: (Resource.ID) -> Void
    internal var openResourceMenu: ((Resource.ID) -> Void)?

    #if DEBUG
    internal static var placeholder: Self {
      .init(
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

  #if DEBUG
  nonisolated static var placeholder: Self {
    .init(
      viewState: .placeholder,
      viewActions: .placeholder
    )
  }
  #endif
}

// MARK: - Implementation

extension ResourceFolderContentDisplayController {

  @MainActor fileprivate static func load(
    features: FeatureFactory,
    context: Context
  ) async throws -> Self {
    let diagnostics: Diagnostics = features.instance()
    let asyncExecutor: AsyncExecutor = features.instance(of: AsyncExecutor.self).detach()
    let sessionData: SessionData = try await features.instance()
    let resourceFolders: ResourceFolders = try await features.instance()

    let state: StateBinding<ViewState> = .variable(
      initial: .init(
        folderName: context.folderName,
        isSearchResult: context.filter
          .convert { (filter: ResourceFoldersFilter) in
            !filter.text.isEmpty
          },
        directFolders: .init(),
        nestedFolders: .init(),
        suggestedResources: .init(),
        directResources: .init(),
        nestedResources: .init()
      )
    )
    state.bind(\.$isSearchResult)

    let viewState: ViewStateBinding<ViewState> = .init(
      stateSource: state
    )

    context
      .filter
      .sink { (filter: ResourceFoldersFilter) in
        updateDisplayedItems(filter)
      }
      .store(in: viewState.cancellables)

    @Sendable nonisolated func activate() async {
      do {
        try await sessionData
          .updatesSequence
          .forEach {
            updateDisplayedItems(
              context.filter.get()
            )
          }
      }
      catch {
        diagnostics.log(
          error: error,
          info: .message(
            "Resource folder content updates broken!"
          )
        )
        context.showMessage(.error(error))
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

          viewState.mutate { (viewState: inout ViewState) in
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
      viewActions: .init(
        activate: activate,
        refresh: refresh,
        create: context.createResource,
        selectFolder: context.selectFolder,
        selectResource: context.selectResource,
        openResourceMenu: context.openResourceMenu
      )
    )
  }
}

extension FeatureFactory {

  @MainActor public func usePassboltResourceFolderContentDisplayController() {
    self.use(
      .disposable(
        ResourceFolderContentDisplayController.self,
        load: ResourceFolderContentDisplayController.load(features:context:)
      )
    )
  }
}
