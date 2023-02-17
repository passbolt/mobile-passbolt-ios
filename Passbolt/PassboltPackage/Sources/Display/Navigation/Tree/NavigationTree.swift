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

@available(*, deprecated, message: "Please switch to `NavigationTo`")
public struct NavigationTree {

  internal var state: MutableViewState<NavigationTreeState>
}

extension NavigationTree: StaticFeature {

  #if DEBUG
  public static var placeholder: Self {
    return .init(
      state: .placeholder()
    )
  }
  #endif
}

extension NavigationTree {

  @MainActor public func contains(
    _ nodeID: ViewNodeID
  ) -> Bool {
    self.state.value.contains(nodeID)
  }

  @MainActor public var treeState: NavigationTreeState {
    self.state.value
  }

  @MainActor public func set(
    treeState: NavigationTreeState
  ) {
    self.state.update(\.self, to: treeState)
  }

  @MainActor public func mutate<Returned>(
    _ access: (inout NavigationTreeState) throws -> Returned
  ) rethrows -> Returned {
    try self.state.update { (value: inout NavigationTreeState) -> Returned in
      try access(&value)
    }
  }

  @discardableResult
  @MainActor public func replaceRoot<NodeView>(
    with nodeType: NodeView.Type,
    controller: NodeView.Controller
  ) -> ViewNodeID
  where NodeView: ControlledView {
    self.state.update { (tree: inout NavigationTreeState) in
      tree.replaceRoot(
        with: nodeType,
        controller: controller
      )
    }
  }

  @discardableResult
  @MainActor public func replaceRoot<NodeView>(
    pushing nodeType: NodeView.Type,
    controller: NodeView.Controller
  ) -> ViewNodeID
  where NodeView: ControlledView {
    self.state.update { (tree: inout NavigationTreeState) in
      tree.replaceRoot(
        withOnStack: nodeType,
        controller: controller
      )
    }
  }

  @discardableResult
  @MainActor public func push<NodeView>(
    _ nodeType: NodeView.Type,
    controller: NodeView.Controller
  ) -> ViewNodeID
  where NodeView: ControlledView {
    self.state.update { (tree: inout NavigationTreeState) in
      tree.push(
        nodeType,
        controller: controller
      )
    }
  }

  @discardableResult
  @MainActor public func present<NodeView>(
    _ presentation: NavigationTreeOverlayPresentation = .sheet,
    _ nodeType: NodeView.Type,
    controller: NodeView.Controller
  ) -> ViewNodeID
  where NodeView: ControlledView {
    self.state.update { (tree: inout NavigationTreeState) in
      tree.present(
        presentation,
        nodeType,
        controller: controller
      )
    }
  }

  @discardableResult
  @MainActor public func present<NodeView>(
    _ presentation: NavigationTreeOverlayPresentation = .sheet,
    pushing nodeType: NodeView.Type,
    controller: NodeView.Controller
  ) -> ViewNodeID
  where NodeView: ControlledView {
    self.state.update { (tree: inout NavigationTreeState) in
      tree.present(
        presentation,
        onStack: nodeType,
        controller: controller
      )
    }
  }

  @MainActor public func dismiss(
    _ nodeID: ViewNodeID
  ) {
    self.state.update { (tree: inout NavigationTreeState) in
      tree.dismiss(nodeID)
    }
  }

  @MainActor public func dismiss(
    upTo nodeID: ViewNodeID
  ) {
    self.state.update { (tree: inout NavigationTreeState) in
      tree.dismiss(upTo: nodeID)
    }
  }
}

extension NavigationTree {

  @available(*, deprecated, message: "For legacy bridge only") @discardableResult
  @MainActor public func replaceRoot<Component>(
    with componentType: Component.Type,
    context: Component.Controller.Context,
    using features: Features
  ) async -> ViewNodeID
  where Component: UIComponent {
    let cancellables: Cancellables = .init()
    let controller: Component.Controller
    var features: Features = features
    do {
      controller = try .instance(
        in: context,
        with: &features,
        cancellables: cancellables
      )
    }
    catch {
      error
        .asTheError()
        .asFatalError(message: "Cannot instantiate UIComponent")
    }
    let component: LegacyNavigationNodeBridgeView<Component> = .init(
      features: features,
      controller: controller,
      cancellables: cancellables
    )
    let nodeID: ViewNodeID = component.viewNodeID

    self.state.update { (tree: inout NavigationTreeState) in
      tree.mutate { (treeRoot: inout NavigationTreeNode) in
        treeRoot = .just(
          id: nodeID,
          view: LegacyBridgeControlledView(
            for: component
          )
        )
      }
    }

    return nodeID
  }

