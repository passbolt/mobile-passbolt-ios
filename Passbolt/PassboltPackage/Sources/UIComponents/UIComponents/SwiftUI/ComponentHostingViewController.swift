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

@available(
  *,
  deprecated,
  message: "Please switch to `ViewController` and `ViewController` with `NavigationTo` from Display module"
)
@MainActor
public final class ComponentHostingViewController<HostedView>: UIViewController, SwiftUIComponent
where HostedView: ComponentView {

  public typealias Controller = ComponentHostingController<HostedView.Controller>

  @MainActor public static func instance(
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
  public var components: UIComponentFactory
  public var cancellables: Cancellables
  private let controller: Controller

  internal init(
    using controller: Controller,
    with components: UIComponentFactory,
    cancellables: Cancellables
  ) {
    self.components = components
    self.controller = controller
    self.cancellables = cancellables
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  public required init?(coder: NSCoder) {
    unreachable(#function)
  }

  public override var childForStatusBarStyle: UIViewController? {
    presentedViewController as? AnyUIComponent
  }

  public override func loadView() {
    super.loadView()
    mut(self.view) {
      .backgroundColor(.passboltBackground)
    }
    self.cancellables.executeOnMainActor {
      let controller: HostedView.Controller = self.controller.hostedController

      let hostingController: UIHostingController<HostedView> = .init(
        rootView: HostedView(
          state: controller.viewState,
          controller: controller
        )
      )

      if let legacyButton: LegacyNavigationBarButtonBridge = HostedView.legacyNavigaitionBarButtonBridge(
        using: controller
      ) {
        self.navigationItem.rightBarButtonItem = Mutation<UIBarButtonItem>
          .combined(
            .style(.done),
            .image(named: legacyButton.icon, from: .uiCommons),
            .action {
							Task {
								await consumingErrors {
									try await legacyButton.action()
								}
							}
						}
          )
          .instantiate()
      }  // else no button

      self.addChild(hostingController)
      mut(hostingController.view) {
        .combined(
          .backgroundColor(.clear),
          .subview(of: self.view),
          .edges(
            equalTo: self.view,
            usingSafeArea: false
          ),
          .widthAnchor(.equalTo, self.view.widthAnchor),
          .heightAnchor(.equalTo, self.view.heightAnchor)
        )
      }
      hostingController.didMove(toParent: self)
    }
  }

  override public func viewDidLoad() {
    super.viewDidLoad()
    self.setupView()
  }

  override public func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    self.activate()
  }

  override public func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    self.deactivate()
  }

  override public func dismiss(
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
}
