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

  case just(
    id: ViewNodeID,
    view: any View
  )
  case stack(NavigationStackNode)
  case overlay(
    NavigationTreeOverlay,
    covering: NavigationTreeNode
  )
}

extension NavigationTreeNode: Identifiable {

  internal var id: ViewNodeID {
    self.nodeID
  }

  internal var nodeID: ViewNodeID {
    switch self {
    case let .just(id, _):
      return id

    case let .stack(stackNode):
      return stackNode.nodeID

    case let .overlay(overlay, covering: _):
      return overlay.nodeID
    }
  }
}

extension NavigationTreeNode: Hashable {

  internal static func == (
    _ lhs: NavigationTreeNode,
    _ rhs: NavigationTreeNode
  ) -> Bool {
    switch (lhs, rhs) {
    case let (.just(lNodeID, _), .just(rNodeID, _)):
      return lNodeID == rNodeID

    case let (.stack(lStackNode), .stack(rStackNode)):
      return lStackNode == rStackNode

    case let (.overlay(lOverlay, covering: lCoveredTree), .overlay(rOverlay, covering: rCoveredTree)):
      return lOverlay == rOverlay
        && lCoveredTree == rCoveredTree

    case (.overlay, .just), (.overlay, .stack), (.stack, .just), (.stack, .overlay), (.just, .stack), (.just, .overlay):
      return false
    }
  }

  internal func hash(
    into hasher: inout Hasher
  ) {
    switch self {
    case let .just(id, _):
      hasher.combine(id)

    case let .stack(stackNode):
      hasher.combine(stackNode)

    case let .overlay(overlay, covering: coveredTree):
      hasher.combine(overlay)
      hasher.combine(coveredTree)
    }
  }
}

extension NavigationTreeNode {

  @discardableResult
  internal func pushing(
    _ nodeView: any View,
    withID id: ViewNodeID
  ) -> NavigationTreeNode {
    switch self {
    case let .just(currentNodeID, currentNodeView):
      return .stack(
        .element(
          id: currentNodeID,
          view: currentNodeView,
          next: .element(
            id: id,
            view: nodeView,
            next: .none
          )
        )
      )

    case let .stack(stackNode):
      return .stack(
        stackNode
          .appending(
            nodeView,
            withID: id
          )
      )

    case let .overlay(.sheet(overlayTree), coveredTree):
      return .overlay(
        .sheet(
          overlayTree
            .pushing(
              nodeView,
              withID: id
            )
        ),
        covering: coveredTree
      )

    case let .overlay(.overFullScreen(overlayTree), coveredTree):
      return .overlay(
        .overFullScreen(
          overlayTree
            .pushing(
              nodeView,
              withID: id
            )
        ),
        covering: coveredTree
      )
    }
  }

  @discardableResult
  internal func presenting(
    _ nodeView: any View,
    withID id: ViewNodeID,
    _ presentation: NavigationTreeOverlayPresentation
  ) -> NavigationTreeNode {
    switch presentation {
    case .sheet:
      return .overlay(
        .sheet(
          .just(
            id: id,
            view: nodeView
          )
        ),
        covering: self
      )
    case .overFullScreen:
      return .overlay(
        .overFullScreen(
          .just(
            id: id,
            view: nodeView
          )
        ),
        covering: self
      )
    }
  }

  @discardableResult
  internal func presenting(
    pushed nodeView: any View,
    withID id: ViewNodeID,
    _ presentation: NavigationTreeOverlayPresentation
  ) -> NavigationTreeNode {
    switch presentation {
    case .sheet:
      return .overlay(
        .sheet(
          .stack(
            .element(
              id: id,
              view: nodeView,
              next: .none
            )
          )
        ),
        covering: self
      )
    case .overFullScreen:
      return .overlay(
        .overFullScreen(
          .stack(
            .element(
              id: id,
              view: nodeView,
              next: .none
            )
          )
        ),
        covering: self
      )
    }
  }

  internal func removing(
    _ nodeID: ViewNodeID
  ) -> Self? {
    switch self {
    case let .just(id, _):
      if id == nodeID {
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

    case let .overlay(.sheet(overlayTree), coveredTree):
      if coveredTree.contains(nodeID) {
        return coveredTree.removing(nodeID)
      }
      else if let overlayTree: Self = overlayTree.removing(nodeID) {
        return .overlay(
          .sheet(overlayTree),
          covering: coveredTree
        )
      }
      else {
        return coveredTree
      }

    case let .overlay(.overFullScreen(overlayTree), coveredTree):
      if coveredTree.contains(nodeID) {
        return coveredTree.removing(nodeID)
      }
      else if let overlayTree: Self = overlayTree.removing(nodeID) {
        return .overlay(
          .overFullScreen(overlayTree),
          covering: coveredTree
        )
      }
      else {
        return coveredTree
      }
    }
  }

  internal func removing(
    upTo nodeID: ViewNodeID
  ) -> Self {
    switch self {
    case .just:
      // no matter what ID it has it will stay
      return self

    case let .stack(stackNode):
      return .stack(
        stackNode
          .prefix(including: nodeID)
      )

    case let .overlay(.sheet(overlayTree), coveredTree):
      if coveredTree.contains(nodeID) {
        return coveredTree.removing(upTo: nodeID)
      }
      else {
        return .overlay(
          .sheet(overlayTree.removing(upTo: nodeID)),
          covering: coveredTree
        )
      }

    case let .overlay(.overFullScreen(overlayTree), coveredTree):
      if coveredTree.contains(nodeID) {
        return coveredTree.removing(upTo: nodeID)
      }
      else {
        return .overlay(
          .overFullScreen(overlayTree.removing(upTo: nodeID)),
          covering: coveredTree
        )
      }
    }
  }

  internal func contains(
    _ nodeID: ViewNodeID
  ) -> Bool {
    switch self {
    case let .just(id, _):
      return id == nodeID

    case let .stack(stackNode):
      return stackNode.contains(nodeID)

    case let .overlay(.sheet(overlayTree), coveredTree):
      return overlayTree.contains(nodeID)
        || coveredTree.contains(nodeID)

    case let .overlay(.overFullScreen(overlayTree), coveredTree):
      return overlayTree.contains(nodeID)
        || coveredTree.contains(nodeID)
    }
  }
}
