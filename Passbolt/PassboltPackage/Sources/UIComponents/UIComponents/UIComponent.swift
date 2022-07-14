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

import CommonModels
import Features
import UIKit

@MainActor public protocol AnyUIComponent: UIViewController {

  @MainActor var lazyView: UIView { get }
  var components: UIComponentFactory { get }

  @MainActor func setup()
  @MainActor func setupView()
  @MainActor func activate()
  @MainActor func deactivate()
}

@MainActor public protocol UIComponent: AnyUIComponent {

  associatedtype ContentView: UIView
  associatedtype Controller: UIController

  @MainActor static func instance(
    using controller: Controller,
    with components: UIComponentFactory,
    cancellables: Cancellables
  ) -> Self

  @MainActor var contentView: ContentView { get }
  @MainActor var cancellables: Cancellables { get set }
}

extension UIComponent {

  @MainActor public var lazyView: UIView { contentView }

  @MainActor public func setup() {}
  @MainActor public func activate() {}
  @MainActor public func deactivate() {}
}

@MainActor public protocol SwiftUIComponent: UIComponent where ContentView == UIView {

  associatedtype HostedView: ComponentView
}

extension SwiftUIComponent {

  @MainActor public var contentView: ContentView {
    self.view
  }

  @MainActor public func setupView() {}
}

public final class NavigationView: UIView {}

extension UIComponent where Self: UINavigationController {

  @MainActor public var contentView: NavigationView {
    unreachable(#function)
  }

  @MainActor public func setupView() {}
}

extension UIComponent where Self: UITabBarController {

  @MainActor public var contentView: NavigationView {
    unreachable(#function)
  }

  @MainActor public func setupView() {}
}

extension UIComponent where Self: UIAlertController {

  @MainActor public func setupView() {}
}
