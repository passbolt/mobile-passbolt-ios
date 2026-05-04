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
final class StoredVariableTests: TestCase {

  func test_value_fetchesFromStorage_onFirstAccess() {
    let fetchCallCount: CriticalState<Int> = .init(0)
    let storedVariable: StoredVariable<Int> = .init(
      fetch: {
        fetchCallCount.access { $0 += 1 }
        return 42
      },
      store: { _ in }
    )

    verifyIf(
      storedVariable.value,
      isEqual: 42
    )
    verifyIf(
      fetchCallCount.get(),
      isEqual: 1
    )
  }

  func test_value_doesNotFetchFromStorage_onSubsequentAccess() {
    let fetchCallCount: CriticalState<Int> = .init(0)
    let storedVariable: StoredVariable<Int> = .init(
      fetch: {
        fetchCallCount.access { $0 += 1 }
        return 42
      },
      store: { _ in }
    )

    _ = storedVariable.value
    _ = storedVariable.value
    _ = storedVariable.value

    verifyIf(
      fetchCallCount.get(),
      isEqual: 1
    )
  }

  func test_variable_isLazilyInitialized() {
    let fetchCallCount: CriticalState<Int> = .init(0)
    let storedVariable: StoredVariable<Int> = .init(
      fetch: {
        fetchCallCount.access { $0 += 1 }
        return 42
      },
      store: { _ in }
    )

    verifyIf(
      fetchCallCount.get(),
      isEqual: 0
    )

    _ = storedVariable.variable

    verifyIf(
      fetchCallCount.get(),
      isEqual: 1
    )
  }

  func test_variable_returnsTheSameInstance_onMultipleAccesses() {
    let storedVariable: StoredVariable<Int> = .init(
      fetch: { 42 },
      store: { _ in }
    )

    let first = storedVariable.variable
    let second = storedVariable.variable

    XCTAssertIdentical(first, second)
  }

  func test_assign_updatesValue_andCallsStore() {
    let storedValue: CriticalState<Int?> = .init(.none)
    let storedVariable: StoredVariable<Int> = .init(
      fetch: { 42 },
      store: { storedValue.set($0) }
    )

    storedVariable.assign(99)

    verifyIf(
      storedVariable.value,
      isEqual: 99
    )
    verifyIf(
      storedValue.get(),
      isEqual: 99
    )
  }

  func test_assign_withKeyPath_updatesValue_andCallsStore() {
    struct TestStruct: Sendable {
      var count: Int
      var name: String
    }

    let storedValue: CriticalState<TestStruct?> = .init(.none)
    let storedVariable: StoredVariable<TestStruct> = .init(
      fetch: { TestStruct(count: 0, name: "initial") },
      store: { storedValue.set($0) }
    )

    storedVariable.assign(42, to: \.count)

    verifyIf(
      storedVariable.value.count,
      isEqual: 42
    )
    verifyIf(
      storedValue.get()?.count,
      isEqual: 42
    )
    verifyIf(
      storedValue.get()?.name,
      isEqual: "initial"
    )
  }

  func test_mutate_updatesValue_andCallsStore() {
    let storedValue: CriticalState<Int?> = .init(.none)
    let storedVariable: StoredVariable<Int> = .init(
      fetch: { 42 },
      store: { storedValue.set($0) }
    )

    storedVariable.mutate { $0 = 100 }

    verifyIf(
      storedVariable.value,
      isEqual: 100
    )
    verifyIf(
      storedValue.get(),
      isEqual: 100
    )
  }

  func test_mutate_returnsValue_fromClosure() {
    let storedVariable: StoredVariable<Int> = .init(
      fetch: { 42 },
      store: { _ in }
    )

    let result = storedVariable.mutate { value in
      value = 100
      return "modified"
    }

    verifyIf(
      result,
      isEqual: "modified"
    )
  }

  func test_valueModification_callsStore() {
    let storedValue: CriticalState<Int?> = .init(.none)
    let storedVariable: StoredVariable<Int> = .init(
      fetch: { 42 },
      store: { storedValue.set($0) }
    )

    storedVariable.value += 10

    verifyIf(
      storedVariable.value,
      isEqual: 52
    )
    verifyIf(
      storedValue.get(),
      isEqual: 52
    )
  }

