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

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseForceTry, NeverForceUnwrap
final class PatchableVariableTests: TestCase {

  func test_value_returnsTransformedSourceValue() async {
    let source: Variable<Int> = .init(initial: 42)
    let variable: PatchableVariable = .init(
      updatingFrom: source
    ) { (current: Update<String>, update: Update<Int>) throws -> String in
      try String(update.value)
    }
    await verifyIf(
      try await variable.value,
      isEqual: "42"
    )
  }

  func test_value_isTheSameAsInLastUpdate() async {
    let source: Variable<Int> = .init(initial: 42)
    let variable: PatchableVariable = .init(
      updatingFrom: source
    ) { (current: Update<String>, update: Update<Int>) throws -> String in
      try String(update.value)
    }
    await verifyIf(
      try await variable.value,
      isEqual: try! variable.lastUpdate.value
    )
  }

  func test_value_updates_afterSourceUpdate() async {
    let source: Variable<Int> = .init(initial: 42)
    let variable: PatchableVariable = .init(
      updatingFrom: source
    ) { (current: Update<String>, update: Update<Int>) throws -> String in
      try String(update.value)
    }
    source.assign(99)
    await verifyIf(
      try await variable.value,
      isEqual: "99"
    )
    source.value += 1
    await verifyIf(
      try await variable.value,
      isEqual: "100"
    )
    source.mutate { value in
      value = 0
    }
    await verifyIf(
      try await variable.value,
      isEqual: "0"
    )
  }

  func test_value_updates_afterPatch() async {
    let source: Variable<Int> = .init(initial: 42)
    let variable: PatchableVariable = .init(
      updatingFrom: source
    ) { (current: Update<String>, update: Update<Int>) throws -> String in
      try String(update.value)
    }
    await variable.patch { (current: Update<String>) -> String in
      try current.value + "_updated"
    }
    await verifyIf(
      try await variable.value,
      isEqual: "42_updated"
    )
    await variable.patch { (current: Update<String>) -> String in
      try current.value + "_updated"
    }
    await verifyIf(
      try await variable.value,
      isEqual: "42_updated_updated"
    )
  }

  func test_value_transform_executesWhenRequested() async {
    let source: Variable<Int> = .init(initial: 42)
    let counter: SendableCounter = .init()
    let variable: PatchableVariable = .init(
      updatingFrom: source
    ) { (current: Update<String>, update: Update<Int>) throws -> String in
      counter.increment()
      return try String(update.value)
    }
    await verifyIf(
      counter.value,
      isEqual: 0
    )
    source.assign(99)
    await verifyIf(
      counter.value,
      isEqual: 0
    )
    source.value += 1
    await verifyIf(
      counter.value,
      isEqual: 0
    )
    source.mutate { value in
      value = 0
    }
    await verifyIf(
      try await variable.value,
      isEqual: "0"
    )
    await verifyIf(
      counter.value,
      isEqual: 1
    )
  }

  func test_generation_isGreatherThanOrEqualSourceGeneration() async {
    let source: Variable<Int> = .init(initial: 42)
    let variable: PatchableVariable = .init(
      updatingFrom: source
    ) { (current: Update<String>, update: Update<Int>) throws -> String in
      try String(update.value)
    }
    await verifyIf(
      variable.generation,
      isEqual: source.generation
    )
    await variable.patch { (current: Update<String>) -> String in
      try current.value + "_updated"
    }
    await verifyIf(
      variable.generation,
      isGreaterThan: source.generation
    )
    source.assign(99)
    await verifyIf(
      variable.generation,
      isEqual: source.generation
    )
    await variable.patch { (current: Update<String>) -> String in
      try current.value + "_updated"
    }
    await verifyIf(
      variable.generation,
      isGreaterThan: source.generation
    )
    source.assign(11)
    await verifyIf(
      variable.generation,
      isEqual: source.generation
    )
  }

  func test_generation_isTheSameAsInLastUpdate() async {
    let source: Variable<Int> = .init(initial: 42)
    let variable: PatchableVariable = .init(
      updatingFrom: source
    ) { (current: Update<String>, update: Update<Int>) throws -> String in
      try String(update.value)
    }
    await verifyIf(
      try await variable.lastUpdate.generation,
      isEqual: variable.generation
    )
  }

