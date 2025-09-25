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

import XCTest

import struct Foundation.UUID

final class Collection_TopoSortTests: XCTestCase {
  func testLargeDatasetTree() {
    // create random test input
    var nodes: [Node] = []
    for _ in 0 ..< 1000 {
      nodes.append(.init(parentId: nodes.randomElement()?.id))
    }

    let input = nodes.shuffled()
    // created test data will be in right sorted order, ensure input is not sorted
    XCTAssertNotEqual(input, nodes, "Input should be shuffled")

    // sort
    let topoSorted = input.topoSort(idPath: \.id, parentIdPath: \.parentId)

    // verify if every node is after its parent
    for (index, node) in topoSorted.enumerated() {
      if let parentId = node.parentId {
        let parentIndex = topoSorted.firstIndex { $0.id == parentId }
        XCTAssertNotNil(parentIndex, "Parent should be in the collection")
        XCTAssertLessThan(parentIndex!, index, "Parent should be before the child")
      }
    }

    XCTAssertEqual(nodes.count, topoSorted.count, "Count of nodes should be the same")
  }

  func testGivenCyclicTree_shouldReturnEmptyCollection() {
    let aID: UUID = .init()
    let bID: UUID = .init()
    let cID: UUID = .init()
    let nodes = [Node(id: aID, parentId: cID), Node(id: bID, parentId: aID), Node(id: cID, parentId: bID)]

    let topoSorted = nodes.topoSort(idPath: \.id, parentIdPath: \.parentId)
    XCTAssertTrue(topoSorted.isEmpty, "Should return empty collection")
  }

  func testGivenNonExistingParent_shouldBeTreatedAsRoot() {
    let aID: UUID = .init()
    let bID: UUID = .init()
    let cID: UUID = .init()
    let nodes = [Node(id: aID, parentId: nil), Node(id: bID, parentId: .init()), Node(id: cID, parentId: bID)]

    let topoSorted = nodes.topoSort(idPath: \.id, parentIdPath: \.parentId)
    XCTAssertEqual(nodes.count, topoSorted.count, "Should return all items")
  }
}

private struct Node: Identifiable, Equatable {
  let id: UUID
  let parentId: UUID?

  init(id: UUID = .init(), parentId: UUID? = nil) {
    self.id = id
    self.parentId = parentId
  }
}
