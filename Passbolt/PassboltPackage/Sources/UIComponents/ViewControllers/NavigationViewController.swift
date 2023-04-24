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
import UIKit

@available(
  *,
  deprecated,
  message: "Please switch to `ViewController` and `ViewController` with `NavigationTo` from Display module"
)
@MainActor open class NavigationViewController: UINavigationController {

  open class var disableSystemBackNavigation: Bool { true }
  public var cancellables: Cancellables

  @MainActor public init(
    cancellables: Cancellables
  ) {
    self.cancellables = cancellables
    super.init(nibName: nil, bundle: nil)
    self.isModalInPresentation = true
    self.delegate = self
    (self as? AnyUIComponent)?.setup()
  }

  @available(*, unavailable)
  public required init?(coder: NSCoder) {
    unreachable(#function)
  }

  override open var childForStatusBarStyle: UIViewController? {
    (presentedViewController ?? visibleViewController) as? AnyUIComponent
  }

  public var lazyView: UIView {
    unreachable(#function)
  }

  public var contentView: UIView {
    unreachable(#function)
  }

  override open func loadView() {
    super.loadView()
    view.backgroundColor = .passboltBackground
    interactivePopGestureRecognizer?.isEnabled = !Self.disableSystemBackNavigation
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
    super
      .dismiss(
        animated: animated,
        completion: { [weak presentingViewController] in
          presentingViewController?.setNeedsStatusBarAppearanceUpdate()
          completion?()
        }
      )
  }

  open override func pushViewController(_ viewController: UIViewController, animated: Bool) {
    (viewController as? CustomPresentableUIComponent)?.customPresentationSetup()
    if let tabBarController = self.tabBarController, self.viewControllers.count > 0 {
      viewController.extendedLayoutIncludesOpaqueBars = true
      viewController.edgesForExtendedLayout = viewController.edgesForExtendedLayout.union([.bottom])
      if !tabBarController.tabBar.isHidden {
        UIView.animate(
          withDuration: animated ? 0.25 : 0,
          delay: 0,
          options: [.allowUserInteraction, .beginFromCurrentState],
          animations: {
            tabBarController.tabBar.frame.origin.x = -tabBarController.tabBar.frame.width
          },
          completion: { _ in
            tabBarController.tabBar.isHidden = true
          }
        )
      }
    }
    else {
      /* NOP */
    }

    CATransaction.begin()
    CATransaction.setCompletionBlock {
      (viewController.navigationItem.backBarButtonItem?.menu = UIMenu(
        title: "",
        image: nil,
        identifier: nil,
        options: [],
        children: []
      ))
    }
    super.pushViewController(viewController, animated: animated)
    CATransaction.commit()

  }

  open override func popViewController(animated: Bool) -> UIViewController? {
    if let tabBarController = tabBarController,
      tabBarController.tabBar.isHidden,
      viewControllers.count <= 2
    {
      tabBarController.tabBar.isHidden = false
      UIView.animate(
        withDuration: animated ? 0.25 : 0,
        delay: 0,
        options: [.allowUserInteraction, .beginFromCurrentState],
        animations: {
          tabBarController.tabBar.frame.origin.x = 0
        }
      )
    }
    else {
      /* NOP */
    }

    return super.popViewController(animated: animated)
  }

  open override func setViewControllers(_ viewControllers: [UIViewController], animated: Bool) {
    viewControllers.forEach { viewController in
      (viewController as? CustomPresentableUIComponent)?.customPresentationSetup()
    }

    if let tabBarController = tabBarController {
      viewControllers[1...]
        .forEach { viewController in
          viewController.extendedLayoutIncludesOpaqueBars = true
          viewController.edgesForExtendedLayout = viewController.edgesForExtendedLayout.union([.bottom])
        }
      if tabBarController.tabBar.isHidden, viewControllers.count <= 1 {
        tabBarController.tabBar.isHidden = false
        UIView.animate(
          withDuration: animated ? 0.25 : 0,
          delay: 0,
          options: [.allowUserInteraction, .beginFromCurrentState],
          animations: {
            tabBarController.tabBar.frame.origin.x = 0
          }
        )
      }
      else if !tabBarController.tabBar.isHidden, viewControllers.count > 1 {
        UIView.animate(
          withDuration: animated ? 0.25 : 0,
          delay: 0,
          options: [.allowUserInteraction, .beginFromCurrentState],
          animations: {
            tabBarController.tabBar.frame.origin.x = -tabBarController.tabBar.frame.width
          },
          completion: { _ in
            tabBarController.tabBar.isHidden = true
          }
        )
      }
      else {
        /* NOP */
      }
    }
    else {
      /* NOP */
    }

    super.setViewControllers(viewControllers, animated: animated)
  }

  open override func popToRootViewController(animated: Bool) -> [UIViewController]? {
    if let tabBarController = tabBarController,
      tabBarController.tabBar.isHidden
    {
      tabBarController.tabBar.isHidden = false
      UIView.animate(
        withDuration: animated ? 0.25 : 0,
        delay: 0,
        options: [.allowUserInteraction, .beginFromCurrentState],
        animations: {
          tabBarController.tabBar.frame.origin.x = 0
        }
      )
    }
    else {
      /* NOP */
    }
    return super.popToRootViewController(animated: animated)
  }

  open override func popToViewController(
    _ viewController: UIViewController,
    animated: Bool
  ) -> [UIViewController]? {
    if let tabBarController = tabBarController,
      tabBarController.tabBar.isHidden,
      self.viewControllers.firstIndex(of: viewController) == self.viewControllers.startIndex
    {
      tabBarController.tabBar.isHidden = false
      UIView.animate(
        withDuration: animated ? 0.25 : 0,
        delay: 0,
        options: [.allowUserInteraction, .beginFromCurrentState],
        animations: {
          tabBarController.tabBar.frame.origin.x = 0
        }
      )
    }
    else {
      /* NOP */
    }
    return super
      .popToViewController(
        viewController,
        animated: animated
      )
  }
}

// Disables contextual menu on back button, it cannot be disabled otherwise.
// https://developer.apple.com/forums/thread/653913?answerId=621184022#621184022
private final class BackBarButtonItem: UIBarButtonItem {

  override var menu: UIMenu? {
    set { /* NOP */  }
    get { return nil }
  }
}

extension NavigationViewController: UINavigationControllerDelegate {

  public func navigationController(
    _ navigationController: UINavigationController,
    willShow viewController: UIViewController,
    animated: Bool
  ) {
    viewController.navigationItem.backBarButtonItem = BackBarButtonItem(
      title: "",
      style: .plain,
      target: nil,
      action: nil
    )
  }
}
