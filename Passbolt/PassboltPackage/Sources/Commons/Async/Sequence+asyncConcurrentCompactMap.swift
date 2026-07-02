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

extension Sequence where Element: Sendable {

  /// Concurrent, order-preserving variant of `asyncCompactMap`.
  ///
  /// Runs at most `maximumConcurrentTasks` `transform` operations at a time using a sliding
  /// window over a task group, so the result order matches the input order regardless of the
  /// order in which individual operations complete. `nil` results are dropped, exactly like
  /// `asyncCompactMap`. With `maximumConcurrentTasks <= 1` it is equivalent to a sequential map.
  public func asyncConcurrentCompactMap<T: Sendable>(
    maximumConcurrentTasks: Int,
    _ transform: @escaping @Sendable (Element) async throws -> T?
  ) async throws -> Array<T> {
    let elements: Array<Element> = Array(self)
    let limit: Int = Swift.max(1, maximumConcurrentTasks)

    return try await withThrowingTaskGroup(of: (index: Int, value: T?).self) { group in
      var results: Array<T?> = Array(repeating: nil, count: elements.count)
      var nextIndex: Int = 0

      // Prime the window with up to `limit` operations.
      while nextIndex < elements.count, nextIndex < limit {
        let index: Int = nextIndex
        let element: Element = elements[index]
        group.addTask { (index, try await transform(element)) }
        nextIndex += 1
      }

      // As each operation finishes, record it (by original index) and enqueue the next one,
      // keeping at most `limit` operations in flight.
      while let completed: (index: Int, value: T?) = try await group.next() {
        results[completed.index] = completed.value
        if nextIndex < elements.count {
          let index: Int = nextIndex
          let element: Element = elements[index]
          group.addTask { (index, try await transform(element)) }
          nextIndex += 1
        }
      }

      return results.compactMap { $0 }
    }
  }
}
