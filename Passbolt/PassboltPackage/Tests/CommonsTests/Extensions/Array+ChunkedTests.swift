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

@testable import Commons

final class Array_ChunkedTests: XCTestCase {

  func test_chunked_exactMultiple_splitsIntoEqualChunks() {
    let input: Array<Int> = [1, 2, 3, 4, 5, 6]
    let result: Array<Array<Int>> = input.chunked(into: 2).map { Array($0) }
    XCTAssertEqual(result, [[1, 2], [3, 4], [5, 6]])
  }

  func test_chunked_withRemainder_lastChunkIsSmaller() {
    let input: Array<Int> = [1, 2, 3, 4, 5]
    let result: Array<Array<Int>> = input.chunked(into: 2).map { Array($0) }
    XCTAssertEqual(result, [[1, 2], [3, 4], [5]])
  }

  func test_chunked_sizeLargerThanCount_returnsSingleChunk() {
    let input: Array<Int> = [1, 2, 3]
    let result: Array<Array<Int>> = input.chunked(into: 10).map { Array($0) }
    XCTAssertEqual(result, [[1, 2, 3]])
  }

  func test_chunked_sizeOfOne_returnsSingleElementChunks() {
    let input: Array<Int> = [1, 2, 3]
    let result: Array<Array<Int>> = input.chunked(into: 1).map { Array($0) }
    XCTAssertEqual(result, [[1], [2], [3]])
  }

  func test_chunked_emptyArray_returnsEmpty() {
    let input: Array<Int> = .init()
    let result: Array<ArraySlice<Int>> = input.chunked(into: 3)
    XCTAssertTrue(result.isEmpty)
  }

  func test_chunked_zeroSize_returnsEmpty() {
    let input: Array<Int> = [1, 2, 3]
    let result: Array<ArraySlice<Int>> = input.chunked(into: 0)
    XCTAssertTrue(result.isEmpty)
  }

  func test_chunked_negativeSize_returnsEmpty() {
    let input: Array<Int> = [1, 2, 3]
    let result: Array<ArraySlice<Int>> = input.chunked(into: -5)
    XCTAssertTrue(result.isEmpty)
  }

  func test_chunked_preservesOrderAndCompleteness_whenCrossingChunkBoundaries() {
    // Mirrors the batched-statement usage in ResourcesStoreDatabaseOperation, where a large input
    // is split into chunks of 256: no element may be lost, duplicated, or reordered.
    let batchSize: Int = 256
    let input: Array<Int> = Array(0 ..< 1000)
    let chunks: Array<ArraySlice<Int>> = input.chunked(into: batchSize)

    XCTAssertEqual(chunks.count, 4)
    XCTAssertEqual(chunks.map(\.count), [256, 256, 256, 232])
    XCTAssertEqual(chunks.flatMap { $0 }, input)
  }
}