  func test_generation_isInitialized_afterFirstAccess() {
    let storedVariable: StoredVariable<Int> = .init(
      fetch: { 42 },
      store: { _ in }
    )

    _ = storedVariable.value

    verifyIf(
      storedVariable.generation,
      isGreaterThan: .uninitialized
    )
  }

  func test_generation_grows_afterUpdate() {
    let storedVariable: StoredVariable<Int> = .init(
      fetch: { 42 },
      store: { _ in }
    )

    let firstGeneration: UpdateGeneration = storedVariable.generation
    storedVariable.assign(99)
    let secondGeneration: UpdateGeneration = storedVariable.generation

    verifyIf(
      secondGeneration,
      isGreaterThan: firstGeneration
    )
  }

  func test_lastUpdate_containsCurrentValue() {
    let storedVariable: StoredVariable<Int> = .init(
      fetch: { 42 },
      store: { _ in }
    )

    storedVariable.assign(77)

    verifyIf(
      try! storedVariable.lastUpdate.value,
      isEqual: 77
    )
  }

  func test_notify_waitsForNextUpdate_whenRequestedWithCurrentGeneration() async throws {
    let storedVariable: StoredVariable<Int> = .init(
      fetch: { 42 },
      store: { _ in }
    )

    let initialGeneration: UpdateGeneration = storedVariable.generation

    try await withSerialTaskExecutor {
      Task.detached { storedVariable.assign(11) }
      let update: Update<Int> = try await storedVariable.notify(after: initialGeneration)

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

  func test_convert_createsStoredVariable_withTransformedValue() {
    let storedValue: CriticalState<Int?> = .init(.none)
    let intVariable: StoredVariable<Int> = .init(
      fetch: { 42 },
      store: { storedValue.set($0) }
    )

    let stringVariable: StoredVariable<String> = intVariable.convert(
      read: { String($0) },
      write: { Int($0) ?? 0 }
    )

    verifyIf(
      stringVariable.value,
      isEqual: "42"
    )

    stringVariable.assign("99")

    verifyIf(
      intVariable.value,
      isEqual: 99
    )
    verifyIf(
      storedValue.get(),
      isEqual: 99
    )
  }

  func test_convert_handlesComplexTransformations() {
    struct User: Sendable {
      var name: String
      var age: Int
    }

    let storedUser: CriticalState<User?> = .init(.none)
    let userVariable: StoredVariable<User> = .init(
      fetch: { User(name: "Alice", age: 30) },
      store: { storedUser.set($0) }
    )

    let nameVariable: StoredVariable<String> = userVariable.convert(
      read: { $0.name },
      write: { name in
        var user = userVariable.value
        user.name = name
        return user
      }
    )

    verifyIf(
      nameVariable.value,
      isEqual: "Alice"
    )

    nameVariable.assign("Bob")

    verifyIf(
      userVariable.value.name,
      isEqual: "Bob"
    )
    verifyIf(
      storedUser.get()?.name,
      isEqual: "Bob"
    )
    verifyIf(
      storedUser.get()?.age,
      isEqual: 30
    )
  }

  func test_store_isCalledOnce_perAssignment() {
    let storeCallCount: CriticalState<Int> = .init(0)
    let storedVariable: StoredVariable<Int> = .init(
      fetch: { 42 },
      store: { _ in storeCallCount.access { $0 += 1 } }
    )

    storedVariable.assign(1)
    storedVariable.assign(2)
    storedVariable.assign(3)

    verifyIf(
      storeCallCount.get(),
      isEqual: 3
    )
  }

  func test_store_isCalledOnce_perMutation() {
    let storeCallCount: CriticalState<Int> = .init(0)
    let storedVariable: StoredVariable<Int> = .init(
      fetch: { 42 },
      store: { _ in storeCallCount.access { $0 += 1 } }
    )

    storedVariable.mutate { $0 += 1 }
    storedVariable.mutate { $0 += 2 }

    verifyIf(
      storeCallCount.get(),
      isEqual: 2
    )
  }

  func test_store_isCalledOnce_perValueModification() {
    let storeCallCount: CriticalState<Int> = .init(0)
    let storedVariable: StoredVariable<Int> = .init(
      fetch: { 42 },
      store: { _ in storeCallCount.access { $0 += 1 } }
    )

    storedVariable.value += 1
    storedVariable.value *= 2

    verifyIf(
      storeCallCount.get(),
      isEqual: 2
    )
  }

  func test_concurrentAccess_executesWithoutIssues() async throws {
    let storedValue: CriticalState<Int> = .init(0)
    let lock = NSLock()
    let storedVariable: StoredVariable<Int> = .init(
      fetch: { 42 },
      store: { newValue in
        lock.lock()
        storedValue.set(newValue)
        lock.unlock()
      }
    )

    await withTaskGroup(of: Void.self) { group in
      for _ in 0 ..< 10 {
        group.addTask {
          for i in 0 ..< 100 {
            storedVariable.assign(i)
          }
        }
      }
      await group.waitForAll()
    }

    await verifyIf(
      storedVariable.value,
      isEqual: storedValue.get()
    )
  }

  func test_concurrentMutations_executesWithoutIssues() async throws {
    let storedValue: CriticalState<Int> = .init(0)
    let lock = NSLock()
    let storedVariable: StoredVariable<Int> = .init(
      fetch: { 42 },
      store: { newValue in
        lock.lock()
        storedValue.set(newValue)
        lock.unlock()
      }
    )

    await withTaskGroup(of: Void.self) { group in
      for _ in 0 ..< 10 {
        group.addTask {
          for i in 0 ..< 100 {
            storedVariable.mutate { $0 = i }
          }
        }
      }
      await group.waitForAll()
    }

    await verifyIf(
      storedVariable.value,
      isEqual: storedValue.get()
    )
  }

  func test_concurrentReads_executesWithoutIssues() async throws {
    let storedVariable: StoredVariable<Int> = .init(
      fetch: { 42 },
      store: { _ in }
    )

    await withTaskGroup(of: Void.self) { group in
      for _ in 0 ..< 20 {
        group.addTask {
          for _ in 0 ..< 1_000 {
            _ = storedVariable.value
          }
        }
      }
      await group.waitForAll()
    }
  }

  func test_mixedConcurrentAccess_executesWithoutIssues() async throws {
    let storedValue: CriticalState<Int> = .init(0)
    let lock = NSLock()
    let storedVariable: StoredVariable<Int> = .init(
      fetch: { 42 },
      store: { newValue in
        lock.lock()
        storedValue.set(newValue)
        lock.unlock()
      }
    )

    await withTaskGroup(of: Void.self) { group in
      for i in 0 ..< 20 {
        if i.isMultiple(of: 2) {
          group.addTask {
            for j in 0 ..< 100 {
              storedVariable.value += j
            }
          }
        }
        else {
          group.addTask {
            for _ in 0 ..< 100 {
              _ = storedVariable.value
            }
          }
        }
      }
      await group.waitForAll()
    }

    await verifyIf(
      storedVariable.value,
      isEqual: storedValue.get()
    )
  }

  func test_asyncSequence_deliversUpdates() async throws {
    let storedVariable: StoredVariable<Int> = .init(
      fetch: { 0 },
      store: { _ in }
    )

    let expectation: XCTestExpectation = expectation(description: "Receive 3 updates")
    expectation.expectedFulfillmentCount = 3

    let receivedValues: CriticalState<Array<Int>> = .init(.init())

    Task.detached {
      var iterator = storedVariable.makeAsyncIterator()
      for _ in 0 ..< 3 {
        if let update = await iterator.next(),
          let value = try? update.value
        {
          receivedValues.access { $0.append(value) }
          expectation.fulfill()
        }
      }
    }

    Task.detached {
      for i in 1 ... 2 {
        try await Task.sleep(for: .milliseconds(100))
        storedVariable.assign(i)
      }
    }

    await fulfillment(of: [expectation], timeout: 1.0)
    await verifyIf(
      receivedValues.get(),
      isEqual: [0, 1, 2]
    )
  }

  func test_notifying_triggersUpdates_onAssign() {
    let updates: Updates = .init()
    let initialGeneration: UpdateGeneration = updates.generation
    let storedVariable: StoredVariable<Int> = StoredVariable<Int>(
      fetch: { 42 },
      store: { _ in }
    )
    .notifying(updates)

    storedVariable.assign(99)

    verifyIf(
      updates.generation,
      isGreaterThan: initialGeneration
    )
  }

  func test_notifying_triggersUpdates_onValueModification() {
    let updates: Updates = .init()
    let storedVariable: StoredVariable<Int> = StoredVariable<Int>(
      fetch: { 42 },
      store: { _ in }
    )
    .notifying(updates)

    let generationBeforeModification: UpdateGeneration = updates.generation
    storedVariable.value += 10

    verifyIf(
      updates.generation,
      isGreaterThan: generationBeforeModification
    )
  }

  func test_notifying_triggersUpdates_onMutate() {
    let updates: Updates = .init()
    let storedVariable: StoredVariable<Int> = StoredVariable<Int>(
      fetch: { 42 },
      store: { _ in }
    )
    .notifying(updates)

    let generationBeforeMutation: UpdateGeneration = updates.generation
    storedVariable.mutate { $0 = 100 }

    verifyIf(
      updates.generation,
      isGreaterThan: generationBeforeMutation
    )
  }

  func test_notifying_propagatesValueToOriginal() {
    let storedValue: CriticalState<Int?> = .init(.none)
    let updates: Updates = .init()
    let original: StoredVariable<Int> = .init(
      fetch: { 42 },
      store: { storedValue.set($0) }
    )
    let notifying: StoredVariable<Int> = original.notifying(updates)

    notifying.assign(77)

    verifyIf(
      original.value,
      isEqual: 77
    )
    verifyIf(
      storedValue.get(),
      isEqual: 77
    )
  }

  func test_notifying_doesNotTriggerUpdates_withoutWrite() {
    let updates: Updates = .init()
    let storedVariable: StoredVariable<Int> = StoredVariable<Int>(
      fetch: { 42 },
      store: { _ in }
    )
    .notifying(updates)

    let generationAfterCreation: UpdateGeneration = updates.generation
    _ = storedVariable.value

    verifyIf(
      updates.generation,
      isEqual: generationAfterCreation
    )
  }

  func test_notifying_chainsWithConvert() {
    let storedValue: CriticalState<Int?> = .init(.none)
    let updates: Updates = .init()
    let intVariable: StoredVariable<Int> = .init(
      fetch: { 42 },
      store: { storedValue.set($0) }
    )
    let stringVariable: StoredVariable<String> =
      intVariable
      .convert(
        read: { String($0) },
        write: { Int($0) ?? 0 }
      )
      .notifying(updates)

    let initialGeneration: UpdateGeneration = updates.generation
    stringVariable.assign("99")

    verifyIf(
      updates.generation,
      isGreaterThan: initialGeneration
    )
    verifyIf(
      storedValue.get(),
      isEqual: 99
    )
  }

  func test_storedVariable_concurrentIninitalization() {
    let fetchCallCount: CriticalState<Int> = .init(0)
    let storedVariable: StoredVariable<Int> = .init(
      fetch: {
        fetchCallCount.access { $0 += 1 }
        return 42
      },
      store: { _ in }
    )
    let tasksCompletedExpectation: XCTestExpectation = expectation(description: "All tasks completed")
    tasksCompletedExpectation.expectedFulfillmentCount = 1_000

    for _ in 0 ..< 1_000 {
      Task.detached {
        _ = storedVariable.value
        tasksCompletedExpectation.fulfill()
      }
    }
    wait(for: [tasksCompletedExpectation], timeout: 1.0)
    verifyIf(
      fetchCallCount.get(),
      isEqual: 1
    )
  }
}
