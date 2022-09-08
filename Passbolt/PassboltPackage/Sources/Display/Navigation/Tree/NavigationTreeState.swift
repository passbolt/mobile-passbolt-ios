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

public struct NavigationTreeState {

  internal private(set) var root: NavigationTreeNode
}

extension NavigationTreeState: Hashable {}

extension NavigationTreeState {

  public func contains(
    _ nodeID: NavigationNodeID
  ) -> Bool {
    self.root.contains(nodeID)
  }

  @discardableResult
  public mutating func replaceRoot<ViewNode>(
    with _: ViewNode.Type,
    controller: ViewNode.Controller
  ) -> NavigationNodeID
  where ViewNode: ControlledViewNode {
    let newNode: AnyViewNode = .init(
      erasing: ViewNode.self,
      with: controller
    )

    self.root = .just(newNode)

    return newNode.nodeID
  }

  @discardableResult
  public mutating func replaceRoot<ViewNode>(
    withOnStack _: ViewNode.Type,
    controller: ViewNode.Controller
  ) -> NavigationNodeID
  where ViewNode: ControlledViewNode {
    let newNode: AnyViewNode = .init(
      erasing: ViewNode.self,
      with: controller
    )

    self.root = .stack(.element(newNode, next: .none))

    return newNode.nodeID
  }

  @discardableResult
  public mutating func push<ViewNode>(
    _: ViewNode.Type,
    controller: ViewNode.Controller
  ) -> NavigationNodeID
  where ViewNode: ControlledViewNode {
    let newNode: AnyViewNode = .init(
      erasing: ViewNode.self,
      with: controller
    )

    self.root = self.root.pushing(newNode)

    return newNode.nodeID
  }

  @discardableResult
  public mutating func present<ViewNode>(
    _ presentation: NavigationTreeOverlayPresentation = .sheet,
    _: ViewNode.Type,
    controller: ViewNode.Controller
  ) -> NavigationNodeID
  where ViewNode: ControlledViewNode {
    let newNode: AnyViewNode = .init(
      erasing: ViewNode.self,
      with: controller
    )

    self.root = self.root.presenting(newNode, presentation)

    return newNode.nodeID
  }

  @discardableResult
  public mutating func present<ViewNode>(
    _ presentation: NavigationTreeOverlayPresentation = .sheet,
    onStack _: ViewNode.Type,
    controller: ViewNode.Controller
  ) -> NavigationNodeID
  where ViewNode: ControlledViewNode {
    let newNode: AnyViewNode = .init(
      erasing: ViewNode.self,
      with: controller
    )

    self.root = self.root.presenting(pushed: newNode, presentation)

    return newNode.nodeID
  }

  public mutating func dismiss(
    _ nodeID: NavigationNodeID
  ) {
    if let subtree: NavigationTreeNode = self.root.removing(nodeID) {
      self.root = subtree
    }
    else {
      InternalInconsistency
        .error("Invalid navigation tree state, cannot dismiss root of the tree")
        .asFatalError()
    }
  }

  public mutating func dismiss(
    upTo nodeID: NavigationNodeID
  ) {
    self.root = self.root.removing(upTo: nodeID)
  }
}

// Legacy only
extension NavigationTreeState {

  @available(*, deprecated, message: "For legacy bridge only")
  internal mutating func mutate(
    _ mutation: (inout NavigationTreeNode) -> Void
  ) {
    mutation(&self.root)
  }
}