  func test_generation_grows_afterSourceUpdate() async {
    let source: Variable<Int> = .init(initial: 42)
    let variable: PatchableVariable = .init(
      updatingFrom: source
    ) { (current: Update<String>, update: Update<Int>) throws -> String in
      try String(update.value)
    }
    let firstGeneration: UpdateGeneration = variable.generation
    source.assign(99)
    let secondGeneration: UpdateGeneration = variable.generation
    await verifyIf(
      secondGeneration,
      isGreaterThan: firstGeneration
    )
    source.value += 1
    let thirdGeneration: UpdateGeneration = variable.generation
    await verifyIf(
      thirdGeneration,
      isGreaterThan: secondGeneration
    )
    source.mutate { value in
      value = 0
    }
    let fourthGeneration: UpdateGeneration = variable.generation
    await verifyIf(
      fourthGeneration,
      isGreaterThan: thirdGeneration
    )
  }

  func test_generation_grows_afterPatch() async {
    let source: Variable<Int> = .init(initial: 42)
    let variable: PatchableVariable = .init(
      updatingFrom: source
    ) { (current: Update<String>, update: Update<Int>) throws -> String in
      try String(update.value)
    }
    let firstGeneration: UpdateGeneration = variable.generation
    await variable.patch { (current: Update<String>) -> String in
      try current.value + "_updated"
    }
    let secondGeneration: UpdateGeneration = variable.generation
    await verifyIf(
      secondGeneration,
      isGreaterThan: firstGeneration
    )
    await variable.patch { (current: Update<String>) -> String in
      try current.value + "_updated"
    }
    let thirdGeneration: UpdateGeneration = variable.generation
    await verifyIf(
      thirdGeneration,
      isGreaterThan: secondGeneration
    )
    await variable.patch { (current: Update<String>) -> String in
      try current.value + "_updated"
    }
    let fourthGeneration: UpdateGeneration = variable.generation
    await verifyIf(
      fourthGeneration,
      isGreaterThan: thirdGeneration
    )
  }

  func test_notify_waitsForNextUpdate_whenRequestedWithCurrentGeneration() async throws {
    let source: Variable<Int> = .init(initial: 42)
    let variable: PatchableVariable = .init(
      updatingFrom: source
    ) { (current: Update<String>, update: Update<Int>) throws -> String in
      try String(update.value)
    }
    _ = try? await variable.lastUpdate  // resolve initially to ensure waiting later
    let initialGeneration: UpdateGeneration = variable.generation
    try await withSerialTaskExecutor {
      Task.detached {
        await Task.yield()
        source.assign(11)
      }
      let update: Update<String> = try await variable.notify(after: initialGeneration)
      await verifyIf(
        update.generation,
        isGreaterThan: initialGeneration
      )

      await verifyIf(
        try update.value,
        isEqual: "11"
      )
    }

    let updatedGeneration: UpdateGeneration = variable.generation
    try await withSerialTaskExecutor {
      Task.detached {
        await Task.yield()
        await variable.patch { (current: Update<String>) -> String in
          try current.value + "_updated"
        }
      }
      let update: Update<String> = try await variable.notify(after: updatedGeneration)
      await verifyIf(
        update.generation,
        isGreaterThan: updatedGeneration
      )

      await verifyIf(
        try update.value,
        isEqual: "11_updated"
      )
    }
  }

