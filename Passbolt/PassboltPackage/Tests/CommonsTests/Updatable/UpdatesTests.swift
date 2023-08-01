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

final class UpdatesTests: TestCase {

  func test_value_returnsImmediately() {
    _ = Updates().value
  }

  func test_generation_isInitializedInitially() {
    let updates: Updates = .init()
    verifyIf(
      updates.generation,
      isGreaterThan: .uninitialized
    )
  }

  func test_generation_isTheSameAsInLastUpdate() {
    let updates: Updates = .init()
    verifyIf(
      updates.generation,
      isEqual: updates.lastUpdate.generation
    )
  }

  func test_generation_grows_afterUpdate() {
    let updates: Updates = .init()
    let firstGeneration: UpdateGeneration = updates.generation
    updates.update()
    let secondGeneration: UpdateGeneration = updates.generation
    verifyIf(
      secondGeneration,
      isGreaterThan: firstGeneration
    )
    updates.update()
    let thirdGeneration: UpdateGeneration = updates.generation
    verifyIf(
      thirdGeneration,
      isGreaterThan: secondGeneration
    )
    updates.update()
    let fourthGeneration: UpdateGeneration = updates.generation
    verifyIf(
      fourthGeneration,
      isGreaterThan: thirdGeneration
    )
  }

  func test_notify_waitsForNextUpdate_whenRequestedWithCurrentGeneration() async throws {
    let updates: Updates = .init()
    let initialGeneration: UpdateGeneration = updates.generation
    try await withSerialTaskExecutor {
      Task.detached { updates.update() }
      let update: Update<Void> = try await updates.notify(after: initialGeneration)
      await verifyIf(
        update.generation,
        isGreaterThan: initialGeneration
      )
    }
  }

  func test_notify_resumesAllWaitingFutures_whenUpdated() async throws {
    let updates: Updates = .init()
    let initialGeneration: UpdateGeneration = updates.generation
    let generation: UpdateGeneration = try await withSerialTaskExecutor {
      try await withThrowingTaskGroup(of: UpdateGeneration.self) { group in
        for _ in 0 ..< 10 {
          group.addTask {
            try await updates.notify(after: initialGeneration).generation
          }
        }
        Task.detached { updates.update() }
        let result: UpdateGeneration = try await group.next() ?? .uninitialized
        try await group.waitForAll()
        return result
      }
    }
    await verifyIf(
      generation,
      isGreaterThan: initialGeneration
    )
  }

  func test_notify_throwsCancelled_whenWaitingTaskIsCancelled() async throws {
    let updates: Updates = .init()
    try await withSerialTaskExecutor {
      let task: Task<Void, Error> = .detached {
        _ = try await updates.notify(after: updates.generation)
      }
      Task.detached { task.cancel() }
      await verifyIf(
        try await task.value,
        throws: Cancelled.self
      )
    }
  }

  func test_update_executesWithoutIssues_concurrently() async throws {
    let updates: Updates = .init()
    await withTaskGroup(of: Void.self) { group in
      for _ in 0 ..< 10 {
        group.addTask {
          for _ in 0 ..< 1_000 {
            updates.update()
          }
        }
      }
      await group.waitForAll()
    }
  }

  func test_value_executesWithoutIssues_concurrently() async throws {
    let updates: Updates = .init()
    await withTaskGroup(of: Void.self) { group in
      for _ in 0 ..< 10 {
        group.addTask {
          for _ in 0 ..< 1_000 {
            updates.value
          }
        }
      }
      await group.waitForAll()
    }
  }

  func test_continuousAccess_executesWithoutIssues_concurrently() async throws {
    let updates: Updates = .init()
    await withTaskGroup(of: Void.self) { group in
      for i in 0 ..< 20 {
        if i.isMultiple(of: 2) {
          group.addTask {
            for _ in 0 ..< 1_000 {
              updates.update()
            }
          }
        }
        else {
          group.addTask {
            for _ in 0 ..< 1_000 {
              updates.value
            }
          }
        }
      }
      await group.waitForAll()
    }
  }
}
