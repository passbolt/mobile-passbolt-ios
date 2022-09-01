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

internal struct HomeNavigationNodeView: NavigationNodeView {

  internal typealias Controller = HomeNavigationNodeController

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
  }

  @ViewBuilder private func bodyView(
    with state: ViewState
  ) -> some View {
    ScreenView(
      titleIcon: state.mode.iconName,
      title: state.mode.title,
      titleBarShadow: true,
      snackBarMessage: self.controller.binding(to: \.snackBarMessage),
      titleExtensionView: {
        self.searchView(with: state)
      },
      titleLeadingItem: EmptyView.init,
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
      text: self.controller
        .viewState
        .binding(to: \.searchText),
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
    state
      .modeContent
      .controlling(
        ResourcesListDisplayView.self,
        or: ResourceFolderContentDisplayView.self,
        or: ResourceTagsListDisplayView.self,
        or: ResourceUserGroupsListDisplayView.self,
        or: LoaderNavigationNodeView.self,
        default: EmptyView.init
      )
  }
}