  func test_notify_resumesAllWaitingFutures_whenSourceUpdates() async throws {
    let source: Variable<Int> = .init(initial: 42)
    let variable: PatchableVariable = .init(
      updatingFrom: source
    ) { (current: Update<String>, update: Update<Int>) throws -> String in
      try String(update.value)
    }
    _ = try? await variable.lastUpdate  // resolve initially to ensure waiting later
    let initialGeneration: UpdateGeneration = variable.generation
    let update: Update<String> = try await withSerialTaskExecutor {
      try await withThrowingTaskGroup(of: Update<String>.self) { group in
        for _ in 0 ..< 10 {
          group.addTask {
            try await variable.notify(after: initialGeneration)
          }
        }
        Task.detached {
          source.assign(11)
        }
        let result: Update<String> = try await group.next()!
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
      isEqual: "11"
    )
  }

  func test_notify_resumesAllWaitingFutures_whenPatched() async throws {
    let source: Variable<Int> = .init(initial: 42)
    let variable: PatchableVariable = .init(
      updatingFrom: source
    ) { (current: Update<String>, update: Update<Int>) throws -> String in
      try String(update.value)
    }
    _ = try? await variable.lastUpdate  // resolve initially to ensure waiting later
    let initialGeneration: UpdateGeneration = variable.generation
    let update: Update<String> = try await withSerialTaskExecutor {
      try await withThrowingTaskGroup(of: Update<String>.self) { group in
        for _ in 0 ..< 10 {
          group.addTask {
            try await variable.notify(after: initialGeneration)
          }
        }
        Task.detached {
          await variable.patch { (current: Update<String>) -> String in
            try current.value + "_updated"
          }
        }
        let result: Update<String> = try await group.next()!
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
      isEqual: "42_updated"
    )
  }

  func test_notify_throwsCancelled_whenWaitingTaskIsCancelled() async throws {
    let source: Variable<Int> = .init(initial: 42)
    let variable: PatchableVariable = .init(
      updatingFrom: source
    ) { (current: Update<String>, update: Update<Int>) throws -> String in
      try String(update.value)
    }
    _ = try? await variable.lastUpdate  // resolve initially to ensure waiting later
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

  func test_sourceUpdates_executesWithoutIssues_concurrently() async throws {
    let source: Variable<Int> = .init(initial: 42)
    let variable: PatchableVariable = .init(
      updatingFrom: source
    ) { (current: Update<String>, update: Update<Int>) throws -> String in
      try String(update.value)
    }
    await withTaskGroup(of: Void.self) { group in
      for _ in 0 ..< 10 {
        group.addTask {
          for i in 0 ..< 1_000 {
            source.assign(i)
          }
        }
      }
      await group.waitForAll()
    }
    _ = try await variable.value
  }

  func test_patches_executesWithoutIssues_concurrently() async throws {
    let source: Variable<Int> = .init(initial: 42)
    let variable: PatchableVariable = .init(
      updatingFrom: source
    ) { (current: Update<String>, update: Update<Int>) throws -> String in
      try String(update.value)
    }
    await withTaskGroup(of: Void.self) { group in
      for _ in 0 ..< 10 {
        group.addTask {
          for i in 0 ..< 1_000 {
            await variable.patch { (current: Update<String>) -> String in
              try current.value + "\(i)"
            }
          }
        }
      }
      await group.waitForAll()
    }
    _ = try await variable.value
  }

  func test_patch_isIgnored_whenSourceUpdates() async throws {
    let source: Variable<Int> = .init(initial: 42)
    let variable: PatchableVariable = .init(
      updatingFrom: source
    ) { (current: Update<String>, update: Update<Int>) throws -> String in
      try String(update.value)
    }
    let initialGeneration: UpdateGeneration = variable.generation
    try await withSerialTaskExecutor {
      Task.detached {
        await variable.patch { (current: Update<String>) -> String in
          await Task.yield()
          return try current.value + "_updated"
        }
      }
      Task.detached { source.assign(11) }
      let update: Update<String> = try await variable.notify(after: initialGeneration)
      await verifyIf(
        update.generation,
        isGreaterThan: initialGeneration
      )
      await verifyIf(
        update.generation,
        isEqual: source.generation
      )
      await verifyIf(
        try update.value,
        isEqual: "11"
      )
    }

    let updatedGeneration: UpdateGeneration = variable.generation
    try await withSerialTaskExecutor {
      Task.detached {
        await variable.patch { (current: Update<String>) -> String in
          try current.value + "_updated"
        }
      }
      let update: Update<String> = try await variable.notify(after: updatedGeneration)
      await verifyIf(
        update.generation,
        isGreaterThan: updatedGeneration
      )

      await verifyIf(
        try update.value,
        isEqual: "11_updated"
      )
    }
  }

  func test_value_executesWithoutIssues_concurrently() async throws {
    let source: Variable<Int> = .init(initial: 42)
    let variable: PatchableVariable = .init(
      updatingFrom: source
    ) { (current: Update<String>, update: Update<Int>) throws -> String in
      try String(update.value)
    }
    await withTaskGroup(of: Void.self) { group in
      for _ in 0 ..< 10 {
        group.addTask {
          for _ in 0 ..< 1_000 {
            _ = try? await variable.value
          }
        }
      }
      await group.waitForAll()
    }
  }

  func test_continuousAccess_executesWithoutIssues_concurrently() async throws {
    let source: Variable<Int> = .init(initial: 42)
    let variable: PatchableVariable = .init(
      updatingFrom: source
    ) { (current: Update<String>, update: Update<Int>) throws -> String in
      try String(update.value)
    }
    await withTaskGroup(of: Void.self) { group in
      for i in 0 ..< 20 {
        if i.isMultiple(of: 2) {
          group.addTask {
            for j in 0 ..< 1_000 {
              if j.isMultiple(of: 2) {
                source.value += j
              }
              else {
                await variable.patch { (current: Update<String>) -> String in
                  try current.value + "\(j)"
                }
              }
            }
          }
        }
        else {
          group.addTask {
            for _ in 0 ..< 1_000 {
              _ = try? await variable.value
            }
          }
        }
      }
      await group.waitForAll()
    }
  }
}
