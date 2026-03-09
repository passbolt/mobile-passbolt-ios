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
    List(
      content: {
        if state.groupID != nil, !state.resources.isEmpty {
          self.resourcesListContent(with: state)
        }
        else if state.groupID == nil, !state.groups.isEmpty {
          self.resourcesUserGroupsListContent(with: state)
        }
        else {
          EmptyListView()
        }
      }
    )
    .listStyle(.plain)
    .environment(\.defaultMinListRowHeight, 20)
    .refreshable {
      await self.controller.refreshIfNeeded()
    }
  }

  @ViewBuilder private func resourcesUserGroupsListContent(with state: ViewState) -> some View {
    Section {
      ForEach(
        state.groups,
        id: \ResourceUserGroupListItemDSV.id
      ) { listGroup in
        ResourceUserGroupListItemView(
          name: listGroup.name,
          contentCount: listGroup.contentCount,
          action: {
            await self.controller.presentGroupContent(listGroup)
          }
        )
      }
    }
    .listSectionSeparator(.hidden)
    .backgroundColor(.passboltBackground)
  }

  @ViewBuilder private func resourcesListContent(with state: ViewState) -> some View {
    Section {
      ForEach(
        state.resources,
        id: \ResourceListItemDSV.id
      ) { resource in
        ResourceListItemView(
          name: resource.name,
          username: resource.username,
          isExpired: resource.isExpired,
          icon: resource.icon,
          resourceTypeSlug: resource.typeInfo.typeSlug,
          contentAction: {
            await self.controller.presentResourceDetails(resource.id)
          },
          rightAction: {
            await self.controller.presentResourceMenu(resource.id)
          },
          rightAccessory: {
            Image(named: .more)
              .resizable()
              .aspectRatio(1, contentMode: .fit)
              .foregroundColor(Color.passboltIcon)
              .padding(16)
              .frame(width: 44)
          }
        )
      }
    }
    .listSectionSeparator(.hidden)
    .backgroundColor(.passboltBackground)
  }
}
