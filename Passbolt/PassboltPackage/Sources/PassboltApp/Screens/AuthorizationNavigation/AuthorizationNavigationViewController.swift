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
  private let controller: AuthorizationNavigationController

  internal init(
    using controller: Controller,
    with components: UIComponentFactory
  ) {
    self.controller = controller
    self.components = components
    super.init()
  }

  internal var isAuthorizationPromptAllowed: Bool {
    viewControllers
      .contains(where: { viewController in
        viewController is BiometricsInfoViewController
          || viewController is BiometricsSetupViewController
          || viewController is ExtensionSetupViewController
      })
  }

  internal var isInitialScreenNavigationAllowed: Bool {
    // Checking for account selection
    if viewControllers.count == 1 && viewControllers.first is AccountSelectionViewController {
      return false
    }
    else {
      // Checking wether the user is currently on the account setup
      return
        !viewControllers
        .contains(where: { viewController in
          viewController is AccountTransferFailureViewController
            || viewController is BiometricsInfoViewController
            || viewController is BiometricsSetupViewController
            || viewController is CodeScanningViewController
            || viewController is CodeScanningSuccessViewController
            || viewController is CodeScanningDuplicateViewController
            || viewController is TransferSignInViewController
            || viewController is TransferInfoScreenViewController
            || viewController is ExtensionSetupViewController
        })
    }
  }

  internal func setup() {
    let accountSelectionScreen: AccountSelectionViewController = components.instance()
    setViewControllers([accountSelectionScreen], animated: false)

    mut(navigationBarView) {
      .primaryNavigationStyle()
    }

    if let selectedAccountID: Account.LocalID = controller.selectedAccountID {
      push(
        AuthorizationViewController.self,
        in: selectedAccountID
      )
    }
    else {
      /* */
    }
  }
}
