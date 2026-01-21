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
      titleTrailingItem: {
        IconButton(iconName: .more, action: self.controller.presentResourceFolderMenu)
      },
      contentView: {
        if state.searchText.isEmpty {
          self.contentView(with: state)
        }
        else {
          self.searchContentView(with: state)
        }
      }
    )
    .environment(\.isInNavigationTreeContext, state.folderID != .none)
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
        if state.canCreateResources {
          ResourceListAddView {
            await self.controller.presentAddNew(folderID: state.folderID)
          }
          .accessibilityIdentifier("folder.explore.create.new")
        }  // else { /* NOP */ }

        if state.directFolders.isEmpty,
          state.directResources.isEmpty,
          state.nestedFolders.isEmpty,
          state.nestedResources.isEmpty
        {
          EmptyListView()
        }
        else {
          self.directListContent(with: state)
        }
      }
    )
    .listStyle(.plain)
    .environment(\.defaultMinListRowHeight, 20)
    .refreshable {
      await self.controller.refreshIfNeeded()
    }
  }

  @ViewBuilder private func searchContentView(with state: ViewState) -> some View {
    List(
      content: {
        if state.directFolders.isEmpty,
          state.directResources.isEmpty,
          state.nestedFolders.isEmpty,
          state.nestedResources.isEmpty
        {
          EmptyListView()
        }
        else {
          if !state.directFolders.isEmpty
            || !state.directResources.isEmpty
          {
            Text(
              displayable: .localized(
                key: "home.presentation.mode.folders.explorer.search.direct.results"
              ),
              arguments: state.title.string()
            )
            .text(
              font: .inter(
                ofSize: 14,
                weight: .semibold
              ),
              color: .passboltPrimaryText
            )
            .frame(maxWidth: .infinity)
            .padding(
              leading: 16,
              trailing: 16
            )
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets())
            .buttonStyle(.plain)
            .frame(height: 24)

            self.directListContent(with: state)

            if !state.nestedFolders.isEmpty
              || !state.nestedResources.isEmpty
            {
              ListDividerView()
                .padding(
                  leading: 16,
                  trailing: 16
                )
            }  // else { /* NOP */ }
          }  // else { /* NOP */ }

          if !state.nestedFolders.isEmpty
            || !state.nestedResources.isEmpty
          {
            Text(
              displayable: .localized(
                key: "home.presentation.mode.folders.explorer.search.nested.results"
              )
            )
            .text(
              font: .inter(
                ofSize: 14,
                weight: .semibold
              ),
              color: .passboltPrimaryText
            )
            .frame(maxWidth: .infinity)
            .padding(
              leading: 16,
              trailing: 16
            )
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets())
            .buttonStyle(.plain)
            .frame(height: 24)

            self.nestedListContent(with: state)
          }  // else { /* NOP */ }
        }
      }
    )
    .listStyle(.plain)
    .environment(\.defaultMinListRowHeight, 20)
  }

  @ViewBuilder private func directListContent(with state: ViewState) -> some View {
    Section {
      ForEach(
        state.directFolders,
        id: \ResourceFolderListItemDSV.id
      ) { folder in
        ResourceFolderListItemView(
          name: folder.name,
          shared: folder.shared,
          contentCount: folder.contentCount,
          locationString: folder.location,
          action: {
            await self.controller.presentFolderContent(folder)
          }
        )
      }
    }
    .listSectionSeparator(.hidden)
    .backgroundColor(.passboltBackground)

    Section {
      ForEach(
        state.directResources,
        id: \ResourceListItemDSV.id
      ) { (resource: ResourceListItemDSV) in
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
              .padding(8)
              .frame(width: 44)
          }
        )
      }
    }
    .listSectionSeparator(.hidden)
    .backgroundColor(.passboltBackground)
  }

  @ViewBuilder private func nestedListContent(with state: ViewState) -> some View {
    Section {
      ForEach(
        state.nestedFolders,
        id: \ResourceFolderListItemDSV.id
      ) { folder in
        ResourceFolderListItemView(
          name: folder.name,
          shared: folder.shared,
          contentCount: folder.contentCount,
          locationString: folder.location,
          action: {
            await self.controller.presentFolderContent(folder)
          }
        )
      }
    }
    .listSectionSeparator(.hidden)
    .backgroundColor(.passboltBackground)

    Section {
      ForEach(
        state.nestedResources,
        id: \ResourceListItemDSV.id
      ) { (resource: ResourceListItemDSV) in
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
              .padding(8)
              .frame(width: 44)
          }
        )
      }
    }
    .listSectionSeparator(.hidden)
    .backgroundColor(.passboltBackground)
  }
}
