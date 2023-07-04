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

import UICommons
import UIComponents

// This ViewController is a bridge for
// legacy way of building views and navigating.
// It does not suit UIComponent nor ControlledView
// pattern just to allow bridging between worlds.
// It will have to be removed/rewritten when
// cleaning up main tabs navigation.
internal final class OTPResourcesTabViewController: NavigationViewController {

  internal override class var disableSystemBackNavigation: Bool { false }

  private let controller: OTPResourcesTabController

  internal init(
    controller: OTPResourcesTabController
  ) {
    self.controller = controller
    super.init(cancellables: .init())
    self.setup()
  }

  internal func setup() {
    mut(tabBarItem) {
      .combined(
        .title(.localized(key: "tab.otp")),
        .image(named: .otp, from: .uiCommons)
      )
    }

    let root: UIHostingController = .init(
      rootView: OTPResourcesListView(
        controller: self.controller.prepareListController()
      )
    )
    root.destinationIdentifier = OTPResourcesListNavigationDestination.identifier
    self.viewControllers = [root]
  }
}
