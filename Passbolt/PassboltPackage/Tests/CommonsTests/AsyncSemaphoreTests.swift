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
final class AsyncSemaphoreTests: XCTestCase {

  func test_init_createsSemaphoreWithCorrectInitialValue() async {
    let semaphore = AsyncSemaphore(maxConcurrentOperations: 3)

    let firstWaitTask = Task { await semaphore.wait() }
    let secondWaitTask = Task { await semaphore.wait() }
    let thirdWaitTask = Task { await semaphore.wait() }

    await firstWaitTask.value
    await secondWaitTask.value
    await thirdWaitTask.value
  }

  func test_wait_completesImmediately_whenSemaphoreHasAvailablePermits() async {
    let semaphore = AsyncSemaphore(maxConcurrentOperations: 2)

    let startTime = ContinuousClock().now
    await semaphore.wait()
    let endTime = ContinuousClock().now

    let duration = endTime - startTime
    XCTAssertLessThan(duration, .milliseconds(10))
  }

  func test_wait_suspendsExecution_whenSemaphoreHasNoAvailablePermits() async {
    let semaphore = AsyncSemaphore(maxConcurrentOperations: 1)

    await semaphore.wait()

    let expectation = expectation(description: "Wait should suspend")
    expectation.isInverted = true

    let waitTask = Task {
      await semaphore.wait()
      expectation.fulfill()
    }

    await fulfillment(of: [expectation], timeout: 0.1)
    waitTask.cancel()
  }

  func test_signal_resumesWaitingTask_whenCalledAfterWait() async {
    let semaphore = AsyncSemaphore(maxConcurrentOperations: 1)

    await semaphore.wait()

    let waitExpectation = expectation(description: "Wait should complete after signal")

    let waitTask = Task {
      await semaphore.wait()
      waitExpectation.fulfill()
    }

    try? await Task.sleep(nanoseconds: 10 * NSEC_PER_MSEC)
    await semaphore.signal()

    await fulfillment(of: [waitExpectation], timeout: 1.0)
    waitTask.cancel()
  }

  func test_signal_increasesAvailablePermits_whenNoTasksAreWaiting() async {
    let semaphore = AsyncSemaphore(maxConcurrentOperations: 1)

    await semaphore.wait()
    await semaphore.signal()
    await semaphore.signal()

    let firstWaitTask = Task { await semaphore.wait() }
    let secondWaitTask = Task { await semaphore.wait() }

    await firstWaitTask.value
    await secondWaitTask.value
  }

  func test_multipleWaitersAndSignals_workCorrectly() async {
    let semaphore = AsyncSemaphore(maxConcurrentOperations: 2)
    let completionCount = ActorCounter()

    await semaphore.wait()
    await semaphore.wait()

    let waitTasks = (0 ..< 5)
      .map { index in
        Task {
          await semaphore.wait()
          await completionCount.increment()
          try? await Task.sleep(nanoseconds: 10 * NSEC_PER_MSEC)
          await semaphore.signal()
        }
      }

    try? await Task.sleep(nanoseconds: 10 * NSEC_PER_MSEC)
    let countBeforeSignals = await completionCount.value
    XCTAssertEqual(countBeforeSignals, 0)

    await semaphore.signal()
    await semaphore.signal()

    for task in waitTasks {
      await task.value
    }

    let finalCount = await completionCount.value
    XCTAssertEqual(finalCount, 5)
  }

  func test_concurrentAccess_maintainsCorrectState() async {
    let semaphore = AsyncSemaphore(maxConcurrentOperations: 3)
    let activeCounter = ActorCounter()
    let maxActiveCounter = ActorCounter()

    let tasks = (0 ..< 10)
      .map { _ in
        Task {
          await semaphore.wait()
          let currentActive = await activeCounter.increment()
          let currentMax = await maxActiveCounter.value
          if currentActive > currentMax {
            await maxActiveCounter.set(currentActive)
          }

          try? await Task.sleep(nanoseconds: 50 * NSEC_PER_MSEC)

          await activeCounter.decrement()
          await semaphore.signal()
        }
      }

    for task in tasks {
      await task.value
    }

    let maxActive = await maxActiveCounter.value
    XCTAssertLessThanOrEqual(maxActive, 3)
    XCTAssertGreaterThan(maxActive, 0)

    let finalActive = await activeCounter.value
    XCTAssertEqual(finalActive, 0)
  }

  func test_singlePermitSemaphore_ensuresMutualExclusion() async {
    let semaphore = AsyncSemaphore(maxConcurrentOperations: 1)
    var sharedResource = 0
    let iterations = 100

    let tasks = (0 ..< iterations)
      .map { _ in
        Task {
          await semaphore.wait()
          let current = sharedResource
          try? await Task.sleep(nanoseconds: 1 * NSEC_PER_MSEC)
          sharedResource = current + 1
          await semaphore.signal()
        }
      }

    for task in tasks {
      await task.value
    }

    XCTAssertEqual(sharedResource, iterations)
  }

  func test_zeroPermitSemaphore_blocksAllOperations() async {
    let semaphore = AsyncSemaphore(maxConcurrentOperations: 0)

    let expectation = expectation(description: "Wait should never complete")
    expectation.isInverted = true

    let waitTask = Task {
      await semaphore.wait()
      expectation.fulfill()
    }

    await fulfillment(of: [expectation], timeout: 0.1)
    waitTask.cancel()
  }

  func test_waitersAreResumedCorrectly_withoutLossOrDuplication() async {
    let semaphore = AsyncSemaphore(maxConcurrentOperations: 0)
    let completionOrder = ActorArray<Int>()

    let tasks = (0 ..< 10).map { index in
      Task {
        await semaphore.wait()
        await completionOrder.append(index)
      }
    }

    try? await Task.sleep(nanoseconds: 50 * NSEC_PER_MSEC)

    for _ in 0 ..< 10 {
      await semaphore.signal()
    }

    for task in tasks {
      await task.value
    }

    let completedTasks = await completionOrder.elements
    XCTAssertEqual(completedTasks.count, 10)
    XCTAssertEqual(Set(completedTasks), Set(0 ..< 10))
  }
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
