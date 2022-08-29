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
import SwiftUI

public struct NavigationTreeRootView: View {

  private let navigationTree: NavigationTree

  public init(
    navigationTree: NavigationTree
  ) {
    self.navigationTree = navigationTree
  }

  public var body: some View {
    WithDisplayViewState(self.navigationTree.state) { (state: NavigationTreeNode) in
      self.viewFor(node: state)
    }
    .environment(\.isInNavigationTreeContext, true)
  }

  @ViewBuilder private func viewFor(
    node: NavigationTreeNode
  ) -> some View {
    switch node {
    case let .just(nodeView):
      nodeView
        .id(nodeView.nodeID)

    case let .stack(stackNode):
      NavigationView {
        self.viewFor(stackNode: stackNode)
      }
      .id(stackNode.nodeID)

    case let .overlay(overlayNode, covering: coveredNode):
      switch coveredNode {
      case let .just(nodeView):
        nodeView
          .sheet(
            isPresented: .init(
              get: { true },
              set: { active in
                assert(!active)
                self.navigationTree
                  .dismiss(overlayNode.id)
              }
            ),
            content: {
              switch overlayNode {
              case let .just(nodeView):
                nodeView
                  .id(nodeView.nodeID)

              case let .stack(stackNode):
                NavigationView {
                  self.viewFor(stackNode: stackNode)
                }
                .id(stackNode.nodeID)

              case .overlay:
                InternalInconsistency  // SwiftUI does not support it
                  .error("Cannot present more than one overlay navigation node")
                  .asFatalError()
              }
            }
          )
          .id(nodeView.nodeID)

      case let .stack(stackNode):
        NavigationView {
          self.viewFor(stackNode: stackNode)
        }
        .sheet(
          isPresented: .init(
            get: { true },
            set: { active in
              assert(!active)
              self.navigationTree
                .dismiss(overlayNode.id)
            }
          ),
          content: {
            switch overlayNode {
            case let .just(nodeView):
              nodeView
                .id(nodeView.nodeID)

            case let .stack(stackNode):
              NavigationView {
                self.viewFor(stackNode: stackNode)
              }
              .id(stackNode.nodeID)

            case .overlay:
              InternalInconsistency  // SwiftUI does not support it
                .error("Cannot present more than one overlay navigation node")
                .asFatalError()
            }
          }
        )
        .id(stackNode.nodeID)

      case .overlay:
        InternalInconsistency  // SwiftUI does not support it
          .error("Cannot present more than one overlay navigation node")
          .asFatalError()
      }
    }
  }

  @ViewBuilder private func viewFor(
    stackNode: NavigationStackNode
  ) -> some View {
    ZStack {
      NavigationLink(
        isActive: .init(
          get: {
            stackNode.next != .none
          },
          set: { active in
            assert(!active)
            guard let nodeID: NavigationNodeID = stackNode.next?.nodeID else { return }
            self.navigationTree
              .dismiss(nodeID)
          }
        ),
        destination: {
          if let nextNode: NavigationStackNode = stackNode.next {
            AnyView(self.viewFor(stackNode: nextNode))
              .id(nextNode.nodeID)
          }  // else no destination
        },
        label: EmptyView.init
      )
      .isDetailLink(false)
      stackNode.nodeView
    }
  }
}
