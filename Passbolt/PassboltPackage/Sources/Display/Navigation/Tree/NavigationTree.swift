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
import Features
import UIKit

public struct NavigationTree {

  internal var state: ViewStateBinding<NavigationTreeState>
}

extension NavigationTree: StaticFeature {

  #if DEBUG
  public static var placeholder: Self {
    return .init(
      state: .placeholder
    )
  }
  #endif
}

extension NavigationTree {

  @MainActor public func contains(
    _ nodeID: NavigationNodeID
  ) -> Bool {
    self.state.wrappedValue.contains(nodeID)
  }

  @MainActor public var treeState: NavigationTreeState {
    self.state.wrappedValue
  }

  @MainActor public func set(
    treeState: NavigationTreeState
  ) {
    self.state.wrappedValue = treeState
  }

  @MainActor public func mutate<Returned>(
    _ access: (inout NavigationTreeState) throws -> Returned
  ) rethrows -> Returned {
    try self.state.mutate { (value: inout NavigationTreeState) -> Returned in
      try access(&value)
    }
  }

  @discardableResult
  @MainActor public func replaceRoot<NodeView>(
    with nodeType: NodeView.Type,
    controller: NodeView.Controller
  ) -> NavigationNodeID
  where NodeView: ControlledViewNode {
    self.state.wrappedValue
      .replaceRoot(
        with: nodeType,
        controller: controller
      )
  }

  @discardableResult
  @MainActor public func replaceRoot<NodeView>(
    pushing nodeType: NodeView.Type,
    controller: NodeView.Controller
  ) -> NavigationNodeID
  where NodeView: ControlledViewNode {
    self.state.wrappedValue
      .replaceRoot(
        withOnStack: nodeType,
        controller: controller
      )
  }

  @discardableResult
  @MainActor public func push<NodeView>(
    _ nodeType: NodeView.Type,
    controller: NodeView.Controller
  ) -> NavigationNodeID
  where NodeView: ControlledViewNode {
    self.state.wrappedValue
      .push(
        nodeType,
        controller: controller
      )
  }

  @discardableResult
  @MainActor public func present<NodeView>(
    _ presentation: NavigationTreeOverlayPresentation = .sheet,
    _ nodeType: NodeView.Type,
    controller: NodeView.Controller
  ) -> NavigationNodeID
  where NodeView: ControlledViewNode {
    self.state.wrappedValue
      .present(
        presentation,
        nodeType,
        controller: controller
      )
  }

  @discardableResult
  @MainActor public func present<NodeView>(
    _ presentation: NavigationTreeOverlayPresentation = .sheet,
    pushing nodeType: NodeView.Type,
    controller: NodeView.Controller
  ) -> NavigationNodeID
  where NodeView: ControlledViewNode {
    self.state.wrappedValue
      .present(
        presentation,
        onStack: nodeType,
        controller: controller
      )
  }

  @MainActor public func dismiss(
    _ nodeID: NavigationNodeID
  ) {
    self.state.wrappedValue.dismiss(nodeID)
  }

  @MainActor public func dismiss(
    upTo nodeID: NavigationNodeID
  ) {
    self.state.wrappedValue.dismiss(upTo: nodeID)
  }
}

extension NavigationTree {

  @available(*, deprecated, message: "For legacy bridge only") @discardableResult
  @MainActor public func replaceRoot<Component>(
    with componentType: Component.Type,
    context: Component.Controller.Context,
    using features: FeatureFactory
  ) async -> NavigationNodeID
  where Component: UIComponent {
    let nodeID: NavigationNodeID = .init()
    let cancellables: Cancellables = .init()
    let controller: Component.Controller
    do {
      controller = try await .instance(
        in: context,
        with: features,
        cancellables: cancellables
      )
    }
    catch {
      error
        .asTheError()
        .asFatalError(message: "Cannot instantiate UIComponent")
    }

    self.state.wrappedValue
      .mutate { (treeRoot: inout NavigationTreeNode) in
        treeRoot = .just(
          id: nodeID,
          view: LegacyBridgeControlledViewNode(
            for: LegacyNavigationNodeBridgeView<Component>(
              features: features,
              controller: controller,
              cancellables: cancellables
            )
          )
        )
      }

    return nodeID
  }

