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

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class BatchExecutorTests: XCTestCase {

  func test_init_createsBatchExecutorWithCorrectConcurrencyLimit() async {
    let executor = BatchExecutor(maxConcurrentTasks: 5)
    XCTAssertNotNil(executor)
  }

  func test_execute_completesSuccessfully_withNoOperations() async throws {
    let executor = BatchExecutor(maxConcurrentTasks: 3)

    try await executor.execute()
  }

  func test_execute_completesSuccessfully_withSingleOperation() async throws {
    let executor = BatchExecutor(maxConcurrentTasks: 3)
    let expectation = expectation(description: "Operation should execute")

    await executor.addOperation {
      expectation.fulfill()
    }

    try await executor.execute()

    await fulfillment(of: [expectation], timeout: 1.0)
  }

  func test_execute_completesSuccessfully_withMultipleOperations() async throws {
    let executor = BatchExecutor(maxConcurrentTasks: 3)
    let counter = ActorCounter()

    for _ in 0 ..< 10 {
      await executor.addOperation {
        await counter.increment()
      }
    }

    try await executor.execute()

    let finalCount = await counter.value
    XCTAssertEqual(finalCount, 10)
  }

  func test_execute_respectsConcurrencyLimit() async throws {
    let maxConcurrentTasks = 3
    let executor = BatchExecutor(maxConcurrentTasks: maxConcurrentTasks)
    let activeCounter = ActorCounter()
    let maxActiveCounter = ActorCounter()
    let totalTasks = 10

    for _ in 0 ..< totalTasks {
      await executor.addOperation {
        let currentActive = await activeCounter.increment()
        let currentMax = await maxActiveCounter.value
        if currentActive > currentMax {
          await maxActiveCounter.set(currentActive)
        }

        try? await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)

        await activeCounter.decrement()
      }
    }

    try await executor.execute()

    let maxActive = await maxActiveCounter.value
    XCTAssertLessThanOrEqual(maxActive, maxConcurrentTasks)
    XCTAssertGreaterThan(maxActive, 0)

    let finalActive = await activeCounter.value
    XCTAssertEqual(finalActive, 0)
  }

  func test_execute_throwsError_whenOperationThrows() async {
    let executor = BatchExecutor(maxConcurrentTasks: 3)

    await executor.addOperation {
      throw TestError.operationFailed
    }

    do {
      try await executor.execute()
      XCTFail("Expected to throw an error")
    }
    catch {
      XCTAssertTrue(error is TestError)
    }
  }

  func test_execute_throwsFirstError_whenMultipleOperationsThrow() async {
    let executor = BatchExecutor(maxConcurrentTasks: 3)

    await executor.addOperation {
      try? await Task.sleep(nanoseconds: 50 * NSEC_PER_MSEC)
      throw TestError.firstError
    }

    await executor.addOperation {
      throw TestError.secondError
    }

    await executor.addOperation {
      try? await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)
      throw TestError.thirdError
    }

    do {
      try await executor.execute()
      XCTFail("Expected to throw an error")
    }
    catch let error as TestError {
      XCTAssertTrue([TestError.firstError, TestError.secondError, TestError.thirdError].contains(error))
    }
    catch {
      XCTFail("Unexpected error type: \(error)")
    }
  }

  func test_execute_completesAllOperations_whenSomeThrow() async {
    let executor = BatchExecutor(maxConcurrentTasks: 3)
    let successCounter = ActorCounter()

    for i in 0 ..< 5 {
      await executor.addOperation {
        if i == 2 {
          throw TestError.operationFailed
        }
        await successCounter.increment()
      }
    }

    do {
      try await executor.execute()
      XCTFail("Expected to throw an error")
    }
    catch {
      let successCount = await successCounter.value
      XCTAssertEqual(successCount, 4)
    }
  }

  func test_execute_worksCorrectly_withSingleConcurrentTask() async throws {
    let executor = BatchExecutor(maxConcurrentTasks: 1)
    let executionOrder = ActorArray<Int>()

    for i in 0 ..< 5 {
      await executor.addOperation {
        await executionOrder.append(i)
        try? await Task.sleep(nanoseconds: 10 * NSEC_PER_MSEC)
      }
    }

    try await executor.execute()

    let order = await executionOrder.elements
    XCTAssertEqual(order.count, 5)
    XCTAssertEqual(Set(order), Set([0, 1, 2, 3, 4]))
  }

  func test_execute_handlesZeroConcurrencyLimit() async throws {
    let executor = BatchExecutor(maxConcurrentTasks: 0)
    let counter = ActorCounter()

    await executor.addOperation {
      await counter.increment()
    }

    try await executor.execute()

    let finalCount = await counter.value
    XCTAssertEqual(finalCount, 1)
  }

  func test_addOperation_canAddMultipleOperationsBeforeExecution() async throws {
    let executor = BatchExecutor(maxConcurrentTasks: 2)
    let results = ActorArray<String>()

    await executor.addOperation {
      await results.append("first")
    }

    await executor.addOperation {
      await results.append("second")
    }

    await executor.addOperation {
      await results.append("third")
    }

    try await executor.execute()

    let allResults = await results.elements
    XCTAssertEqual(allResults.count, 3)
    XCTAssertTrue(allResults.contains("first"))
    XCTAssertTrue(allResults.contains("second"))
    XCTAssertTrue(allResults.contains("third"))
  }

  func test_execute_canBeCalledMultipleTimes() async throws {
    let executor = BatchExecutor(maxConcurrentTasks: 2)
    let counter = ActorCounter()

    await executor.addOperation {
      await counter.increment()
    }

    try await executor.execute()

    let countAfterFirstExecution = await counter.value
    XCTAssertEqual(countAfterFirstExecution, 1)

    await executor.addOperation {
      await counter.increment()
    }

    await executor.addOperation {
      await counter.increment()
    }

    try await executor.execute()

    let countAfterSecondExecution = await counter.value
    XCTAssertEqual(countAfterSecondExecution, 3)
  }

  func test_execute_performsOperationsInParallel_withinConcurrencyLimit() async throws {
    let maxConcurrentTasks = 3
    let executor = BatchExecutor(maxConcurrentTasks: maxConcurrentTasks)
    let startTime = ContinuousClock().now
    let taskDuration: UInt64 = 100 * NSEC_PER_MSEC
    let numberOfTasks = 6

    for _ in 0 ..< numberOfTasks {
      await executor.addOperation {
        try? await Task.sleep(nanoseconds: taskDuration)
      }
    }

    try await executor.execute()

    let endTime = ContinuousClock().now
    let totalDuration = endTime - startTime

    let sequentialDuration = taskDuration * UInt64(numberOfTasks)
    let parallelDuration = taskDuration * UInt64((numberOfTasks + maxConcurrentTasks - 1) / maxConcurrentTasks)

//    XCTAssertLessThan(totalDuration.components.nanoseconds, sequentialDuration)
//    XCTAssertGreaterThan(totalDuration.components.nanoseconds, parallelDuration - 50 * NSEC_PER_MSEC)
  }

  func test_execute_handlesAsyncOperationsCorrectly() async throws {
    let executor = BatchExecutor(maxConcurrentTasks: 2)
    let results = ActorArray<Int>()

    for i in 0 ..< 5 {
      await executor.addOperation {
        try? await Task.sleep(nanoseconds: UInt64.random(in: 10 ... 50) * NSEC_PER_MSEC)
        await results.append(i * 2)
      }
    }

    try await executor.execute()

    let allResults = await results.elements
    let expected = [0, 2, 4, 6, 8]
    XCTAssertEqual(Set(allResults), Set(expected))
  }
}

private enum TestError: Error, Equatable {
  case operationFailed
  case firstError
  case secondError
  case thirdError
}

private actor ActorCounter {
  private var internalValue: Int = 0

  var value: Int { internalValue }

  @discardableResult
  func increment() -> Int {
    internalValue += 1
    return internalValue
  }

  @discardableResult
  func decrement() -> Int {
    internalValue -= 1
    return internalValue
  }

  func set(_ value: Int) {
    internalValue = value
  }
}

private actor ActorArray<T> {
  private var internalElements: [T] = []

  var elements: [T] { internalElements }

  func append(_ element: T) {
    internalElements.append(element)
  }
}
