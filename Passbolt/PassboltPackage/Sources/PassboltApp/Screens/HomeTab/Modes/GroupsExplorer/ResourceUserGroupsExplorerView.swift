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

internal struct ResourceUserGroupsExplorerView: ControlledView {

  internal let controller: ResourceUserGroupsExplorerViewContorller

  internal init(controller: ResourceUserGroupsExplorerViewContorller) {
    self.controller = controller
  }

  internal var body: some View {
    WithViewState(from: self.controller) { state in
      self.bodyView(with: state)
    }
  }

  @MainActor @ViewBuilder private func bodyView(
    with state: ViewState
  ) -> some View {
    ScreenView(
      titleIcon: .userGroup,
      title: state.title,
      titleExtensionView: {
        self.searchView(with: state)
      },
      titleLeadingItem: EmptyView.init,
      titleTrailingItem: EmptyView.init,
      contentView: {
        self.contentView(with: state)
      }
    )
    .environment(\.hideLeadingItem, state.groupID == .none)
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
    if state.groupID != nil, !state.resources.isEmpty {
      self.resourcesListContent(with: state)
    }
    else if state.groupID == nil, !state.groups.isEmpty {
      self.resourcesUserGroupsListContent(with: state)
    }
    else {
      List {
        EmptyListView()
      }
      .listStyle(.plain)
      .environment(\.defaultMinListRowHeight, 20)
      .refreshable {
        await self.controller.refreshIfNeeded()
      }
    }
  }

  @ViewBuilder private func resourcesUserGroupsListContent(with state: ViewState) -> some View {
    UICommons.ResourceUserGroupsListView(
      userGroups: state.groups,
      hasMoreData: state.hasMoreData,
      isLoadingMore: state.isLoadingMore,
      contentResetToken: state.contentResetToken,
      refreshAction: self.controller.refreshIfNeeded,
      loadMoreAction: self.controller.loadMore,
      createAction: .none,
      groupTapAction: { groupID in
        // Find the group item and navigate
        if let group: ResourceUserGroupListItemDSV = state.groups.first(where: { $0.id == groupID }) {
          await self.controller.presentGroupContent(group)
        }
      }
    )
  }

  @ViewBuilder private func resourcesListContent(with state: ViewState) -> some View {
    UICommons.ResourcesListView(
      suggestedResources: .none,
      resources: .constant(state.resources),
      hasMoreData: state.hasMoreData,
      isLoadingMore: state.isLoadingMore,
      contentResetToken: state.contentResetToken,
      refreshAction: self.controller.refreshIfNeeded,
      loadMoreAction: self.controller.loadMore,
      createAction: .none,
      resourceTapAction: { resourceID in
        await self.controller.presentResourceDetails(resourceID)
      },
      resourceMenuAction: { resourceID in
        await self.controller.presentResourceMenu(resourceID)
      }
    )
  }
}
