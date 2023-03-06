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

import CommonModels
import UIComponents

internal final class MainTabsViewController: TabsViewController, UIComponent {

  internal typealias Controller = MainTabsController

  internal static func instance(
    using controller: Controller,
    with components: UIComponentFactory,
    cancellables: Cancellables
  ) -> Self {
    Self(
      using: controller,
      with: components,
      cancellables: cancellables
    )
  }

  internal var components: UIComponentFactory
  private let controller: Controller
  private var setupSubscriptionCancellables: Cancellables = .init()

  internal init(
    using controller: Controller,
    with components: UIComponentFactory,
    cancellables: Cancellables
  ) {
    self.controller = controller
    self.components = components
    super.init(
      cancellables: cancellables
    )
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
      .combined(
        .set(\.tabBarDynamicTintColor, to: .primaryBlue),
        .set(\.tabBarDynamicBackgroundColor, to: .background),
        .set(\.tabBarDynamicBarTintColor, to: .background),
        .set(\.tabBarDynamicUnselectedItemTintColor, to: .icon)
      )
    }
    mut(self.view) {
      .backgroundColor(.none)
    }
    Mutation<UITabBar>
      .combined(
        .set(\.isTranslucent, to: false),
        .set(\.backgroundImage, to: UIImage()),
        .set(\.shadowImage, to: UIImage()),
        .shadow(color: .black, opacity: 0.2, offset: .init(width: 0, height: 10), radius: 12)
      )
      .apply(on: self.tabBar)
    setupSubscriptions()
  }

  internal func activate() {
    self.setupSubscriptionCancellables = .init()
    self.subscribeToInitialModalPresentation()
  }
}

extension MainTabsViewController: UITabBarControllerDelegate {

  internal func tabBarController(
    _ tabBarController: UITabBarController,
    didSelect viewController: UIViewController
  ) {
    guard let tab = MainTab(rawValue: selectedIndex)
    else { unreachable("Internal inconsistency - Invalid state") }
    controller.setActiveTab(tab)
  }
}

extension MainTabsViewController {

  fileprivate func initializeTabs() {
    #warning("[MOB-1075] TODO: hide OTP tab when OTP resources are not available]")
    do {
      self.viewControllers = [
        try UIComponentFactory(features: self.components.features).instance(of: HomeTabNavigationViewController.self),
        try OTPResourcesTabViewController(
          controller: self.components.features.instance()
        ),
        try UIComponentFactory(features: self.components.features).instance(of: SettingsTabViewController.self),
      ]
    }
    catch {
      error
        .asTheError()
        .pushing(
          .message("Preparing main tabs failed!")
        )
        .asFatalError()
    }
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

  fileprivate func subscribeToInitialModalPresentation() {
    controller
      .initialModalPresentation()
      .receive(on: RunLoop.main)
      .sink { [weak self] destination in
        MainActor.execute {
          switch destination {
          case .biometricsInfo:
            await self?.present(
              PlainNavigationViewController<BiometricsInfoViewController>.self
            )

          case .biometricsSetup:
            await self?.present(
              PlainNavigationViewController<BiometricsSetupViewController>.self
            )

          case .autofillSetup:
            await self?.present(
              PlainNavigationViewController<ExtensionSetupViewController>.self
            )

          case .none:
            break
          }
        }
      }
      .store(in: setupSubscriptionCancellables)
  }
}
