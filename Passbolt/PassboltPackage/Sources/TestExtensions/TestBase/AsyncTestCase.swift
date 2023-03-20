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
import XCTest

@dynamicMemberLookup
open class AsyncTestCase: XCTestCase {

  private var currentTestTask: Task<Void, Error>? {
    didSet {
      guard let task: Task<Void, Error> = currentTestTask
      else { return }
      self.testTasks.append(task)
    }
  }
  private var testTasks: Array<Task<Void, Error>> = .init()
  public var variables: DynamicVariables!

  public subscript<Value>(
    dynamicMember keyPath: KeyPath<DynamicVariables.VariableNames, StaticString>
  ) -> Value {
    get {
      self.variables.get(
        keyPath,
        of: Value.self
      )
    }
    set {
      self.variables.set(
        keyPath,
        of: Value.self,
        to: newValue
      )
    }
  }

  open override func setUp() async throws {
    try await super.setUp()
    self.variables = .init()
  }

  open override func tearDown() async throws {
    for task in self.testTasks {
      await task.waitForCompletion()
    }
    self.testTasks = .init()
    self.currentTestTask = .none
    self.variables = .none
    try await super.tearDown()
  }

  public func asyncTest(
    timeout: TimeInterval = 0.3,
    file: StaticString = #file,
    line: UInt = #line,
    test: @escaping @Sendable () async throws -> Void
  ) {
    guard self.currentTestTask == .none
    else { fatalError("Cannot use concurrently") }

    let expectation: XCTestExpectation = expectation(description: "Async test completes")

    self.currentTestTask = Task {
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
    self.currentTestTask?.cancel()
    self.currentTestTask = .none
  }

  public func asyncTestExecuted<Value>(
    count: UInt = 1,
    timeout: TimeInterval = 0.3,
    file: StaticString = #file,
    line: UInt = #line,
    test: @escaping @Sendable (@escaping @Sendable () -> Void) async throws -> Value
  ) {
    guard self.currentTestTask == .none
    else { fatalError("Cannot use concurrently") }

    let executedCount: CriticalState<UInt> = .init(0)
    let executed: @Sendable () -> Void = {
      executedCount.access { (count: inout UInt) in
        count += 1
      }
    }

    let expectation: XCTestExpectation = expectation(description: "Async test completes")

    self.currentTestTask = Task {
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
      executedCount.get(\.self),
      count,
      "Execution count (\(executedCount.get(\.self)) does not match expected (\(count)).",
      file: file,
      line: line
    )
    self.currentTestTask?.cancel()
    self.currentTestTask = .none
  }

  public func asyncTestReturnsEqual<Value>(
    _ expectedResult: Value,
    timeout: TimeInterval = 0.3,
    file: StaticString = #file,
    line: UInt = #line,
    test: @escaping @Sendable () async throws -> Value?
  ) where Value: Equatable {
    guard self.currentTestTask == .none
    else { fatalError("Cannot use concurrently") }

    let expectation: XCTestExpectation = expectation(description: "Async test completes")

    self.currentTestTask = Task {
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
    self.currentTestTask?.cancel()
    self.currentTestTask = .none
  }

  public func asyncTestReturnsSome(
    timeout: TimeInterval = 0.3,
    file: StaticString = #file,
    line: UInt = #line,
    test: @escaping @Sendable () async throws -> Any?
  ) {
    guard self.currentTestTask == .none
    else { fatalError("Cannot use concurrently") }

    let expectation: XCTestExpectation = expectation(description: "Async test completes")

    self.currentTestTask = Task {
      do {
        let result: Any? = try await test()
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
    self.currentTestTask?.cancel()
    self.currentTestTask = .none
  }

  public func asyncTestReturnsNone(
    timeout: TimeInterval = 0.3,
    file: StaticString = #file,
    line: UInt = #line,
    test: @escaping @Sendable () async throws -> Any?
  ) {
    guard self.currentTestTask == .none
    else { fatalError("Cannot use concurrently") }

    let expectation: XCTestExpectation = expectation(description: "Async test completes")

    self.currentTestTask = Task {
      do {
        let result: Any? = try await test()
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
    self.currentTestTask?.cancel()
    self.currentTestTask = .none
  }

  public func asyncTestNotThrows<Value>(
    timeout: TimeInterval = 0.3,
    file: StaticString = #file,
    line: UInt = #line,
    test: @escaping @Sendable () async throws -> Value
  ) {
    guard self.currentTestTask == .none
    else { fatalError("Cannot use concurrently") }

    let expectation: XCTestExpectation = expectation(description: "Async test completes")

    self.currentTestTask = Task {
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
    self.currentTestTask?.cancel()
    self.currentTestTask = .none
  }

  public func asyncTestThrows<Value, Failure>(
    _ failureType: Failure.Type,
    timeout: TimeInterval = 0.3,
    file: StaticString = #file,
    line: UInt = #line,
    test: @escaping @Sendable () async throws -> Value
  ) where Failure: Error {
    guard self.currentTestTask == .none
    else { fatalError("Cannot use concurrently") }

    let expectation: XCTestExpectation = expectation(description: "Async test completes")

    self.currentTestTask = Task {
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
    self.currentTestTask?.cancel()
    self.currentTestTask = .none
  }
}
