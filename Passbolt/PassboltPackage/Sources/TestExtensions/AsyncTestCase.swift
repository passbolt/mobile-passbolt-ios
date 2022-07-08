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

open class AsyncTestCase: XCTestCase {

  private var testTask: Task<Void, Error>?

  open override func tearDown() async throws {
    await self.testTask?.waitForCompletion()
    try await super.tearDown()
  }

  public func asyncTest(
    timeout: TimeInterval = 0.3,
    file: StaticString = #file,
    line: UInt = #line,
    test: @escaping @Sendable () async throws -> Void
  ) {
    guard self.testTask == .none
    else { fatalError("Cannot use more than once per test") }

    let expectation: XCTestExpectation = expectation(description: "Async test completes")

    self.testTask = Task {
      do {
        try await test()
      }
      catch {
        XCTFail(
          "Unexpected error thrown: \(error)",
          file: file,
          line: line
        )
      }
      expectation.fulfill()
    }

    waitForExpectations(timeout: timeout)
    self.testTask?.cancel()
  }

  public func asyncTestExecuted<Value>(
    count: UInt = 1,
    timeout: TimeInterval = 0.3,
    file: StaticString = #file,
    line: UInt = #line,
    test: @escaping @Sendable (@escaping () -> Void) async throws -> Value
  ) {
    guard self.testTask == .none
    else { fatalError("Cannot use more than once per test") }

    var executedCount: UInt = 0
    let executed: () -> Void = {
      executedCount += 1
    }

    let expectation: XCTestExpectation = expectation(description: "Async test completes")

    self.testTask = Task {
      do {
        _ = try await test(executed)
      }
      catch {
        XCTFail(
          "Unexpected error thrown: \(error)",
          file: file,
          line: line
        )
      }
      expectation.fulfill()
    }

    waitForExpectations(timeout: timeout)
    XCTAssertEqual(
      executedCount,
      count,
      "Execution count (\(executedCount)) does not match expected (\(count)).",
      file: file,
      line: line
    )
    self.testTask?.cancel()
  }

  public func asyncTestReturnsEqual<Value>(
    _ expectedResult: Value,
    timeout: TimeInterval = 0.3,
    file: StaticString = #file,
    line: UInt = #line,
    test: @escaping @Sendable () async throws -> Value?
  ) where Value: Equatable {
    guard self.testTask == .none
    else { fatalError("Cannot use more than once per test") }

    let expectation: XCTestExpectation = expectation(description: "Async test completes")

    self.testTask = Task {
      do {
        let result: Value? = try await test()
        XCTAssertEqual(
          result,
          expectedResult,
          file: file,
          line: line
        )
      }
      catch {
        XCTFail(
          "Unexpected error thrown: \(error)",
          file: file,
          line: line
        )
      }
      expectation.fulfill()
    }

    waitForExpectations(timeout: timeout)
    self.testTask?.cancel()
  }

  public func asyncTestReturnsSome<Value>(
    timeout: TimeInterval = 0.3,
    file: StaticString = #file,
    line: UInt = #line,
    test: @escaping @Sendable () async throws -> Value?
  ) {
    guard self.testTask == .none
    else { fatalError("Cannot use more than once per test") }

    let expectation: XCTestExpectation = expectation(description: "Async test completes")

    self.testTask = Task {
      do {
        let result: Value? = try await test()
        XCTAssertNotNil(
          result,
          file: file,
          line: line
        )
      }
      catch {
        XCTFail(
          "Unexpected error thrown: \(error)",
          file: file,
          line: line
        )
      }
      expectation.fulfill()
    }

    waitForExpectations(timeout: timeout)
    self.testTask?.cancel()
  }

  public func asyncTestReturnsNone<Value>(
    timeout: TimeInterval = 0.3,
    file: StaticString = #file,
    line: UInt = #line,
    test: @escaping @Sendable () async throws -> Value?
  ) {
    guard self.testTask == .none
    else { fatalError("Cannot use more than once per test") }

    let expectation: XCTestExpectation = expectation(description: "Async test completes")

    self.testTask = Task {
      do {
        let result: Value? = try await test()
        XCTAssertNil(
          result,
          file: file,
          line: line
        )
      }
      catch {
        XCTFail(
          "Unexpected error thrown: \(error)",
          file: file,
          line: line
        )
      }
      expectation.fulfill()
    }

    waitForExpectations(timeout: timeout)
    self.testTask?.cancel()
  }

  public func asyncTestNotThrows<Value>(
    timeout: TimeInterval = 0.3,
    file: StaticString = #file,
    line: UInt = #line,
    test: @escaping @Sendable () async throws -> Value
  ) {
    guard self.testTask == .none
    else { fatalError("Cannot use more than once per test") }

    let expectation: XCTestExpectation = expectation(description: "Async test completes")

    self.testTask = Task {
      do {
        _ = try await test()
      }
      catch {
        XCTFail(
          "Unexpected error thrown: \(error)",
          file: file,
          line: line
        )
      }
      expectation.fulfill()
    }

    waitForExpectations(timeout: timeout)
    self.testTask?.cancel()
  }

  public func asyncTestThrows<Value, Failure>(
    _ failureType: Failure.Type,
    timeout: TimeInterval = 0.3,
    file: StaticString = #file,
    line: UInt = #line,
    test: @escaping @Sendable () async throws -> Value
  ) where Failure: Error {
    guard self.testTask == .none
    else { fatalError("Cannot use more than once per test") }

    let expectation: XCTestExpectation = expectation(description: "Async test completes")

    self.testTask = Task {
      do {
        let result: Value = try await test()
        XCTFail(
          "Expected error not thrown, got: \(result)",
          file: file,
          line: line
        )
      }
      catch {
        XCTAssert(
          error is Failure,
          "Unexpected error thrown, got: \(error), expected \(failureType)",
          file: file,
          line: line
        )
      }
      expectation.fulfill()
    }

    waitForExpectations(timeout: timeout)
    self.testTask?.cancel()
  }
}
