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

import UIComponents

internal struct HomePresentationMenuView: ComponentView {

  @ObservedObject private var state: ObservableValue<State>
  private let controller: HomePresentationMenuController

  internal init(
    state: ObservableValue<State>,
    controller: HomePresentationMenuController
  ) {
    self.state = state
    self.controller = controller
  }

  internal var body: some View {
    DrawerMenu(
      closeTap: {
        self.controller.dismissView()
      },
      title: {
        Text(
          displayable: .localized(
            key: "home.presentation.mode.menu.title"
          )
        )
      },
      content: {
        VStack(spacing: 0) {
          ForEach(self.state.availableModes, id: \.self) { mode in
            // TODO: [MOB-???] There might be other modes in section
            // which require divider but those are not linked to folders
            // rethink adding divider when adding tags or groups
            if case .foldersExplorer = mode {
              DrawerMenuDividerView()
            }  // else { /* NOP */ }
            DrawerMenuItemView(
              action: {
                self.controller.selectMode(mode)
              },
              title: {
                Text(displayable: mode.title)
              },
              leftIcon: {
                Image(named: mode.iconName)
              },
              isSelected: mode == self.state.currentMode
            )
          }
        }
      }
    )
  }
}

extension HomePresentationMenuView {

  internal struct State: Hashable {

    internal var currentMode: HomePresentationMode
    internal var availableModes: Array<HomePresentationMode>
  }
}
