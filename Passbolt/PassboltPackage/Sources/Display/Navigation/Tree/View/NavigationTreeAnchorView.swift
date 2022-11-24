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

import SwiftUI

extension View {

  public func erased() -> AnyView {
    AnyView(erasing: self)
  }
}

internal struct NavigationTreeAnchorView: View {

  internal let node: NavigationTreeNode
  @Environment(\.navigationTreeDismiss) private var dismissNode

  @ViewBuilder internal var nodeView: some View {
    switch node {
    case let .just(id, nodeView), let .overlay(_, covering: .just(id, nodeView)):
      nodeView
        .erased()
        .id(id)

    case let .stack(stackNode), let .overlay(_, covering: .stack(stackNode)):
      if #available(iOS 16.0, *) {
        #warning("TODO: use NavigationStack")
        NavigationView {
          NavigationStackAnchorView(
            node: stackNode
          )
        }
        .navigationViewStyle(.stack)
      }
      else {
        NavigationView {
          NavigationStackAnchorView(
            node: stackNode
          )
        }
        .navigationViewStyle(.stack)
      }

    case let .overlay(_, covering: .overlay(.sheet(overlayNode), covering: coveredNode)):
      NavigationTreeAnchorView(
        node: .overlay(
          .sheet(overlayNode),
          covering: coveredNode
        )
      )

    case let .overlay(_, covering: .overlay(.overFullScreen(overlayNode), covering: coveredNode)):
      NavigationTreeAnchorView(
        node: .overlay(
          .overFullScreen(overlayNode),
          covering: coveredNode
        )
      )
    }
  }

  internal var nodeOverlay: NavigationTreeOverlay? {
    switch node {
    case .just, .stack:
      return .none

    case let .overlay(overlay, covering: _):
      return overlay
    }
  }

  @ViewBuilder internal var body: some View {
    let overlay: NavigationTreeOverlay? = self.nodeOverlay
    self.nodeView
      .fullScreenCover(
        item: .init(
          get: { overlay?.overFullScreenNode },
          set: { _ in
            guard let overlayNodeID: NavigationNodeID = overlay?.nodeID
            else { return }
            self.dismissNode?(overlayNodeID)
          }
        ),
        content: { (overlayNode: NavigationTreeNode) in
          NavigationTreeAnchorView(
            node: overlayNode
          )
        }
      )
      .sheet(
        item: .init(
          get: { overlay?.sheetNode },
          set: { _ in
            guard let overlayNodeID: NavigationNodeID = overlay?.nodeID
            else { return }
            self.dismissNode?(overlayNodeID)
          }
        ),
        content: { (overlayNode: NavigationTreeNode) in
          NavigationTreeAnchorView(
            node: overlayNode
          )
        }
      )
  }
}

internal struct NavigationStackAnchorView: View {

  internal let node: NavigationStackNode
  internal var nextNode: NavigationStackNode? { self.node.next }
  @Environment(\.navigationTreeDismiss) private var dismissNode

  internal var body: some View {
    ZStack {
      NavigationLink(
        isActive: .init(
          get: { self.nextNode != .none },
          set: { active in
            assert(!active)
            guard let nodeID: NavigationNodeID = self.nextNode?.nodeID
            else { return }
            self.dismissNode?(nodeID)
          }
        ),
        destination: {
          if let nextNode: NavigationStackNode = nextNode {
            NavigationStackAnchorView(
              node: nextNode
            )
          }  // else no destination
        },
        label: EmptyView.init
      )
      .isDetailLink(false)

      self.node
        .nodeView
        .erased()
        .id(self.node.nodeID)
    }
  }
}
