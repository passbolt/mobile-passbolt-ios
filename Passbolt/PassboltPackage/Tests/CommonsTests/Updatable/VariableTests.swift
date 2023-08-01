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
import CoreTest

final class VariableTests: TestCase {

  func test_value_returnsImmediately() {
    verifyIf(
      Variable<Int>(initial: 42).value,
      isEqual: 42
    )
  }

  func test_value_isTheSameAsInLastUpdate() {
    let variable: Variable<Int> = .init(initial: 42)
    verifyIf(
      variable.value,
      isEqual: try! variable.lastUpdate.value
    )
  }

  func test_value_updates_afterUpdate() {
    let variable: Variable<Int> = .init(initial: 42)
    variable.assign(99)
    verifyIf(
      variable.value,
      isEqual: 99
    )
    variable.value += 1
    verifyIf(
      variable.value,
      isEqual: 100
    )
    variable.mutate { value in
      value = 0
    }
    verifyIf(
      variable.value,
      isEqual: 0
    )
  }

  func test_generation_isInitializedInitially() {
    let variable: Variable<Int> = .init(initial: 42)
    verifyIf(
      variable.generation,
      isGreaterThan: .uninitialized
    )
  }

  func test_generation_isTheSameAsInLastUpdate() {
    let variable: Variable<Int> = .init(initial: 42)
    verifyIf(
      variable.generation,
      isEqual: variable.lastUpdate.generation
    )
  }

  func test_generation_grows_afterUpdate() {
    let variable: Variable<Int> = .init(initial: 42)
    let firstGeneration: UpdateGeneration = variable.generation
    variable.assign(99)
    let secondGeneration: UpdateGeneration = variable.generation
    verifyIf(
      secondGeneration,
      isGreaterThan: firstGeneration
    )
    variable.value += 1
    let thirdGeneration: UpdateGeneration = variable.generation
    verifyIf(
      thirdGeneration,
      isGreaterThan: secondGeneration
    )
    variable.mutate { value in
      value = 0
    }
    let fourthGeneration: UpdateGeneration = variable.generation
    verifyIf(
      fourthGeneration,
      isGreaterThan: thirdGeneration
    )
  }

  func test_notify_waitsForNextUpdate_whenRequestedWithCurrentGeneration() async throws {
    let variable: Variable<Int> = .init(initial: 42)
    let initialGeneration: UpdateGeneration = variable.generation
    try await withSerialTaskExecutor {
      Task.detached { variable.assign(11) }
      let update: Update<Int> = try await variable.notify(after: initialGeneration)
      await verifyIf(
        update.generation,
        isGreaterThan: initialGeneration
      )

      await verifyIf(
        try update.value,
        isEqual: 11
      )
    }
  }

  func test_notify_resumesAllWaitingFutures_whenUpdated() async throws {
    let variable: Variable<Int> = .init(initial: 42)
    let initialGeneration: UpdateGeneration = variable.generation
    let update: Update<Int> = try await withSerialTaskExecutor {
      try await withThrowingTaskGroup(of: Update<Int>.self) { group in
        for _ in 0 ..< 10 {
          group.addTask {
            try await variable.notify(after: initialGeneration)
          }
        }
        Task.detached { variable.assign(11) }
        let result: Update<Int> = try await group.next()!
        try await group.waitForAll()
        return result
      }
    }
    await verifyIf(
      update.generation,
      isGreaterThan: initialGeneration
    )
    await verifyIf(
      try update.value,
      isEqual: 11
    )
  }

  func test_notify_throwsCancelled_whenWaitingTaskIsCancelled() async throws {
    let variable: Variable<Int> = .init(initial: 42)
    try await withSerialTaskExecutor {
      let task: Task<Void, Error> = .detached {
        _ = try await variable.notify(after: variable.generation)
      }
      Task.detached { task.cancel() }
      await verifyIf(
        try await task.value,
        throws: Cancelled.self
      )
    }
  }

  func test_assign_executesWithoutIssues_concurrently() async throws {
    let variable: Variable<Int> = .init(initial: 42)
    await withTaskGroup(of: Void.self) { group in
      for _ in 0 ..< 10 {
        group.addTask {
          for i in 0 ..< 1_000 {
            variable.assign(i)
          }
        }
      }
      await group.waitForAll()
    }
  }

  func test_mutate_executesWithoutIssues_concurrently() async throws {
    let variable: Variable<Int> = .init(initial: 42)
    await withTaskGroup(of: Void.self) { group in
      for _ in 0 ..< 10 {
        group.addTask {
          for i in 0 ..< 1_000 {
            variable.mutate { $0 = i }
          }
        }
      }
      await group.waitForAll()
    }
  }

  func test_mutation_executesWithoutIssues_concurrently() async throws {
    let variable: Variable<Int> = .init(initial: 42)
    await withTaskGroup(of: Void.self) { group in
      for _ in 0 ..< 10 {
        group.addTask {
          for i in 0 ..< 1_000 {
            variable.value += i
          }
        }
      }
      await group.waitForAll()
    }
  }

  func test_value_executesWithoutIssues_concurrently() async throws {
    let variable: Variable<Int> = .init(initial: 42)
    await withTaskGroup(of: Void.self) { group in
      for _ in 0 ..< 10 {
        group.addTask {
          for _ in 0 ..< 1_000 {
            _ = variable.value
          }
        }
      }
      await group.waitForAll()
    }
  }

  func test_continuousAccess_executesWithoutIssues_concurrently() async throws {
    let variable: Variable<Int> = .init(initial: 42)
    await withTaskGroup(of: Void.self) { group in
      for i in 0 ..< 20 {
        if i.isMultiple(of: 2) {
          group.addTask {
            for j in 0 ..< 1_000 {
              variable.value += j
            }
          }
        }
        else {
          group.addTask {
            for _ in 0 ..< 1_000 {
              _ = variable.value
            }
          }
        }
      }
      await group.waitForAll()
    }
  }
}
