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

@available(
  *,
  deprecated,
  message: "Please switch to `ViewController` and `ViewController` with `NavigationTo` from Display module"
)
internal indirect enum NavigationStackNode {

  case element(
    id: ViewNodeID,
    view: any View,
    next: NavigationStackNode?
  )
}

extension NavigationStackNode: Hashable {

  internal static func == (
    _ lhs: NavigationStackNode,
    _ rhs: NavigationStackNode
  ) -> Bool {
    if lhs.nodeID == rhs.nodeID {
      return lhs.next == rhs.next
    }
    else {
      return false
    }
  }

  internal func hash(
    into hasher: inout Hasher
  ) {
    hasher.combine(self.nodeID)
    hasher.combine(self.next)
  }
}

extension NavigationStackNode {

  internal var nodeID: ViewNodeID {
    switch self {
    case .element(let id, _, _):
      return id
    }
  }

  internal var nodeView: any View {
    switch self {
    case .element(let _, let nodeView, _):
      return nodeView
    }
  }

  internal var next: NavigationStackNode? {
    get {
      switch self {
      case .element(let _, _, let next):
        return next
      }
    }
    set {
      switch self {
      case .element(let id, let nodeView, _):
        self = .element(
          id: id,
          view: nodeView,
          next: newValue
        )
      }
    }
  }

  internal var last: NavigationStackNode {
    get {
      switch self {
      case .element(_, _, let next):
        return next?.last ?? self
      }
    }
    set {
      switch self {
      case .element(let id, let nodeView, .some(let next)):
        var next: NavigationStackNode = next
        next.last = newValue
        self = .element(
          id: id,
          view: nodeView,
          next: next
        )

      case .element(let id, let nodeView, .none):
        self = .element(
          id: id,
          view: nodeView,
          next: newValue
        )
      }
    }
  }

  internal func appending(
    _ view: any View,
    withID id: ViewNodeID
  ) -> Self {
    var copy: Self = self
    copy.last = .element(
      id: id,
      view: view,
      next: .none
    )
    return copy
  }

  internal func prefix(
    to nodeID: ViewNodeID
  ) -> NavigationStackNode? {
    guard self.nodeID != nodeID
    else { return .none }

    var stackPrefix: NavigationStackNode = .element(
      id: self.nodeID,
      view: self.nodeView,
      next: .none
    )

    var currentNode: NavigationStackNode = self
    while let nextNode: NavigationStackNode = currentNode.next {
      if nextNode.nodeID == nodeID {
        return stackPrefix
      }
      else {
        stackPrefix.last = .element(
          id: nextNode.nodeID,
          view: nextNode.nodeView,
          next: .none
        )
        currentNode = nextNode
      }
    }

    return stackPrefix
  }

  internal func prefix(
    including nodeID: ViewNodeID
  ) -> NavigationStackNode {
    var stackPrefix: NavigationStackNode = .element(
      id: self.nodeID,
      view: self.nodeView,
      next: .none
    )

    var currentNode: NavigationStackNode = self
    while currentNode.nodeID != nodeID {
      if let nextNode: NavigationStackNode = currentNode.next {
        stackPrefix.last = .element(
          id: nextNode.nodeID,
          view: nextNode.nodeView,
          next: .none
        )
        currentNode = nextNode
      }
      else {
        return stackPrefix
      }
    }

    return stackPrefix
  }

  internal func contains(
    _ nodeID: ViewNodeID
  ) -> Bool {
    if self.nodeID == nodeID {
      return true
    }
    else {
      return self
        .next?
        .contains(nodeID)
        ?? false
    }
  }
}
