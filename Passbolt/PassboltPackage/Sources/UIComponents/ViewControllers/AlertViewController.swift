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

// UIAlertController does not support subclassing, in order to make a proper component from it
// we avoid overriding its initializer (which does break the things) and instead use existing one
// and add controller right after initialization (this is reason for imclitly unwrapped optional there).
@available(
  *,
  deprecated,
  message: "Please switch to `ViewController` and `ViewController` with `NavigationTo` from Display module"
)
@MainActor open class AlertViewController<Controller: UIController>: UIAlertController {

  public static func instance(
    using controller: Controller,
    with components: UIComponentFactory,
    cancellables: Cancellables
  ) -> Self {
    let instance: Self = Self(
      title: nil,
      message: nil,
      preferredStyle: .alert
    )
    instance.controller = controller
    instance._components = components
    instance._cancellables = cancellables
    (instance as? AnyUIComponent)?.setup()
    return instance
  }

  public var components: UIComponentFactory { _components }

  // swift-format-ignore: NoLeadingUnderscores, NeverUseImplicitlyUnwrappedOptionals
  private var _components: UIComponentFactory!
  // swift-format-ignore: NeverUseImplicitlyUnwrappedOptionals
  public private(set) var controller: Controller! = nil
  // swift-format-ignore: NoLeadingUnderscores, NeverUseImplicitlyUnwrappedOptionals
  private var _cancellables: Cancellables!
  public var cancellables: Cancellables {
    get { self._cancellables }
    set { self._cancellables = newValue }
  }

  public var contentView: UIView {
    unreachable(#function)
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
}
