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
import UIComponents

internal indirect enum NavigationTreeNode {

  case just(AnyNavigationNodeView)
  case stack(NavigationStackNode)
  case overlay(
    NavigationTreeNode,
    covering: NavigationTreeNode
  )
}

extension NavigationTreeNode: Hashable {

  internal static func == (
    _ lhs: NavigationTreeNode,
    _ rhs: NavigationTreeNode
  ) -> Bool {
    switch (lhs, rhs) {
    case let (.just(lNodeView), .just(rNodeView)):
      return lNodeView.nodeID == rNodeView.nodeID

    case let (.stack(lStackNode), .stack(rStackNode)):
      return lStackNode == rStackNode

    case let (.overlay(lOverlayTree, covering: lCoveredTree), .overlay(rOverlayTree, covering: rCoveredTree)):
      return lOverlayTree == rOverlayTree
        && lCoveredTree == rCoveredTree

    case (.overlay, .just), (.overlay, .stack), (.stack, .just), (.stack, .overlay), (.just, .stack), (.just, .overlay):
      return false
    }
  }

  internal func hash(
    into hasher: inout Hasher
  ) {
    switch self {
    case let .just(nodeView):
      hasher.combine(nodeView.nodeID)

    case let .stack(stackNode):
      hasher.combine(stackNode)

    case let .overlay(overlayTree, covering: coveredTree):
      hasher.combine(overlayTree)
      hasher.combine(coveredTree)
    }
  }
}

extension NavigationTreeNode {

  internal var id: NavigationNodeID {
    switch self {
    case let .just(nodeView):
      return nodeView.nodeID

    case let .stack(stackNode):
      return stackNode.nodeID

    case let .overlay(overlayTree, covering: _):
      return overlayTree.id
    }
  }

  internal var overlayNode: NavigationTreeNode? {
    switch self {
    case .just:
      return .none

    case .stack:
      return .none

    case let .overlay(overlayTree, covering: _):
      return overlayTree
    }
  }

  @discardableResult
  internal func pushing(
    _ nodeView: AnyNavigationNodeView
  ) -> NavigationTreeNode {
    switch self {
    case let .just(currentNodeView):
//      assertionFailure("Pushing view without stack")
      return .stack(
        .element(
          currentNodeView,
          next: .element(
            nodeView,
            next: .none
          )
        )
      )

    case let .stack(stackNode):
      return .stack(stackNode.appending(nodeView))

    case let .overlay(overlayTree, coveredTree):
      return .overlay(
        overlayTree.pushing(nodeView),
        covering: coveredTree
      )
    }
  }

  @discardableResult
  internal func presenting(
    _ nodeView: AnyNavigationNodeView
  ) -> NavigationTreeNode {
    .overlay(
      .just(nodeView),
      covering: self
    )
  }

  @discardableResult
  internal func presenting(
    pushed nodeView: AnyNavigationNodeView
  ) -> NavigationTreeNode {
    .overlay(
      .stack(.element(nodeView, next: .none)),
      covering: self
    )
  }

  internal func removing(
    _ nodeID: NavigationNodeID
  ) -> Self? {
    switch self {
    case let .just(nodeView):
      if nodeView.nodeID == nodeID {
        return .none
      }
      else {
        return self
      }

    case let .stack(stackNode):
      return
        stackNode
        .prefix(to: nodeID)
        .map(NavigationTreeNode.stack)

    case let .overlay(overlayTree, coveredTree):
      if coveredTree.contains(nodeID) {
        return coveredTree.removing(nodeID)
      }
      else if let overlayTree: Self = overlayTree.removing(nodeID) {
        return .overlay(
          overlayTree,
          covering: coveredTree
        )
      }
      else {
        return coveredTree
      }
    }
  }

  internal func contains(
    _ nodeID: NavigationNodeID
  ) -> Bool {
    switch self {
    case let .just(node):
      return node.nodeID == nodeID

    case let .stack(stackNode):
      return stackNode.contains(nodeID)

    case let .overlay(overlayTree, coveredTree):
      return overlayTree.contains(nodeID)
        || coveredTree.contains(nodeID)
    }
  }
}
