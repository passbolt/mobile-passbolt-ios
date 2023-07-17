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

  internal let controller: ResourceContextualMenuViewController

  internal init(
    controller: ResourceContextualMenuViewController
  ) {
    self.controller = controller
  }

  internal var body: some View {
    DrawerMenu(
      closeTap: self.controller.dismiss,
      title: {
        with(\.title) { (title: String) in
          Text(title)
        }
      },
      content: {
        withEach(\.accessMenuItems) { (item: ResourceContextualMenuItem) in
          item.view(using: self.controller)
        }

        Divider()

        withEach(\.modifyMenuItems) { (item: ResourceContextualMenuItem) in
          item.view(using: self.controller)
        }
      }
    )
    .task(self.controller.activate)
  }
}

extension ResourceContextualMenuItem {

  @ViewBuilder @MainActor fileprivate func view(
    using controller: ResourceContextualMenuViewController
  ) -> some View {
    switch self {
    case .openURI:
      DrawerMenuItemView(
        action: {
          await controller.performAction(for: self)
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
          await controller.performAction(for: self)
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
          await controller.performAction(for: self)
        },
        title: {
          Text(displayable: "resource.menu.item.copy.username")
        },
        leftIcon: {
          Image(named: .user)
            .resizable()
        }
      )

    case .copyPassword:
      DrawerMenuItemView(
        action: {
          await controller.performAction(for: self)
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
          await controller.performAction(for: self)
        },
        title: {
          Text(displayable: "resource.menu.item.copy.description")
        },
        leftIcon: {
          Image(named: .description)
            .resizable()
        }
      )

    case .showOTPMenu:
      DrawerMenuItemView(
        action: {
          await controller.performAction(for: self)
        },
        title: {
          Text(displayable: "resource.menu.item.otp.menu")
        },
        leftIcon: {
          Image(named: .otp)
            .resizable()
        }
      )
    case .toggle(favorite: true):
      DrawerMenuItemView(
        action: {
          await controller.performAction(for: self)
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
          await controller.performAction(for: self)
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
          await controller.performAction(for: self)
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
          await controller.performAction(for: self)
        },
        title: {
          Text(displayable: "resource.menu.item.edit.password")
        },
        leftIcon: {
          Image(named: .edit)
            .resizable()
        }
      )

    case .addOTP:
      DrawerMenuItemView(
        action: {
          await controller.performAction(for: self)
        },
        title: {
          Text(displayable: "resource.menu.item.add.otp")
        },
        leftIcon: {
          Image(named: .otp)
            .resizable()
        }
      )

    case .delete:
      DrawerMenuItemView(
        action: {
          await controller.performAction(for: self)
        },
        title: {
          Text(displayable: "resource.menu.item.delete.resource")
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
