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

  public static func legacyNavigaitionBarButtonBridge(
    using controller: FoldersExplorerController
  ) -> LegacyNavigationBarButtonBridge? {
    if case .some = controller.viewState.value.folderID {
      return .init(
        icon: .more,
        action: controller.presentResourceFolderMenu
      )
    }
    else {
      return .none
    }
  }

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
        // hide under navigation bar
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
    .backgroundColor(.passboltBackground)
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
      text: self.$state.searchText,
      leftAccessory: {
        AsyncButton(
          action: {
            await self.controller.presentHomePresentationMenu()
          },
          label: {
            ImageWithPadding(4, named: .filter)
          }
        )
      },
      rightAccessory: {
        AsyncButton(
          action: {
            await self.controller.presentAccountMenu()
          },
          label: {
            UserAvatarView(imageData: self.state.userAvatarImage)
              .padding(
                top: 0,
                leading: 0,
                bottom: 0,
                trailing: 6
              )
          }
        )
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
    List(
      content: {
        if self.state.canCreateResources {
          ResourceListAddView {
            self.controller.presentAddNew(self.state.folderID)
          }
        }  // else { /* NOP */ }

        if self.state.directFolders.isEmpty,
          self.state.directResources.isEmpty,
          self.state.nestedFolders.isEmpty,
          self.state.nestedResources.isEmpty
        {
          EmptyListView()
        }
        else {
          self.directListContent
        }
      }
    )
    .listStyle(.plain)
    .environment(\.defaultMinListRowHeight, 20)
    .refreshable {
      await self.controller.refreshIfNeeded()
    }
  }

  @ViewBuilder private var searchContentView: some View {
    List(
      content: {
        if self.state.directFolders.isEmpty,
          self.state.directResources.isEmpty,
          self.state.nestedFolders.isEmpty,
          self.state.nestedResources.isEmpty
        {
          EmptyListView()
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
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets())
            .buttonStyle(.plain)
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
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets())
            .buttonStyle(.plain)
            .frame(height: 24)

            self.nestedListContent
          }  // else { /* NOP */ }
        }
      }
    )
    .listStyle(.plain)
    .environment(\.defaultMinListRowHeight, 20)
  }

  @ViewBuilder private var directListContent: some View {
    Section {
      ForEach(
        self.state.directFolders,
        id: \ResourceFolderListItemDSV.id
      ) { folder in
        ResourceFolderListItemView(
          name: folder.name,
          shared: folder.shared,
          contentCount: folder.contentCount,
          locationString: folder.location,
          action: {
            self.controller.presentFolderContent(folder)
          }
        )
      }
    }
    .listSectionSeparator(.hidden)
    .backgroundColor(.passboltBackground)

    Section {
      ForEach(
        self.state.directResources,
        id: \ResourceListItemDSV.id
      ) { resource in
        ResourceListItemView(
          name: resource.name,
          username: resource.username,
          contentAction: {
            self.controller.presentResourceDetails(resource.id)
          },
          rightAction: {
            self.controller.presentResourceMenu(resource.id)
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

  @ViewBuilder private var nestedListContent: some View {
    Section {
      ForEach(
        self.state.nestedFolders,
        id: \ResourceFolderListItemDSV.id
      ) { folder in
        ResourceFolderListItemView(
          name: folder.name,
          shared: folder.shared,
          contentCount: folder.contentCount,
          locationString: folder.location,
          action: {
            self.controller.presentFolderContent(folder)
          }
        )
      }
    }
    .listSectionSeparator(.hidden)
    .backgroundColor(.passboltBackground)

    Section {
      ForEach(
        self.state.nestedResources,
        id: \ResourceListItemDSV.id
      ) { resource in
        ResourceListItemView(
          name: resource.name,
          username: resource.username,
          contentAction: {
            self.controller.presentResourceDetails(resource.id)
          },
          rightAction: {
            self.controller.presentResourceMenu(resource.id)
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

extension FoldersExplorerView {

  internal struct ViewState {

    internal var title: DisplayableString
    internal var folderID: ResourceFolder.ID?
    internal var folderShared: Bool
    internal var canCreateResources: Bool
    internal var userAvatarImage: Data? = .none
    internal var searchText: String = ""
    internal var directFolders: Array<ResourceFolderListItemDSV> = .init()
    internal var nestedFolders: Array<ResourceFolderListItemDSV> = .init()
    internal var directResources: Array<ResourceListItemDSV> = .init()
    internal var nestedResources: Array<ResourceListItemDSV> = .init()
    internal var snackBarMessage: SnackBarMessage? = .none
  }
}

extension FoldersExplorerView.ViewState: Hashable {}
