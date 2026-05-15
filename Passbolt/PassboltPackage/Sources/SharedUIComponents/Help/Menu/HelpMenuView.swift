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

internal struct HelpMenuView: ControlledView {

  internal let controller: HelpMenuViewController

  internal init(controller: HelpMenuViewController) {
    self.controller = controller
  }

  internal var body: some View {
    DrawerMenu(
      closeTap: { await self.controller.closeMenu() },
      title: {
        Text(displayable: "help.menu.title")
          .font(.inter(ofSize: 18, weight: .bold))
          .foregroundStyle(Color.passboltPrimaryText)
      },
      content: {
        with(\.actions) { actions in
          VStack(spacing: 10) {
            ForEach(actions, id: \.self) { action in
              DrawerMenuItemView(
                action: action.action,
                title: {
                  Text(displayable: action.title)
                    .font(.inter(ofSize: 14, weight: .semibold))
                    .foregroundStyle(Color.passboltPrimaryText)
                },
                leftIcon: {
                  Image(named: action.icon)
                    .renderingMode(.template)
                    .foregroundStyle(Color.passboltPrimaryText)
                    .frame(width: 18, height: 18)
                }
              )
            }
          }
        }
      }
    )
    .ignoresSafeArea()
    .task { await controller.activate() }
  }
}

#if DEBUG
#Preview {
  PlaceholderView()
    .sheet(isPresented: .constant(true)) {
      createPreview(
        HelpMenuView.self,
        with: .init()
      )
      .wrapInNavigationStack()
    }
}
#endif