  @available(*, deprecated, message: "For legacy bridge only") @discardableResult
  @MainActor public func replaceRoot<Component>(
    pushing componentType: Component.Type,
    context: Component.Controller.Context,
    using features: Features
  ) async -> ViewNodeID
  where Component: UIComponent {
    let cancellables: Cancellables = .init()
    let controller: Component.Controller
    var features: Features = features
    do {
      controller = try .instance(
        in: context,
        with: &features,
        cancellables: cancellables
      )
    }
    catch {
      error
        .asTheError()
        .asFatalError(message: "Cannot instantiate UIComponent")
    }
    let component: LegacyNavigationNodeBridgeView<Component> = .init(
      features: features,
      controller: controller,
      cancellables: cancellables
    )
    let nodeID: ViewNodeID = component.viewNodeID

    self.state.update { (tree: inout NavigationTreeState) in
      tree.mutate { (treeRoot: inout NavigationTreeNode) in
        treeRoot = .stack(
          .element(
            id: nodeID,
            view: LegacyBridgeControlledView(
              for: component
            ),
            next: .none
          )
        )
      }
    }

    return nodeID
  }

  @available(*, deprecated, message: "For legacy bridge only") @discardableResult
  @MainActor public func push<Component>(
    _ componentType: Component.Type,
    context: Component.Controller.Context,
    using features: Features
  ) async -> ViewNodeID
  where Component: UIComponent {
    let cancellables: Cancellables = .init()
    let controller: Component.Controller
    var features: Features = features
    do {
      controller = try .instance(
        in: context,
        with: &features,
        cancellables: cancellables
      )
    }
    catch {
      error
        .asTheError()
        .asFatalError(message: "Cannot instantiate UIComponent")
    }
    let component: LegacyNavigationNodeBridgeView<Component> = .init(
      features: features,
      controller: controller,
      cancellables: cancellables
    )
    let nodeID: ViewNodeID = component.viewNodeID

    self.state.update { (tree: inout NavigationTreeState) in
      tree.mutate { (treeRoot: inout NavigationTreeNode) in
        treeRoot =
          treeRoot
          .pushing(
            LegacyBridgeControlledView(
              for: component
            ),
            withID: nodeID
          )
      }
    }

    return nodeID
  }

  @available(*, deprecated, message: "For legacy bridge only") @discardableResult
  @MainActor public func present<Component>(
    _ presentation: NavigationTreeOverlayPresentation = .sheet,
    _ componentType: Component.Type,
    context: Component.Controller.Context,
    using features: Features
  ) async -> ViewNodeID
  where Component: UIComponent {
    let cancellables: Cancellables = .init()
    let controller: Component.Controller
    var features: Features = features
    do {
      controller = try .instance(
        in: context,
        with: &features,
        cancellables: cancellables
      )
    }
    catch {
      error
        .asTheError()
        .asFatalError(message: "Cannot instantiate UIComponent")
    }
    let component: LegacyNavigationNodeBridgeView<Component> = .init(
      features: features,
      controller: controller,
      cancellables: cancellables
    )
    let nodeID: ViewNodeID = component.viewNodeID

    self.state.update { (tree: inout NavigationTreeState) in
      tree.mutate { (treeRoot: inout NavigationTreeNode) in
        treeRoot =
          treeRoot
          .presenting(
            LegacyBridgeControlledView(
              for: component
            ),
            withID: nodeID,
            presentation
          )
      }
    }

    return nodeID
  }

  @available(*, deprecated, message: "For legacy bridge only") @discardableResult
  @MainActor public func present<Component>(
    _ presentation: NavigationTreeOverlayPresentation = .sheet,
    pushing componentType: Component.Type,
    context: Component.Controller.Context,
    using features: Features
  ) async -> ViewNodeID
  where Component: UIComponent {
    let cancellables: Cancellables = .init()
    let controller: Component.Controller
    var features: Features = features
    do {
      controller = try .instance(
        in: context,
        with: &features,
        cancellables: cancellables
      )
    }
    catch {
      error
        .asTheError()
        .asFatalError(message: "Cannot instantiate UIComponent")
    }
    let component: LegacyNavigationNodeBridgeView<Component> = .init(
      features: features,
      controller: controller,
      cancellables: cancellables
    )
    let nodeID: ViewNodeID = component.viewNodeID

    self.state.update { (tree: inout NavigationTreeState) in
      tree.mutate { (treeRoot: inout NavigationTreeNode) in
        treeRoot =
          treeRoot
          .presenting(
            pushed: LegacyBridgeControlledView(
              for: component
            ),
            withID: nodeID,
            presentation
          )
      }
    }

    return nodeID
  }
}

extension NavigationTree {

  fileprivate static func liveNavigationTree(
    from root: NavigationTreeRootViewAnchor
  ) -> Self {
    let initializationViewController: InitializationViewNode.Controller = .init()
    let navigationTree: NavigationTree = .init(
      state: .init(
        initial: .init(
          root: .just(
            id: initializationViewController.viewNodeID,
            view: InitializationViewNode(
              controller: initializationViewController
            )
          )
        )
      )
    )

    Task { @MainActor in
      root.setRoot(
        NavigationTreeRootView(
          navigationTree: navigationTree
        )
      )
    }

    return navigationTree
  }
}

extension FeaturesRegistry {

  public mutating func useLiveNavigationTree(
    from root: NavigationTreeRootViewAnchor
  ) {
    self.use(
      NavigationTree.liveNavigationTree(from: root)
    )
  }
}
