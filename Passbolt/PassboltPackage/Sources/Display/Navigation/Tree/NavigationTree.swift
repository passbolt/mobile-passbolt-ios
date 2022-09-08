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

  public func contains(
    _ nodeID: NavigationNodeID
  ) -> Bool {
    self.state.mutate { (state: inout NavigationTreeState) -> Bool in
      state.contains(nodeID)
    }
  }

  public var treeState: NavigationTreeState {
    self.state.wrappedValue
  }

  public func set(
    treeState: NavigationTreeState
  ) {
    self.state.mutate { (state: inout NavigationTreeState) in
      state = treeState
    }
  }

  @Sendable public func mutate<Returned>(
    _ access: (inout NavigationTreeState) throws -> Returned
  ) rethrows -> Returned {
    try self.state.mutate { (value: inout NavigationTreeState) -> Returned in
      try access(&value)
    }
  }

  @discardableResult
  @Sendable public func replaceRoot<NodeView>(
    with nodeType: NodeView.Type,
    controller: NodeView.Controller
  ) -> NavigationNodeID
  where NodeView: ControlledViewNode {
    self.mutate { (treeState: inout NavigationTreeState) in
      treeState.replaceRoot(
        with: nodeType,
        controller: controller
      )
    }
  }

  @discardableResult
  @Sendable public func replaceRoot<NodeView>(
    pushing nodeType: NodeView.Type,
    controller: NodeView.Controller
  ) -> NavigationNodeID
  where NodeView: ControlledViewNode {
    self.mutate { (treeState: inout NavigationTreeState) in
      treeState.replaceRoot(
        withOnStack: nodeType,
        controller: controller
      )
    }
  }

  @discardableResult
  @Sendable public func push<NodeView>(
    _ nodeType: NodeView.Type,
    controller: NodeView.Controller
  ) -> NavigationNodeID
  where NodeView: ControlledViewNode {
    self.mutate { (treeState: inout NavigationTreeState) in
      treeState.push(
        nodeType,
        controller: controller
      )
    }
  }

  @discardableResult
  @Sendable public func present<NodeView>(
    _ presentation: NavigationTreeOverlayPresentation = .sheet,
    _ nodeType: NodeView.Type,
    controller: NodeView.Controller
  ) -> NavigationNodeID
  where NodeView: ControlledViewNode {
    self.mutate { (treeState: inout NavigationTreeState) in
      treeState.present(
        presentation,
        nodeType,
        controller: controller
      )
    }
  }

  @discardableResult
  @Sendable public func present<NodeView>(
    _ presentation: NavigationTreeOverlayPresentation = .sheet,
    pushing nodeType: NodeView.Type,
    controller: NodeView.Controller
  ) -> NavigationNodeID
  where NodeView: ControlledViewNode {
    self.mutate { (treeState: inout NavigationTreeState) in
      treeState.present(
        presentation,
        onStack: nodeType,
        controller: controller
      )
    }
  }

  @Sendable public func dismiss(
    _ nodeID: NavigationNodeID
  ) {
    self.mutate { (treeState: inout NavigationTreeState) in
      treeState.dismiss(nodeID)
    }
  }

  @Sendable public func dismiss(
    upTo nodeID: NavigationNodeID
  ) {
    self.mutate { (treeState: inout NavigationTreeState) in
      treeState.dismiss(upTo: nodeID)
    }
  }
}

extension NavigationTree {

  @available(*, deprecated, message: "For legacy bridge only") @discardableResult
  public func replaceRoot<Component>(
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

    let newNode: AnyViewNode = await .init(
      for: LegacyNavigationNodeBridgeView<Component>(
        features: features,
        controller: controller,
        cancellables: cancellables
      ),
      withID: nodeID
    )

    self.mutate { (treeState: inout NavigationTreeState) in
      treeState.mutate { (treeRoot: inout NavigationTreeNode) in
        treeRoot = .just(newNode)
      }
    }

    return nodeID
  }

  @available(*, deprecated, message: "For legacy bridge only") @discardableResult
  public func replaceRoot<Component>(
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

    let newNode: AnyViewNode = await .init(
      for: LegacyNavigationNodeBridgeView<Component>(
        features: features,
        controller: controller,
        cancellables: cancellables
      ),
      withID: nodeID
    )

    self.mutate { (treeState: inout NavigationTreeState) in
      treeState.mutate { (treeRoot: inout NavigationTreeNode) in
        treeRoot = .stack(.element(newNode, next: .none))
      }
    }

    return nodeID
  }

  @available(*, deprecated, message: "For legacy bridge only") @discardableResult
  public func push<Component>(
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

    let newNode: AnyViewNode = await .init(
      for: LegacyNavigationNodeBridgeView<Component>(
        features: features,
        controller: controller,
        cancellables: cancellables
      ),
      withID: nodeID
    )

    self.mutate { (treeState: inout NavigationTreeState) in
      treeState.mutate { (treeRoot: inout NavigationTreeNode) in
        treeRoot = treeRoot.pushing(newNode)
      }
    }

    return nodeID
  }

  @available(*, deprecated, message: "For legacy bridge only") @discardableResult
  public func present<Component>(
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

    let newNode: AnyViewNode = await .init(
      for: LegacyNavigationNodeBridgeView<Component>(
        features: features,
        controller: controller,
        cancellables: cancellables
      ),
      withID: nodeID
    )

    self.mutate { (treeState: inout NavigationTreeState) in
      treeState.mutate { (treeRoot: inout NavigationTreeNode) in
        treeRoot = treeRoot.presenting(newNode, presentation)
      }
    }

    return nodeID
  }

  @available(*, deprecated, message: "For legacy bridge only") @discardableResult
  public func present<Component>(
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

    let newNode: AnyViewNode = await .init(
      for: LegacyNavigationNodeBridgeView<Component>(
        features: features,
        controller: controller,
        cancellables: cancellables
      ),
      withID: nodeID
    )

    self.mutate { (treeState: inout NavigationTreeState) in
      treeState.mutate { (treeRoot: inout NavigationTreeNode) in
        treeRoot = treeRoot.presenting(pushed: newNode, presentation)
      }
    }

    return nodeID
  }
}

extension NavigationTree {

  @MainActor fileprivate static func liveNavigationTree(
    from root: NavigationTreeRootViewAnchor
  ) -> Self {
    let initialNode: AnyViewNode = InitializationViewNode.erasedInstance

    let navigationTree: NavigationTree = .init(
      state: .init(
        initial: .init(
          root: .just(initialNode)
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
