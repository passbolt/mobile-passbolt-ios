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

@MainActor
public final class ComponentViewController<
  HostedView,
  Presenter: ComponentPresenter,
  Controller
>: UIViewController, SwiftUIComponent
where Presenter.PresentedView == HostedView, Presenter.Controller == Controller {

  public static func instance(
    using controller: Controller,
    with components: UIComponentFactory
  ) -> Self {
    Self(
      using: controller,
      with: components
    )
  }

  public var components: UIComponentFactory
  private let controller: Controller

  internal init(
    using controller: Controller,
    with components: UIComponentFactory
  ) {
    self.components = components
    self.controller = controller
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
    let hostingController: UIHostingController<HostedView> = .init(
      rootView: HostedView(
        presenter: .init(
          controller: controller,
          navigation: .init(sourceComponent: self)
        )
      )
    )
    addChild(hostingController)
    self.view.addSubview(hostingController.view)
    mut(hostingController.view) {
      .combined(
        .subview(of: self.view),
        .edges(equalTo: self.view, usingSafeArea: false)
      )
    }
    hostingController.didMove(toParent: self)
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
    super.dismiss(
      animated: animated,
      completion: { [weak presentingViewController] in
        presentingViewController?.setNeedsStatusBarAppearanceUpdate()
        completion?()
      }
    )
  }
}
