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

// swift-format-ignore: AlwaysUseLowerCamelCase
final class Sequence_asyncConcurrentCompactMapTests: XCTestCase {

  func test_asyncConcurrentCompactMap_preservesInputOrder_whenTasksCompleteOutOfOrder() async throws {
    let count: Int = 5
    let gate: IndexGate = .init()

    // Kick off the last element first; each completing operation then releases its predecessor,
    // so operations finish in strict reverse order (4, 3, 2, 1, 0) while inputs are 0...4.
    // The gate remembers releases, so releasing before the operation waits is safe.
    await gate.release(count - 1)

    let result: [Int] = try await (0 ..< count)
      .asyncConcurrentCompactMap(maximumConcurrentTasks: count) {
        index in
        await gate.wait(index)
        if index > 0 {
          await gate.release(index - 1)
        }
        return index * 10
      }

    XCTAssertEqual(result, [0, 10, 20, 30, 40])
  }

  func test_asyncConcurrentCompactMap_respectsMaximumConcurrentTasks_whenInputExceedsLimit() async throws {
    let limit: Int = 3
    let total: Int = 7
    let tracker: ConcurrencyTracker = .init()
    // Holds the first `limit` operations until all `limit` are simultaneously in flight,
    // guaranteeing the window fills exactly to the limit and never beyond.
    let barrier: ArrivalBarrier = .init(threshold: limit)

    let result: [Int] = try await (0 ..< total)
      .asyncConcurrentCompactMap(maximumConcurrentTasks: limit) {
        index in
        await tracker.enter()
        await barrier.arrive()
        await tracker.leave()
        return index
      }

    let peak: Int = await tracker.peak
    XCTAssertEqual(result, Array(0 ..< total))
    XCTAssertEqual(peak, limit)
  }

  func test_asyncConcurrentCompactMap_dropsNilResults_keepingOrder() async throws {
    let result: [Int] = try await (0 ..< 6)
      .asyncConcurrentCompactMap(maximumConcurrentTasks: 3) {
        index in
        index.isMultiple(of: 2) ? index : nil
      }

    XCTAssertEqual(result, [0, 2, 4])
  }

  func test_asyncConcurrentCompactMap_propagatesError_whenTransformThrows() async throws {
    struct TransformFailure: Error {}

    do {
      _ = try await (0 ..< 5)
        .asyncConcurrentCompactMap(maximumConcurrentTasks: 2) {
          index in
          if index == 3 {
            throw TransformFailure()
          }
          return index
        }
      XCTFail("Expected asyncConcurrentCompactMap to rethrow the transform error.")
    }
    catch is TransformFailure {
      // expected
    }
  }

  func test_asyncConcurrentCompactMap_returnsEmpty_forEmptyInput() async throws {
    let result: [Int] = try await (0 ..< 0)
      .asyncConcurrentCompactMap(maximumConcurrentTasks: 4) {
        index in index
      }

    XCTAssertEqual(result, [])
  }

  func test_asyncConcurrentCompactMap_mapsSingleElement() async throws {
    let result: [Int] = try await [42]
      .asyncConcurrentCompactMap(maximumConcurrentTasks: 4) {
        element in element * 2
      }

    XCTAssertEqual(result, [84])
  }

  func test_asyncConcurrentCompactMap_behavesSequentially_whenLimitIsOneOrLess() async throws {
    let sequential: [Int] = try await (0 ..< 5)
      .asyncConcurrentCompactMap(maximumConcurrentTasks: 1) {
        index in index
      }
    XCTAssertEqual(sequential, [0, 1, 2, 3, 4])

    // A non-positive limit is clamped to 1 (still a valid sequential map, no crash).
    let clamped: [Int] = try await (0 ..< 5)
      .asyncConcurrentCompactMap(maximumConcurrentTasks: 0) {
        index in index
      }
    XCTAssertEqual(clamped, [0, 1, 2, 3, 4])
  }
}

/// Per-index suspension gate. `wait(_:)` suspends until the matching `release(_:)`; a release that
/// arrives before its `wait` is remembered so the later `wait` returns immediately (no deadlock).
private actor IndexGate {

  private var released: Set<Int> = .init()
  private var waiters: [Int: CheckedContinuation<Void, Never>] = .init()

  func wait(_ index: Int) async {
    if self.released.contains(index) {
      return
    }
    await withCheckedContinuation { continuation in
      self.waiters[index] = continuation
    }
  }

  func release(_ index: Int) {
    self.released.insert(index)
    if let continuation: CheckedContinuation<Void, Never> = self.waiters.removeValue(forKey: index) {
      continuation.resume()
    }
  }
}

/// Tracks the number of concurrently active operations and the peak observed.
private actor ConcurrencyTracker {

  private var current: Int = 0
  private(set) var peak: Int = 0

  func enter() {
    self.current += 1
    self.peak = Swift.max(self.peak, self.current)
  }

  func leave() {
    self.current -= 1
  }
}

/// Suspends every caller until `threshold` callers have arrived, then lets all of them (and any
/// later arrivals) proceed. Used to force a known number of operations to overlap.
private actor ArrivalBarrier {

  private let threshold: Int
  private var arrived: Int = 0
  private var isOpen: Bool = false
  private var waiters: [CheckedContinuation<Void, Never>] = .init()

  init(threshold: Int) {
    self.threshold = threshold
  }

  func arrive() async {
    self.arrived += 1
    if self.arrived >= self.threshold {
      self.isOpen = true
      for waiter in self.waiters {
        waiter.resume()
      }
      self.waiters.removeAll()
    }
    if self.isOpen {
      return
    }
    await withCheckedContinuation { continuation in
      self.waiters.append(continuation)
    }
  }
}
