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

@available(
  *,
  deprecated,
  message: "Please switch to `ViewController` and `ViewController` with `NavigationTo` from Display module"
)
public final class DisplayViewBridgeHandle<HostedView>: ObservableObject
where HostedView: ControlledView {

  fileprivate var instance: DisplayViewBridge<HostedView>?

  fileprivate init() {}

  public func setNavigationBackButton(hidden: Bool) {
    self.instance?.navigationItem.hidesBackButton = hidden
  }
}

@available(
  *,
  deprecated,
  message: "Please switch to `ViewController` and `ViewController` with `NavigationTo` from Display module"
)
@MainActor
internal final class DisplayViewBridge<HostedView>: UIHostingController<
  ModifiedContent<HostedView, _EnvironmentKeyWritingModifier<DisplayViewBridgeHandle<HostedView>?>>
>, UIComponent
where HostedView: ControlledView {

  internal typealias ContentView = UIView

  @MainActor internal struct Controller: UIController {

    fileprivate let hostedController: HostedView.Controller

    internal static func instance(
      in context: HostedView.Controller,
      with features: inout Features,
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
    let handle: DisplayViewBridgeHandle<HostedView> = .init()
    let instance: Self = .init(
      rootView: HostedView(
        controller: controller.hostedController
      )
      // this force cast always succeeds - it is actual
      // type returned but not picked by compiler
      // due to opaque result type usage here
      .environmentObject(handle)
        as! ModifiedContent<HostedView, _EnvironmentKeyWritingModifier<DisplayViewBridgeHandle<HostedView>?>>
    )
    instance._components = components
    instance._cancellables = cancellables
    handle.instance = instance
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
    self.view
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

// module placement required by dependency tree
private struct DisplayViewBridgeBackVisibilityEnvironmentKey: EnvironmentKey {

  static let defaultValue: (Bool) -> Void = unimplemented1()
}

extension EnvironmentValues {

  public var displayViewBridgeBackVisibility: (Bool) -> Void {
    get { self[DisplayViewBridgeBackVisibilityEnvironmentKey.self] }
    set { self[DisplayViewBridgeBackVisibilityEnvironmentKey.self] = newValue }
  }
}
