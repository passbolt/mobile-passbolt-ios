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

  internal var state: DisplayViewState<NavigationTreeNode>
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
    self.state.with { (state: inout NavigationTreeNode) -> Bool in
      state.contains(nodeID)
    }
  }

  public var treeState: NavigationTreeState {
    .init(tree: self.state.wrappedValue)
  }

  public func set(
    treeState: NavigationTreeState
  ) {
    self.state.with { (state: inout NavigationTreeNode) in
      state = treeState.tree
    }
  }

  @discardableResult
  @Sendable public func replaceRoot<NodeView>(
    with nodeType: NodeView.Type,
    controller: NodeView.Controller
  ) -> NavigationNodeID
  where NodeView: NavigationNodeView {
    let rootNode: AnyNavigationNodeView = .init(
      for: nodeType,
      controller: controller
    )

    self.state.with { (state: inout NavigationTreeNode) in
      state = .just(rootNode)
    }

    return rootNode.nodeID
  }

  @discardableResult
  @Sendable public func replaceRoot<NodeView>(
    pushing nodeType: NodeView.Type,
    controller: NodeView.Controller
  ) -> NavigationNodeID
  where NodeView: NavigationNodeView {
    let rootNode: AnyNavigationNodeView = .init(
      for: nodeType,
      controller: controller
    )

    self.state.with { (state: inout NavigationTreeNode) in
      state = .stack(.element(rootNode, next: .none))
    }

    return rootNode.nodeID
  }

  @discardableResult
  @Sendable public func push<NodeView>(
    _ nodeType: NodeView.Type,
    controller: NodeView.Controller
  ) -> NavigationNodeID
  where NodeView: NavigationNodeView {
    let nodeView: AnyNavigationNodeView = .init(
      for: nodeType,
      controller: controller
    )

    self.state.with { (state: inout NavigationTreeNode) in
      state = state.pushing(nodeView)
    }

    return nodeView.nodeID
  }

  @discardableResult
  @Sendable public func present<NodeView>(
    _ nodeType: NodeView.Type,
    controller: NodeView.Controller
  ) -> NavigationNodeID
  where NodeView: NavigationNodeView {
    let nodeView: AnyNavigationNodeView = .init(
      for: nodeType,
      controller: controller
    )

    self.state.with { (state: inout NavigationTreeNode) in
      state = state.presenting(nodeView)
    }

    return nodeView.nodeID
  }

  @discardableResult
  @Sendable public func present<NodeView>(
    pushing nodeType: NodeView.Type,
    controller: NodeView.Controller
  ) -> NavigationNodeID
  where NodeView: NavigationNodeView {
    let nodeView: AnyNavigationNodeView = .init(
      for: nodeType,
      controller: controller
    )

    self.state.with { (state: inout NavigationTreeNode) in
      state = state.presenting(pushed: nodeView)
    }

    return nodeView.nodeID
  }

  @Sendable public func dismiss(
    _ nodeID: NavigationNodeID
  ) {
    self.state.with { (state: inout NavigationTreeNode) in
      if let subtree: NavigationTreeNode = state.removing(nodeID) {
        state = subtree
      }
      else {
        InternalInconsistency
          .error("Invalid navigation tree state, cannot dismiss root of the tree")
          .asFatalError()
      }
    }
  }
}

// LegacyBridge
extension NavigationTree {

  @discardableResult
  public func replaceRoot<Component>(
    with componentType: Component.Type,
    context: Component.Controller.Context,
    using features: FeatureFactory
  ) async -> NavigationNodeID
  where Component: UIComponent {
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

    let rootNode: AnyNavigationNodeView = await .init(
      for: LegacyNavigationNodeBridgeView<Component>(
        features: features,
        controller: controller,
        cancellables: cancellables
      )
    )

    self.state.with { (state: inout NavigationTreeNode) in
      state = .just(rootNode)
    }

    return rootNode.nodeID
  }

  @discardableResult
  public func replaceRoot<Component>(
    pushing componentType: Component.Type,
    context: Component.Controller.Context,
    using features: FeatureFactory
  ) async -> NavigationNodeID
  where Component: UIComponent {
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

    let rootNode: AnyNavigationNodeView = await .init(
      for: LegacyNavigationNodeBridgeView<Component>(
        features: features,
        controller: controller,
        cancellables: cancellables
      )
    )

    self.state.with { (state: inout NavigationTreeNode) in
      state = .stack(.element(rootNode, next: .none))
    }

    return rootNode.nodeID
  }

  @discardableResult
  public func push<Component>(
    _ componentType: Component.Type,
    context: Component.Controller.Context,
    using features: FeatureFactory
  ) async -> NavigationNodeID
  where Component: UIComponent {
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

    let nodeView: AnyNavigationNodeView = await .init(
      for: LegacyNavigationNodeBridgeView<Component>(
        features: features,
        controller: controller,
        cancellables: cancellables
      )
    )

    self.state.with { (state: inout NavigationTreeNode) in
      state = state.pushing(nodeView)
    }

    return nodeView.nodeID
  }

  @discardableResult
  public func present<Component>(
    _ componentType: Component.Type,
    context: Component.Controller.Context,
    using features: FeatureFactory
  ) async -> NavigationNodeID
  where Component: UIComponent {
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

    let nodeView: AnyNavigationNodeView = await .init(
      for: LegacyNavigationNodeBridgeView<Component>(
        features: features,
        controller: controller,
        cancellables: cancellables
      )
    )

    self.state.with { (state: inout NavigationTreeNode) in
      state = state.presenting(nodeView)
    }

    return nodeView.nodeID
  }

  @discardableResult
  public func present<Component>(
    pushing componentType: Component.Type,
    context: Component.Controller.Context,
    using features: FeatureFactory
  ) async -> NavigationNodeID
  where Component: UIComponent {
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

    let nodeView: AnyNavigationNodeView = await .init(
      for: LegacyNavigationNodeBridgeView<Component>(
        features: features,
        controller: controller,
        cancellables: cancellables
      )
    )

    self.state.with { (state: inout NavigationTreeNode) in
      state = state.presenting(pushed: nodeView)
    }

    return nodeView.nodeID
  }
}

extension NavigationTree {

  @MainActor fileprivate static func liveNavigationTree(
    from root: NavigationTreeRoot
  ) -> Self {
    let initialNode: AnyNavigationNodeView = InitialNavigationNodeView.erasedInstance

    let navigationTree: NavigationTree = .init(
      state: .init(initial: .just(initialNode))
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
    from root: NavigationTreeRoot
  ) {
    self.use(
      NavigationTree.liveNavigationTree(from: root)
    )
  }
}
