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

internal struct NavigationTreeAnchorView: View {

  internal let node: NavigationTreeNode
  internal let dismissNode: @Sendable (NavigationNodeID) -> Void

  @ViewBuilder internal var nodeView: some View {
    switch node {
    case let .just(nodeView), let .overlay(_, covering: .just(nodeView)):
      nodeView

    case let .stack(stackNode), let .overlay(_, covering: .stack(stackNode)):
      if #available(iOS 16.0, *) {
        #warning("TODO: use NavigationStack")
        NavigationView {
          NavigationStackAnchorView(
            node: stackNode,
            dismissNode: self.dismissNode
          )
        }
        .navigationViewStyle(.stack)
      }
      else {
        NavigationView {
          NavigationStackAnchorView(
            node: stackNode,
            dismissNode: self.dismissNode
          )
        }
        .navigationViewStyle(.stack)
      }

    case let .overlay(_, covering: .overlay(overlayNode, covering: coveredNode)):
      NavigationTreeAnchorView(
        node: .overlay(
          overlayNode,
          covering: coveredNode
        ),
        dismissNode: self.dismissNode
      )
    }
  }

  internal var nodeOverlay: NavigationTreeNode? {
    switch node {
    case .just, .stack:
      return .none

    case let .overlay(overlayNode, covering: _):
      return overlayNode
    }
  }

  @ViewBuilder internal var body: some View {
    let overlayNode: NavigationTreeNode? = self.nodeOverlay
    self.nodeView
      .sheet(
        item: .init(
          get: { overlayNode },
          set: { _ in
            guard let overlayNodeID: NavigationNodeID = overlayNode?.id
            else { return }
            self.dismissNode(overlayNodeID)
          }
        ),
        content: { overlayNode in
          NavigationTreeAnchorView(
            node: overlayNode,
            dismissNode: self.dismissNode
          )
          .environment(
            \.navigationTreeDismiss,
            {
              self.dismissNode(overlayNode.id)
            }
          )
        }
      )
  }
}

internal struct NavigationStackAnchorView: View {

  internal let node: NavigationStackNode
  internal var nextNode: NavigationStackNode? { self.node.next }
  internal let dismissNode: @Sendable (NavigationNodeID) -> Void

  internal var body: some View {
    ZStack {
      NavigationLink(
        isActive: .init(
          get: { self.nextNode != .none },
          set: { active in
            assert(!active)
            guard let nodeID: NavigationNodeID = self.nextNode?.nodeID
            else { return }
            dismissNode(nodeID)
          }
        ),
        destination: {
          if let nextNode: NavigationStackNode = nextNode {
            NavigationStackAnchorView(
              node: nextNode,
              dismissNode: self.dismissNode
            )
            .environment(
              \.navigationTreeBack,
              {
                self.dismissNode(nextNode.nodeID)
              }
            )
          }  // else no destination
        },
        label: EmptyView.init
      )
      .isDetailLink(false)
      self.node.nodeView
    }
  }
}
