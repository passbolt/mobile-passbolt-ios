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

/// Temorary container to refactor top-level views without refactoring entire navigation at once.
private final class ControlledViewContainer<ContainedView: ControlledView>:
  UIViewController, UIComponent
{

  // MARK: UIComponent conformance
  fileprivate var contentView: UIView {
    hostingController.view
  }

  fileprivate var cancellables: Cancellables

  fileprivate static func instance(
    using controller: Controller,
    with components: UIComponentFactory,
    cancellables: Cancellables
  ) -> Self {
    .init(
      controller: controller,
      cancellables: cancellables,
      components: components
    )
  }

  fileprivate lazy var hostingController: UIHostingController<ContainedView> = {
    .init(rootView: createView())
  }()

  fileprivate typealias ContentView = UIView

  fileprivate final class Controller: UIController {

    fileprivate let context: ContainedView.Controller.Context

    fileprivate static func instance(
      in context: ContainedView.Controller.Context,
      with features: inout Features,
      cancellables: Cancellables
    ) throws -> Self {
      .init(context: context)
    }

    private init(context: ContainedView.Controller.Context) {
      self.context = context
    }
  }

  fileprivate var components: UIComponentFactory
  fileprivate var controller: Controller

  override fileprivate func viewDidLoad() {
    setupView()
  }

  fileprivate func setupView() {
    let hostingController: UIHostingController<ContainedView> = self.hostingController
    addChild(hostingController)

    guard let containedView = hostingController.view
    else {
      Unavailable.error("Failed to create contained view.")
        .logged()
        .asAssertionFailure()
      return
    }
    containedView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(containedView)
    NSLayoutConstraint.activate([
      view.topAnchor.constraint(equalTo: containedView.topAnchor),
      view.bottomAnchor.constraint(equalTo: containedView.bottomAnchor),
      view.leadingAnchor.constraint(equalTo: containedView.leadingAnchor),
      view.trailingAnchor.constraint(equalTo: containedView.trailingAnchor),
    ])
    hostingController.didMove(toParent: self)

  }

  fileprivate init(
    controller: Controller,
    cancellables: Cancellables,
    components: UIComponentFactory
  ) {
    self.controller = controller
    self.cancellables = cancellables
    self.components = components
    super.init(nibName: nil, bundle: nil)
  }

  private func createView() -> ContainedView {
    do {
      let controller: ContainedView.Controller = try ContainedView.Controller(
        context: self.controller.context,
        features: components.features
      )

      return .init(controller: controller)
    }
    catch {
      error
        .logged()
        .asFatalError(message: "Failed to create ControlledView.")
    }
  }

  fileprivate required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

extension AnyUIComponent {

  @MainActor public func replaceNavigationRoot<View>(
    with type: View.Type,
    in context: View.Controller.Context,
    animated: Bool = true
  ) async where View: ControlledView {
    await self.replaceNavigationRoot(
      with: ControlledViewContainer<View>.self,
      in: context,
      animated: animated
    )
  }

  @MainActor public func replaceNavigationRoot<View>(
    with type: View.Type,
    animated: Bool = true
  ) async where View: ControlledView, View.Controller.Context == Void {
    await replaceNavigationRoot(with: type, in: (), animated: animated)
  }
}
