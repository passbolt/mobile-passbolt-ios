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

extension Collection {
  /// Topologically sort a collection of elements.
  /// - Parameters:
  ///  - idPath: The key path to the element's identifier.
  ///  - parentIdPath: The key path to the element's parent identifier.
  ///  - Returns: The sorted elements.
  ///
  ///  Sorts the elements in the collection based on their parent-child relationships - children will have higher indices than parents. Supports multiple roots, but for node can have only one parent.
  public func topoSort<ID>(idPath: KeyPath<Element, ID>, parentIdPath: KeyPath<Element, ID?>) -> [Element]
  where ID: Hashable {
    let wrappedElements: [Wrapper] = map { Wrapper(node: $0) }
    var wrappedElementsByKey: [ID: Wrapper<Element>] = [:]
    for wrapper in wrappedElements {
      let id = wrapper.node[keyPath: idPath]
      wrappedElementsByKey[id] = wrapper
    }

    for wrapper in wrappedElementsByKey.values {
      if let parentId = wrapper.node[keyPath: parentIdPath], let parent = wrappedElementsByKey[parentId] {
        parent.addChild(wrapper)
      }
    }

    let roots = wrappedElementsByKey.values.filter { $0.parent == nil }
    return roots.reduce(into: []) { acc, root in
      acc.append(contentsOf: root.sorted())
    }
  }
}

private class Wrapper<Element> {
  let node: Element
  private(set) weak var parent: Wrapper?
  private(set) var children: [Wrapper] = []

  init(node: Element) {
    self.node = node
  }

  func addChild(_ child: Wrapper) {
    children.append(child)
    child.parent = self
  }

  func sorted() -> [Element] {
    children.reduce(into: [node]) { acc, child in
      acc.append(contentsOf: child.sorted())
    }
  }
}
