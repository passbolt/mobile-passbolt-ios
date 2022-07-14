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

import UICommons
import UIComponents

@MainActor
internal final class DisplayViewBridge<HostedView>: UIHostingController<HostedView>, UIComponent
where HostedView: DisplayView {

  @MainActor internal struct Controller: UIController {

    fileprivate let hostedController: HostedView.Controller

    internal static func instance(
      in context: HostedView.Controller,
      with features: FeatureFactory,
      cancellables: Cancellables
    ) -> Self {
      Self(
        hostedController: context
      )
    }
  }

  internal static func instance(
    using controller: Controller,
    with components: UIComponentFactory,
    cancellables: Cancellables
  ) -> Self {
    let instance: Self = .init(
      rootView: HostedView(
        controller: controller.hostedController
      )
    )
    instance._components = components
    instance._cancellables = cancellables
    return instance
  }

  // swift-format-ignore: NeverUseImplicitlyUnwrappedOptionals, NoLeadingUnderscores
  private var _components: UIComponentFactory!
  // swift-format-ignore: NeverUseImplicitlyUnwrappedOptionals, NoLeadingUnderscores
  private var _cancellables: Cancellables!
  internal var cancellables: Cancellables {
    get { self._cancellables }
    set { self._cancellables = newValue }
  }
  internal var components: UIComponentFactory {
    self._components
  }

  internal var contentView: ContentView {
    unreachable(#function)
  }

  internal override var childForStatusBarStyle: UIViewController? {
    self.presentedViewController as? AnyUIComponent
  }

  internal func setupView() {}

  override internal func dismiss(
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
