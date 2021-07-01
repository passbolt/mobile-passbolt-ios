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

import UIComponents

internal final class SplashScreenViewController: PlainViewController, UIComponent {
  
  internal typealias View = SplashScreenView
  internal typealias Controller = SplashScreenController
  
  internal static func instance(
    using controller: Controller,
    with components: UIComponentFactory
  ) -> Self {
    Self(
      using: controller,
      with: components
    )
  }
  
  internal private(set) lazy var contentView: SplashScreenView = .init()
  internal let components: UIComponentFactory
  private let controller: SplashScreenController
  
  internal init(
    using controller: SplashScreenController,
    with components: UIComponentFactory
  ) {
    self.controller = controller
    self.components = components
    super.init()
  }
  
  internal func setupView() {
    mut(contentView) {
      .backgroundColor(dynamic: .background)
    }
    
    setupSubscriptions()
  }
  
  private func setupSubscriptions() {
    controller
      .navigationDestinationPublisher()
      .delay(for: 0.3, scheduler: RunLoop.main)
      .receive(on: RunLoop.main)
      .sink { [weak self] destination in
        self?.navigate(to: destination)
      }
      .store(in: cancellables)
  }
  
  private func navigate(to destination: SplashScreenNavigationDestination) {
    switch destination {
    // swiftlint:disable:next explicit_type_interface
    case let .accountSelection(lastAccountID):
      replaceWindowRoot(
        with: AccountSelectionNavigationViewController.self,
        in: lastAccountID
      )

    case .accountSetup:
      replaceWindowRoot(with: WelcomeNavigationViewController.self)

    case .diagnostics:
      Commons.placeholder("TODO: diagnostics screen")
      
    case .home:
      replaceWindowRoot(with: MainTabsViewController.self)
    }
  }
}
