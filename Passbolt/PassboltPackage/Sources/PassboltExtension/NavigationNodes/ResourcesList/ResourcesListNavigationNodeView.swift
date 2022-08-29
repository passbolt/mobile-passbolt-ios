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

internal struct ResourcesListNavigationNodeView: NavigationNodeView {

  internal typealias Controller = ResourcesListNavigationNodeController

  private let controller: Controller

  internal init(
    controller: Controller
  ) {
    self.controller = controller
  }

  internal var body: some View {
    WithDisplayViewState(self.controller) { state in
      self.bodyView(with: state)
    }
    .task {
      await self.controller.activate()
    }
  }

  @ViewBuilder private func bodyView(
    with state: ViewState
  ) -> some View {
    ScreenView(
      titleIcon: .list,
      title: state.title,
      titleBarShadow: true,
      snackBarMessage: self.controller.binding(to: \.snackBarMessage),
      titleExtensionView: {
        self.searchView(with: state)
      },
      titleLeadingItem: {
        EmptyView()
      },
      titleTrailingItem: {
        Button(
          action: self.controller.closeExtension,
          label: { Image(named: .close) }
        )
      },
      contentView: {
        self.contentView(with: state)
      }
    )
  }

  @ViewBuilder private func searchView(
    with state: ViewState
  ) -> some View {
    SearchView(
      prompt: .localized(key: "resources.search.placeholder"),
      text: .init(
        get: { state.searchText },
        set: self.controller.updateSearchText
      ),
      leftAccessory: {
        Button(
          action: self.controller.showPresentationMenu,
          label: {
            ImageWithPadding(4, named: .filter)
          }
        )
      },
      rightAccessory: {
        Button(
          action: self.controller.signOut,
          label: {
            UserAvatarView(imageData: state.accountAvatar)
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
      bottom: 16
    )
  }

  @ViewBuilder private func contentView(
    with state: ViewState
  ) -> some View {
    List {
      ResourceListAddView {
        self.controller.createResource()
      }
      if state.resources.isEmpty && state.suggested.isEmpty {
        EmptyListView()
      }
      else {
        ResourceListSectionView(
          title: .localized("autofill.extension.resource.list.section.suggested.title"),
          resources: state.suggested,
          tapAction: { resourceID in
            self.controller.selectResource(resourceID)
          }
        )
        ResourceListSectionView(
          title: .localized("autofill.extension.resource.list.section.all.title"),
          resources: state.resources,
          tapAction: { resourceID in
            self.controller.selectResource(resourceID)
          }
        )
      }
    }
    .refreshable {
      await self.controller.refresh()
    }
    .listStyle(.plain)
    .environment(\.defaultMinListRowHeight, 20)
  }
}
