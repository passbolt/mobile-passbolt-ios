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

import Commons
import UIKit

public protocol AnyUIComponent: UIViewController {
  
  var lazyView: UIView { get }
  
  func setup()
  func setupView()
  func activate()
  func deactivate()
}

public protocol UIComponent: AnyUIComponent {
  
  associatedtype View: UIView
  associatedtype Controller: UIController
  
  static func instance(
    using controller: Controller,
    with components: UIComponentFactory
  ) -> Self
  
  var contentView: View { get }
  var components: UIComponentFactory { get }
}

extension UIComponent {
  
  public var lazyView: UIView { contentView }
  
  public func setup() {}
  public func activate() {}
  public func deactivate() {}
}

public final class NavigationView: UIView {}

extension UIComponent where Self: UINavigationController {
  
  public var contentView: NavigationView {
    unreachable("\(Self.self).\(#function) should not be used")
  }
  
  public func setupView() {}
}

extension UIComponent where Self: UIAlertController {
  
  public func setupView() {}
}

public protocol UINavigationComponent: UIComponent where Self: UINavigationController {
  
}
