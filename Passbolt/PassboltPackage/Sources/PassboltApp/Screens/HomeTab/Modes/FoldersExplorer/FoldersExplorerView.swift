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
import SharedUIComponents

internal struct FoldersExplorerView: ControlledView {

  internal let controller: FoldersExplorerViewController

  internal var body: some View {
    WithViewState(from: self.controller) { state in
      self.bodyView(with: state)
    }
  }

  @MainActor @ViewBuilder private func bodyView(
    with state: ViewState
  ) -> some View {
    ScreenView(
      titleIcon: state.folderShared
        ? .sharedFolder
        : .folder,
      title: state.title,
      titleExtensionView: {
        self.searchView(with: state)
      },
      titleLeadingItem: EmptyView.init,
      titleTrailingItem: { IconButton(iconName: .more, action: { await self.controller.presentResourceFolderMenu() }) },
      contentView: {
        self.contentView(with: state)
      }
    )
    .environment(\.hideTrailingItem, state.folderID == .none)
    .environment(\.hideLeadingItem, state.folderID == .none)
  }

  @MainActor @ViewBuilder private func searchView(
    with state: ViewState
  ) -> some View {
    ResourceSearchDisplayView(
      controller: self.controller.searchController
    )
    .padding(.horizontal, 8)
  }

  @MainActor @ViewBuilder private func contentView(
    with state: ViewState
  ) -> some View {
    ResourceFolderContentView(
      folderName: state.title,
      isSearchResult: !state.searchText.isEmpty,
      directFolders: state.directFolders,
      nestedFolders: state.nestedFolders,
      suggestedResources: .none,
      directResources: state.directResources,
      nestedResources: state.nestedResources,
      hasMoreData: state.hasMoreData,
      isLoadingMore: state.isLoadingMore,
      contentResetToken: state.contentResetToken,
      refreshAction: self.controller.refreshIfNeeded,
      refreshIndicatorSource: self.controller.refreshIndicatorSource,
      loadMoreAction: self.controller.loadMore,
      createAction: state.canCreateResources
        ? { @Sendable in await self.controller.presentAddNew(folderID: state.folderID) }
        : .none,
      folderTapAction: { folderID in
        let folder: ResourceFolderListItemDSV? =
          state.directFolders.first(where: { $0.id == folderID })
          ?? state.nestedFolders.first(where: { $0.id == folderID })
        if let folder: ResourceFolderListItemDSV = folder {
          await self.controller.presentFolderContent(folder)
        }
      },
      resourceTapAction: { resourceID in
        await self.controller.presentResourceDetails(resourceID)
      },
      resourceMenuAction: { resourceID in
        await self.controller.presentResourceMenu(resourceID)
      }
    )
  }
}
