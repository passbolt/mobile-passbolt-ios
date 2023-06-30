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
import UICommons

internal struct ResourceContextualMenuView: ControlledView {

  private let controller: ResourceContextualMenuViewController

  internal init(
    controller: ResourceContextualMenuViewController
  ) {
    self.controller = controller
  }

  internal var body: some View {
    DrawerMenu(
      closeTap: self.controller.dismiss,
      title: {
        WithViewState(
          from: self.controller,
          at: \.title
        ) { title in
          Text(title)
        }
      },
      content: {
        WithEachViewState(
          from: self.controller,
          at: \.accessActions
        ) { (action: ResourceContextualMenuAccessAction) in
          switch action {
          case .openURI:
            DrawerMenuItemView(
              action: {
                await self.controller.handle(action)
              },
              title: {
                Text(displayable: "resource.menu.item.open.url")
              },
              leftIcon: {
                Image(named: .open)
                  .resizable()
              }
            )

          case .copyURI:
            DrawerMenuItemView(
              action: {
                await self.controller.handle(action)
              },
              title: {
                Text(displayable: "resource.menu.item.copy.url")
              },
              leftIcon: {
                Image(named: .link)
                  .resizable()
              }
            )

          case .copyUsername:
            DrawerMenuItemView(
              action: {
                await self.controller.handle(action)
              },
              title: {
                Text(displayable: "resource.menu.item.copy.username")
              },
              leftIcon: {
                Image(named: .user)
                  .resizable()
              }
            )

          case .revealOTP:
            DrawerMenuItemView(
              action: {
                await self.controller.handle(action)
              },
              title: {
                Text(displayable: "resource.menu.item.reveal.otp")
              },
              leftIcon: {
                Image(named: .eye)
                  .resizable()
              }
            )

          case .copyOTP:
            DrawerMenuItemView(
              action: {
                await self.controller.handle(action)
              },
              title: {
                Text(displayable: "resource.menu.item.copy.otp")
              },
              leftIcon: {
                Image(named: .copy)
                  .resizable()
              }
            )

          case .copyPassword:
            DrawerMenuItemView(
              action: {
                await self.controller.handle(action)
              },
              title: {
                Text(displayable: "resource.menu.item.copy.password")
              },
              leftIcon: {
                Image(named: .key)
                  .resizable()
              }
            )

          case .copyDescription:
            DrawerMenuItemView(
              action: {
                await self.controller.handle(action)
              },
              title: {
                Text(displayable: "resource.menu.item.copy.description")
              },
              leftIcon: {
                Image(named: .description)
                  .resizable()
              }
            )
          }
        }

        Divider()

        WithEachViewState(
          from: self.controller,
          at: \.modifyActions
        ) { (action: ResourceContextualMenuModifyAction) in
          switch action {
          case .toggle(favorite: true):
            DrawerMenuItemView(
              action: {
                await self.controller.handle(action)
              },
              title: {
                Text(displayable: "resource.menu.item.remove.favorite")
              },
              leftIcon: {
                Image(named: .starCrossed)
                  .resizable()
              }
            )

          case .toggle(favorite: false):
            DrawerMenuItemView(
              action: {
                await self.controller.handle(action)
              },
              title: {
                Text(displayable: "resource.menu.item.add.favorite")
              },
              leftIcon: {
                Image(named: .star)
                  .resizable()
              }
            )

          case .share:
            DrawerMenuItemView(
              action: {
                await self.controller.handle(action)
              },
              title: {
                Text(displayable: "resource.menu.item.share")
              },
              leftIcon: {
                Image(named: .share)
                  .resizable()
              }
            )

          case .editPassword:
            DrawerMenuItemView(
              action: {
                await self.controller.handle(action)
              },
              title: {
                Text(displayable: "resource.menu.item.edit.password")
              },
              leftIcon: {
                Image(named: .edit)
                  .resizable()
              }
            )

          case .editTOTP:
            DrawerMenuItemView(
              action: {
                await self.controller.handle(action)
              },
              title: {
                Text(displayable: "resource.menu.item.edit.totp")
              },
              leftIcon: {
                Image(named: .otp)
                  .resizable()
              }
            )

          case .delete:
            DrawerMenuItemView(
              action: {
                await self.controller.handle(action)
              },
              title: {
                Text(displayable: "resource.menu.item.delete")
                  .foregroundColor(.passboltSecondaryRed)
              },
              leftIcon: {
                Image(named: .trash)
                  .resizable()
                  .foregroundColor(.passboltSecondaryRed)
              }
            )
          }
        }
      }
    )
    .task(self.controller.activate)
  }
}
