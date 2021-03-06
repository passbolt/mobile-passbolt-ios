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

import Accounts
import UIComponents

@MainActor
internal struct FoldersExplorerView: ComponentView {

  @ObservedObject private var state: ObservableValue<ViewState>
  private let controller: FoldersExplorerController

  internal init(
    state: ObservableValue<ViewState>,
    controller: FoldersExplorerController
  ) {
    self.state = state
    self.controller = controller
  }

  internal var body: some View {
    VStack(spacing: 0) {
      ZStack(alignment: .top) {
        Rectangle()
          .fill(Color.passboltBackground)
          .shadow(
            color: .black.opacity(0.2),
            radius: 12,
            x: 0,
            y: -10
          )
          .ignoresSafeArea(.all, edges: .top)
        VStack(spacing: 0) {
          self.titleView
          self.searchView
        }
        .padding(top: -42)
      }
      .fixedSize(horizontal: false, vertical: true)
      .zIndex(1)

      if self.state.searchText.isEmpty {
        self.contentView
      }
      else {
        self.searchContentView
      }
    }
    .background(Color.passboltBackground)
    .snackBarMessage(presenting: self.$state.snackBarMessage)
  }

  @ViewBuilder private var titleView: some View {
    HStack(alignment: .center, spacing: 0) {
      Image(
        named: self.state.folderShared
          ? .sharedFolder
          : .folder
      )
      .aspectRatio(1, contentMode: .fit)
      .frame(width: 24)
      .padding(trailing: 16)
      Text(displayable: self.state.title)
        .font(.inter(ofSize: 16, weight: .semibold))

    }
    .foregroundColor(.passboltPrimaryText)
    .frame(height: 40)
    .padding(
      leading: 32,
      trailing: 32
    )
  }

  @ViewBuilder private var searchView: some View {
    SearchView(
      prompt: .localized(key: "resources.search.placeholder"),
      text: self.state.scope(\.searchText),
      leftAccessory: {
        AsyncButton(
          action: {
            await self.controller.presentHomePresentationMenu()
          },
          label: {
            ImageWithPadding(4, named: .filter)
          }
        )
        .contentShape(Rectangle())
      },
      rightAccessory: {
        AsyncButton(
          action: {
            await self.controller.presentAccountMenu()
          },
          label: {
            UserAvatarView(image: self.state.userAvatarImage)
              .padding(
                top: 0,
                leading: 0,
                bottom: 0,
                trailing: 6
              )
          }
        )
        .contentShape(Rectangle())
      }
    )
    .padding(
      top: 10,
      leading: 16,
      bottom: 16,
      trailing: 16
    )
  }

  @ViewBuilder private var contentView: some View {
    Backport.RefreshableList(
      refresh: {
        await self.controller.refreshIfNeeded()
      },
      listContent: {
        if self.state.canCreateResources {
          ResourceListAddView {
            self.controller.presentResourceCreationFrom(self.state.folderID)
          }
          .backport.hiddenRowSeparators()
        }  // else { /* NOP */ }

        if self.state.directFolders.isEmpty,
          self.state.directResources.isEmpty,
          self.state.nestedFolders.isEmpty,
          self.state.nestedResources.isEmpty
        {
          EmptyListView()
            .backport.hiddenRowSeparators()
        }
        else {
          self.directListContent
        }
      }
    )
  }

  @ViewBuilder private var searchContentView: some View {
    Backport.List(
      listContent: {
        if self.state.directFolders.isEmpty,
          self.state.directResources.isEmpty,
          self.state.nestedFolders.isEmpty,
          self.state.nestedResources.isEmpty
        {
          EmptyListView()
            .backport.hiddenRowSeparators()
        }
        else {
          if !self.state.directFolders.isEmpty
            || !self.state.directResources.isEmpty
          {
            Text(
              displayable: .localized(
                key: "home.presentation.mode.folders.explorer.search.direct.results"
              ),
              arguments: self.state.title.string()
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
            .backport.hiddenRowSeparators()
            .frame(height: 24)

            self.directListContent

            if !self.state.nestedFolders.isEmpty
              || !self.state.nestedResources.isEmpty
            {
              ListDividerView()
                .padding(
                  leading: 16,
                  trailing: 16
                )
                .backport.hiddenRowSeparators()
            }  // else { /* NOP */ }
          }  // else { /* NOP */ }

          if !self.state.nestedFolders.isEmpty
            || !self.state.nestedResources.isEmpty
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
            .backport.hiddenRowSeparators()
            .frame(height: 24)

            self.nestedListContent
          }  // else { /* NOP */ }
        }
      }
    )
  }

  @ViewBuilder private var directListContent: some View {
    ForEach(
      self.state.directFolders,
      id: \ListViewFolder.id
    ) { folder in
      FolderListItemView(
        name: folder.name,
        shared: folder.shared,
        contentCount: folder.contentCount,
        action: {
          self.controller.presentFolderContent(folder)
        }
      )
      .backport.hiddenRowSeparators()
    }
    .backport.hiddenSectionSeparators()
    ForEach(
      self.state.directResources,
      id: \ListViewFolderResource.id
    ) { resource in
      ResourceListItemView(
        name: resource.name,
        username: resource.username,
        action: {
          self.controller.presentResourceDetails(resource.id)
        },
        accessory: {
          AsyncButton(
            action: {
              await self.controller.presentResourceMenu(resource.id)
            },
            label: {
              Image(named: .more)
                .aspectRatio(1, contentMode: .fit)
                .padding(8)
                .foregroundColor(Color.passboltIcon)
                .cornerRadius(8)
            }
          )
          .contentShape(Rectangle())
        }
      )
      .backport.hiddenRowSeparators()
    }
    .backport.hiddenSectionSeparators()
  }

  @ViewBuilder private var nestedListContent: some View {
    ForEach(
      self.state.nestedFolders,
      id: \ListViewFolder.id
    ) { folder in
      FolderListItemView(
        name: folder.name,
        shared: folder.shared,
        contentCount: folder.contentCount,
        action: {
          self.controller.presentFolderContent(folder)
        }
      )
      .backport.hiddenRowSeparators()
    }
    .backport.hiddenSectionSeparators()
    ForEach(
      self.state.nestedResources,
      id: \ListViewFolderResource.id
    ) { resource in
      ResourceListItemView(
        name: resource.name,
        username: resource.username,
        action: {
          self.controller.presentResourceDetails(resource.id)
        },
        accessory: {
          AsyncButton(
            action: {
              await self.controller.presentResourceMenu(resource.id)
            },
            label: {
              Image(named: .more)
                .aspectRatio(1, contentMode: .fit)
                .padding(8)
                .foregroundColor(Color.passboltIcon)
                .cornerRadius(8)
            }
          )
          .contentShape(Rectangle())
        }
      )
      .backport.hiddenRowSeparators()
    }
    .backport.hiddenSectionSeparators()
  }
}

extension FoldersExplorerView {

  internal struct ViewState {

    internal var title: DisplayableString
    internal var folderID: Folder.ID?
    internal var folderShared: Bool
    internal var canCreateResources: Bool
    internal var userAvatarImage: Data? = .none
    internal var searchText: String = ""
    internal var directFolders: Array<ListViewFolder> = .init()
    internal var nestedFolders: Array<ListViewFolder> = .init()
    internal var directResources: Array<ListViewFolderResource> = .init()
    internal var nestedResources: Array<ListViewFolderResource> = .init()
    internal var snackBarMessage: SnackBarMessage? = .none
  }
}

extension FoldersExplorerView.ViewState: Hashable {}
