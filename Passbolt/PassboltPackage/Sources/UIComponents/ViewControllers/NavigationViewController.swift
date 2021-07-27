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
import UIKit

open class NavigationViewController: UINavigationController {

  public init() {
    super.init(navigationBarClass: NavigationBar.self, toolbarClass: nil)
    isModalInPresentation = true
    (self as? AnyUIComponent)?.setup()
  }

  @available(*, unavailable)
  public required init?(coder: NSCoder) {
    unreachable("\(Self.self).\(#function) should not be used")
  }

  override open var childForStatusBarStyle: UIViewController? {
    presentedViewController ?? visibleViewController
  }

  public var lazyView: UIView {
    unreachable("\(Self.self).\(#function) should not be used")
  }

  public var contentView: UIView {
    unreachable("\(Self.self).\(#function) should not be used")
  }

  public var navigationBarView: NavigationBar {
    guard let navigationBar = navigationBar as? NavigationBar else {
      unreachable("Invalid navigation bar type, expected: \(NavigationBar.self), received: \(type(of: navigationBar))")
    }

    return navigationBar
  }

  override open func loadView() {
    super.loadView()
    view.backgroundColor = .white
  }

  override open func viewDidLoad() {
    super.viewDidLoad()
    (self as? AnyUIComponent)?.setupView()
  }

  override open func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    (self as? AnyUIComponent)?.activate()
  }

  override open func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    (self as? AnyUIComponent)?.deactivate()
  }

  override open func dismiss(
    animated: Bool,
    completion: (() -> Void)? = nil
  ) {
    let presentingViewController: UIViewController? = self.presentingViewController
    super.dismiss(
      animated: animated,
      completion: { [weak presentingViewController] in
        presentingViewController?.setNeedsStatusBarAppearanceUpdate()
        completion?()
      }
    )
  }

  open override func pushViewController(_ viewController: UIViewController, animated: Bool) {
    CATransaction.begin()
    CATransaction.setCompletionBlock({ [weak self] in
      if self?.viewControllers.count ?? 0 > 1,
        let tabBar = self?.tabBarController?.tabBar,
        !tabBar.isHidden
      {
        tabBar.isHidden = true
        tabBar.isTranslucent = true
      }
      else {
        /* NOP */
      }
    })
    super.pushViewController(viewController, animated: animated)
    CATransaction.commit()
  }

  open override func popViewController(animated: Bool) -> UIViewController? {
    CATransaction.begin()
    CATransaction.setCompletionBlock({ [weak self] in
      if self?.viewControllers.count == 1,
        let tabBar = self?.tabBarController?.tabBar,
        tabBar.isHidden
      {
        tabBar.isHidden = false
        tabBar.isTranslucent = false
      }
      else {
        /* NOP */
      }
    })

    defer { CATransaction.commit() }
    return super.popViewController(animated: animated)
  }

  open override func setViewControllers(_ viewControllers: [UIViewController], animated: Bool) {
    CATransaction.begin()
    CATransaction.setCompletionBlock({ [weak self] in
      if self?.viewControllers.count == 1,
        let tabBar = self?.tabBarController?.tabBar,
        tabBar.isHidden
      {
        tabBar.isHidden = false
        tabBar.isTranslucent = false
      }
      else if self?.viewControllers.count ?? 0 > 1,
        let tabBar = self?.tabBarController?.tabBar,
        !tabBar.isHidden
      {
        tabBar.isHidden = true
        tabBar.isTranslucent = true
      }
      else {
        /* NOP */
      }
    })
    super.setViewControllers(viewControllers, animated: animated)
    CATransaction.commit()
  }

  open override func popToRootViewController(animated: Bool) -> [UIViewController]? {
    CATransaction.begin()
    CATransaction.setCompletionBlock({ [weak self] in
      if self?.viewControllers.count == 1,
        let tabBar = self?.tabBarController?.tabBar,
        tabBar.isHidden
      {
        tabBar.isHidden = false
        tabBar.isTranslucent = false
      }
      else {
        /* NOP */
      }
    })
    defer { CATransaction.commit() }
    return super.popToRootViewController(animated: animated)
  }
}
