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

internal final class Window {
  
  private let window: UIWindow
  private let controller: WindowController
  private let cancellables: Cancellables
  private let maskView: SplashScreenView = .init()
  
  internal init(
    in scene: UIWindowScene,
    using controller: WindowController,
    within components: UIComponentFactory,
    cancellables: Cancellables
  ) {
    self.window = UIWindow(windowScene: scene)
    self.controller = controller
    self.cancellables = cancellables
    self.window.rootViewController = components
      .instance(
        of: SplashScreenViewController.self,
        in: SplashScreenController.Context()
      )
  }
}

extension Window {
  
  internal var isActive: Bool {
    get { window.isKeyWindow }
    set {
      switch newValue {
      case true:
        maskView.removeFromSuperview()
        window.makeKeyAndVisible()
        
      case false:
        maskView.frame = window.bounds
        window.addSubview(maskView)
        window.resignKey()
      }
    }
  }
}
