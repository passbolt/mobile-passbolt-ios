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
import SharedUIComponents
import UICommons
import UIComponents

internal final class AuthorizationNavigationViewController: NavigationViewController, UIComponent {

  internal typealias Controller = AuthorizationNavigationController

  internal static func instance(
    using controller: Controller,
    with components: UIComponentFactory
  ) -> Self {
    Self(
      using: controller,
      with: components
    )
  }

  internal let components: UIComponentFactory
  private let controller: Controller

  internal init(
    using controller: Controller,
    with components: UIComponentFactory
  ) {
    self.controller = controller
    self.components = components
    super.init()
  }

  internal func setup() {
    mut(navigationBarView) {
      .primaryNavigationStyle()
    }

    if controller.hasAccounts {
      accountSelectionSetup()
    }
    else {
      noAccountsSetup()
    }
  }

  private func noAccountsSetup() {
    let noAccountsViewController: NoAccountsViewController = components.instance()

    setViewControllers([noAccountsViewController], animated: false)
  }

  private func accountSelectionSetup() {
    let accountSelectionScreen: AccountSelectionViewController = components.instance(in: controller.mode)

    setViewControllers([accountSelectionScreen], animated: false)

    if let selectedAccount: Account = controller.selectedAccount {
      push(
        AuthorizationViewController.self,
        in: selectedAccount
      )
    }
    else {
      /* */
    }
  }
}
