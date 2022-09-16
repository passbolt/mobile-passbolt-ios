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
internal struct TagsExplorerView: ComponentView {

  @ObservedObject private var state: ObservableValue<ViewState>
  private let controller: TagsExplorerController

  internal init(
    state: ObservableValue<ViewState>,
    controller: TagsExplorerController
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

      self.contentView
    }
    .backgroundColor(.passboltBackground)
    .snackBarMessage(presenting: self.$state.snackBarMessage)
  }

  @ViewBuilder private var titleView: some View {
    HStack(alignment: .center, spacing: 0) {
      Image(named: .tag)
        .resizable()
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
            self.controller.presentResourceCreationFrom()
          }
        }  // else { /* NOP */ }

        if self.state.resourceTagID != nil, !self.state.resources.isEmpty {
          self.resourcesListContent
        }
        else if self.state.resourceTagID == nil, !self.state.tags.isEmpty {
          self.tagsListContent
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

  @ViewBuilder private var tagsListContent: some View {
    Section {
      ForEach(
        self.state.tags,
        id: \ResourceTagListItemDSV.id
      ) { listTag in
        ResourceTagListItemView(
          name: listTag.slug.rawValue,
          shared: listTag.shared,
          contentCount: listTag.contentCount,
          action: {
            self.controller
              .presentTagContent(
                .init(
                  id: listTag.id,
                  slug: listTag.slug,
                  shared: listTag.shared
                )
              )
          }
        )
      }
    }
    .listSectionSeparator(.hidden)
    .backgroundColor(.passboltBackground)
  }

  @ViewBuilder private var resourcesListContent: some View {
    Section {
      ForEach(
        self.state.resources,
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

extension TagsExplorerView {

  internal struct ViewState {

    internal var title: DisplayableString
    internal var resourceTagID: ResourceTag.ID?
    internal var canCreateResources: Bool
    internal var userAvatarImage: Data? = .none
    internal var searchText: String = ""
    internal var tags: Array<ResourceTagListItemDSV> = .init()
    internal var resources: Array<ResourceListItemDSV> = .init()
    internal var snackBarMessage: SnackBarMessage? = .none
  }
}

extension TagsExplorerView.ViewState: Hashable {}
