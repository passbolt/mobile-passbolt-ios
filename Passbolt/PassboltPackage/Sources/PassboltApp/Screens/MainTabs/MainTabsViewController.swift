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

import Commons
import UIComponents

internal final class MainTabsViewController: TabsViewController, UIComponent {

  internal typealias Controller = MainTabsController

  internal static func instance(
    using controller: Controller,
    with components: UIComponentFactory
  ) -> Self {
    Self(
      using: controller,
      with: components
    )
  }

  internal var components: UIComponentFactory
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
    self.initializeTabs()
    self.delegate = self
  }

  internal func setupView() {
    // Can't set tab bar font without appearance proxy
    UITabBarItem
      .appearance()
      .setTitleTextAttributes(
        [.font: UIFont.inter(ofSize: 12, weight: .semibold)],
        for: .normal
      )
    UITabBarItem
      .appearance()
      .setTitleTextAttributes(
        [.font: UIFont.inter(ofSize: 12, weight: .semibold)],
        for: .selected
      )
    mut(self) {
      .custom { (subject: MainTabsViewController) in
        subject.tabBarDynamicTintColor = .primaryBlue
        subject.tabBarDynamicBackgroundColor = .background
        subject.tabBarDynamicBarTintColor = .background
        subject.tabBarDynamicUnselectedItemTintColor = .icon
        subject.tabBar.isTranslucent = false
      }
    }
    setupSubscriptions()
  }
}

extension MainTabsViewController: UITabBarControllerDelegate {

  internal func tabBarController(
    _ tabBarController: UITabBarController,
    didSelect viewController: UIViewController
  ) {
    guard let tab = MainTab(rawValue: selectedIndex)
    else { unreachable("Internal inconsistency - Invalid \(Self.self) state") }
    controller.setActiveTab(tab)
  }
}

extension MainTabsViewController {

  fileprivate func initializeTabs() {
    viewControllers = [
      components.instance(of: HomeTabViewController.self),
      components.instance(of: SettingsTabViewController.self),
    ]
  }

  fileprivate func setupSubscriptions() {
    subscribeToTabsSelection()
  }

  fileprivate func subscribeToTabsSelection() {
    controller
      .activeTabPublisher()
      .receive(on: RunLoop.main)
      .sink { [weak self] state in
        guard let self = self else { return }
        guard self.selectedIndex != state.rawValue
        else { return }
        self.selectedIndex = state.rawValue
      }
      .store(in: cancellables)
  }
}
