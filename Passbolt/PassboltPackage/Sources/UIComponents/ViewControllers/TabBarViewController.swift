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

open class TabsViewController: UITabBarController {

  // Overriding TabBar is almost impossible, we delegate its colors setup to VC
  public lazy var tabBarDynamicBackgroundColor: DynamicColor = .always(self.tabBar.backgroundColor) {
    didSet {
      self.tabBar.backgroundColor = tabBarDynamicBackgroundColor(in: traitCollection.userInterfaceStyle)
    }
  }
  public lazy var tabBarDynamicTintColor: DynamicColor = .always(self.tabBar.tintColor) {
    didSet {
      self.tabBar.tintColor = tabBarDynamicTintColor(in: traitCollection.userInterfaceStyle)
    }
  }
  public lazy var tabBarDynamicBarTintColor: DynamicColor = .always(self.tabBar.barTintColor) {
    didSet {
      self.tabBar.barTintColor = tabBarDynamicBarTintColor(in: traitCollection.userInterfaceStyle)
    }
  }
  public lazy var tabBarDynamicUnselectedItemTintColor: DynamicColor = .always(.black) {
    didSet {
      self.tabBar.unselectedItemTintColor = tabBarDynamicUnselectedItemTintColor(in: traitCollection.userInterfaceStyle)
    }
  }

  public init() {
    super.init(nibName: nil, bundle: nil)
    navigationItem.backButtonTitle = ""
    isModalInPresentation = true
    (self as? AnyUIComponent)?.setup()
  }

  @available(*, unavailable)
  public required init?(coder: NSCoder) {
    unreachable("\(Self.self).\(#function) should not be used")
  }

  public var lazyView: UIView {
    unreachable("\(Self.self).\(#function) should not be used")
  }

  override open var childForStatusBarStyle: UIViewController? {
    presentedViewController ?? selectedViewController
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

  override public func traitCollectionDidChange(
    _ previousTraitCollection: UITraitCollection?
  ) {
    super.traitCollectionDidChange(previousTraitCollection)
    guard traitCollection != previousTraitCollection
    else { return }
    updateColors()
  }

  private func updateColors() {
    let interfaceStyle: UIUserInterfaceStyle = traitCollection.userInterfaceStyle
    self.tabBar.backgroundColor = tabBarDynamicBackgroundColor(in: interfaceStyle)
    self.tabBar.tintColor = tabBarDynamicTintColor(in: interfaceStyle)
    self.tabBar.barTintColor = tabBarDynamicBarTintColor(in: interfaceStyle)
    self.tabBar.unselectedItemTintColor = tabBarDynamicUnselectedItemTintColor(in: interfaceStyle)
  }
}