  @available(*, deprecated, message: "For legacy bridge only") @discardableResult
  @MainActor public func replaceRoot<Component>(
    pushing componentType: Component.Type,
    context: Component.Controller.Context,
    using features: FeatureFactory
  ) async -> NavigationNodeID
  where Component: UIComponent {
    let nodeID: NavigationNodeID = .init()
    let cancellables: Cancellables = .init()
    let controller: Component.Controller
    do {
      controller = try await .instance(
        in: context,
        with: features,
        cancellables: cancellables
      )
    }
    catch {
      error
        .asTheError()
        .asFatalError(message: "Cannot instantiate UIComponent")
    }

    self.state.wrappedValue
      .mutate { (treeRoot: inout NavigationTreeNode) in
        treeRoot = .stack(
          .element(
            id: nodeID,
            view: LegacyBridgeControlledViewNode(
              for: LegacyNavigationNodeBridgeView<Component>(
                features: features,
                controller: controller,
                cancellables: cancellables
              )
            ),
            next: .none
          )
        )
      }

    return nodeID
  }

  @available(*, deprecated, message: "For legacy bridge only") @discardableResult
  @MainActor public func push<Component>(
    _ componentType: Component.Type,
    context: Component.Controller.Context,
    using features: FeatureFactory
  ) async -> NavigationNodeID
  where Component: UIComponent {
    let nodeID: NavigationNodeID = .init()
    let cancellables: Cancellables = .init()
    let controller: Component.Controller
    do {
      controller = try await .instance(
        in: context,
        with: features,
        cancellables: cancellables
      )
    }
    catch {
      error
        .asTheError()
        .asFatalError(message: "Cannot instantiate UIComponent")
    }

    self.state.wrappedValue
      .mutate { (treeRoot: inout NavigationTreeNode) in
        treeRoot =
          treeRoot
          .pushing(
            LegacyBridgeControlledViewNode(
              for: LegacyNavigationNodeBridgeView<Component>(
                features: features,
                controller: controller,
                cancellables: cancellables
              )
            ),
            withID: nodeID
          )
      }

    return nodeID
  }

  @available(*, deprecated, message: "For legacy bridge only") @discardableResult
  @MainActor public func present<Component>(
    _ presentation: NavigationTreeOverlayPresentation = .sheet,
    _ componentType: Component.Type,
    context: Component.Controller.Context,
    using features: FeatureFactory
  ) async -> NavigationNodeID
  where Component: UIComponent {
    let nodeID: NavigationNodeID = .init()
    let cancellables: Cancellables = .init()
    let controller: Component.Controller
    do {
      controller = try await .instance(
        in: context,
        with: features,
        cancellables: cancellables
      )
    }
    catch {
      error
        .asTheError()
        .asFatalError(message: "Cannot instantiate UIComponent")
    }

    self.state.wrappedValue
      .mutate { (treeRoot: inout NavigationTreeNode) in
        treeRoot =
          treeRoot
          .presenting(
            LegacyBridgeControlledViewNode(
              for: LegacyNavigationNodeBridgeView<Component>(
                features: features,
                controller: controller,
                cancellables: cancellables
              )
            ),
            withID: nodeID,
            presentation
          )
      }

    return nodeID
  }

  @available(*, deprecated, message: "For legacy bridge only") @discardableResult
  @MainActor public func present<Component>(
    _ presentation: NavigationTreeOverlayPresentation = .sheet,
    pushing componentType: Component.Type,
    context: Component.Controller.Context,
    using features: FeatureFactory
  ) async -> NavigationNodeID
  where Component: UIComponent {
    let nodeID: NavigationNodeID = .init()
    let cancellables: Cancellables = .init()
    let controller: Component.Controller
    do {
      controller = try await .instance(
        in: context,
        with: features,
        cancellables: cancellables
      )
    }
    catch {
      error
        .asTheError()
        .asFatalError(message: "Cannot instantiate UIComponent")
    }

    self.state.wrappedValue
      .mutate { (treeRoot: inout NavigationTreeNode) in
        treeRoot =
          treeRoot
          .presenting(
            pushed: LegacyBridgeControlledViewNode(
              for: LegacyNavigationNodeBridgeView<Component>(
                features: features,
                controller: controller,
                cancellables: cancellables
              )
            ),
            withID: nodeID,
            presentation
          )
      }

    return nodeID
  }
}

extension NavigationTree {

  @MainActor fileprivate static func liveNavigationTree(
    from root: NavigationTreeRootViewAnchor
  ) -> Self {
    let initializationViewNodeController: InitializationViewNode.Controller = .init()
    let navigationTree: NavigationTree = .init(
      state: .init(
        initial: .init(
          root: .just(
            id: initializationViewNodeController.nodeID,
            view: InitializationViewNode(
              controller: initializationViewNodeController
            )
          )
        )
      )
    )

    root.setRoot(
      NavigationTreeRootView(
        navigationTree: navigationTree
      )
    )

    return navigationTree
  }
}

extension FeatureFactory {

  @MainActor public func useLiveNavigationTree(
    from root: NavigationTreeRootViewAnchor
  ) {
    self.use(
      NavigationTree.liveNavigationTree(from: root)
    )
  }
}
