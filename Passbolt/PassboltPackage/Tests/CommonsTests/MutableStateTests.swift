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

final class MutableStateTests: XCTestCase {

  func test_initial_providesInitialValue() async throws {
    let state: MutableState<String> = .init(initial: "42")
    let result: String = try await state.value
    XCTAssertEqual(result, "42")
  }

  func test_failed_providesFailedState() async throws {
    let state: MutableState<String> = .init(failed: CancellationError())
    do {
      _ = try await state.value
      XCTFail("Expecting error")
    }
    catch is CancellationError {
      // expected
    }
    catch {
      XCTFail("Unexpected error")
    }
  }

  func test_lazy_providesInitialValueWhenAvailable() async throws {
    let state: MutableState<String> = .init(
      lazy: {
        try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)
        return "42"
      }
    )
    let result: String = try await state.value
    XCTAssertEqual(result, "42")
  }

  func test_update_updatesValue() async throws {
    let state: MutableState<String> = .init(initial: "initial")
    try await state.update(\.self, to: "42")
    let result: String = try await state.value
    XCTAssertEqual(result, "42")
  }

  func test_update_updatesLazyValue() async throws {
    let state: MutableState<String> = .init(lazy: { "initial" })
    try await state.update(\.self, to: "42")
    let result: String = try await state.value
    XCTAssertEqual(result, "42")
  }

  func test_update_updatesAndReturnsValue() async throws {
    let state: MutableState<String> = .init(initial: "initial")
    var result: String = try await state.update { (value: inout String) in
      value = "42"
    }
    XCTAssertEqual(result, "42")
    result = try await state.value
    XCTAssertEqual(result, "42")
  }

  func test_update_updatesAndReturnsLazyValue() async throws {
    let state: MutableState<String> = .init(lazy: { "initial" })
    var result: String = try await state.update { (value: inout String) in
      value = "42"
    }
    XCTAssertEqual(result, "42")
    result = try await state.value
    XCTAssertEqual(result, "42")
  }

  func test_updateAsync_updatesAndReturnsValue() async throws {
    let state: MutableState<String> = .init(initial: "initial")
    var result: String = try await state.asyncUpdate { (value: inout String) in
      try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)
      value = "42"
    }
    XCTAssertEqual(result, "42")
    result = try await state.value
    XCTAssertEqual(result, "42")
  }

  func test_updateAsync_updatesAndReturnsLazyValue() async throws {
    let state: MutableState<String> = .init(lazy: { "initial" })
    var result: String = try await state.asyncUpdate { (value: inout String) in
      try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)
      value = "42"
    }
    XCTAssertEqual(result, "42")
    result = try await state.value
    XCTAssertEqual(result, "42")
  }

  func test_scheduleUpdate_updatesValue() async throws {
    let state: MutableState<String> = .init(initial: "initial")
    try await state.deferredUpdate { (value: inout String) in
      try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)
      value = "42"
    }
    let result: String = try await state.value
    XCTAssertEqual(result, "42")
  }

  func test_scheduleUpdate_updatesLazyValue() async throws {
    let state: MutableState<String> = .init(lazy: { "initial" })
    try state.deferredUpdate { (value: inout String) in
      try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)
      value = "42"
    }
    let result: String = try await state.value
    XCTAssertEqual(result, "42")
  }

//  func test_scheduleRecurringUpdates_updatesValue() async throws {
//    let state: MutableState<String> = .init(initial: "initial")
//    let counter: CriticalState<Int> = .init(0)
//    state.scheduleRecurringUpdates {
//      try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)
//      let counter: Int = counter.exchange(\.self, with: 1)
//      guard counter == 0 else { throw CancellationError() }
//      return { (value: inout String) in
//        value = "42"
//      }
//    }
//    let result: String = try await state.nextValue
//    XCTAssertEqual(result, "42")
//  }
//
//  func test_scheduleRecurringUpdates_updatesLazyValue() async throws {
//    let state: MutableState<String> = .init(lazy: { "initial" })
//    let counter: CriticalState<Int> = .init(0)
//    state.scheduleRecurringUpdates {
//      try await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)
//      let counter: Int = counter.exchange(\.self, with: 1)
//      guard counter == 0 else { throw CancellationError() }
//      return { (value: inout String) in
//        value = "42"
//      }
//    }
//    // delay to ensure that update will be scheduled before asking for a value
//    try await Task.sleep(nanoseconds: 200 * NSEC_PER_MSEC)
//    let result: String = try await state.value
//    XCTAssertEqual(result, "42")
//  }
//
//  func test_scheduleRecurringUpdates_updatesValueOverTime() async throws {
//    let state: MutableState<String> = .init(lazy: { "initial" })
//    let counter: CriticalState<Int> = .init(10)
//    state.scheduleRecurringUpdates {
//      // delay to ensure picking all values
//      try await Task.sleep(nanoseconds: 10 * NSEC_PER_MSEC)
//      let counter: Int = counter.access { (value: inout Int) in
//        defer { value -= 1 }
//        return value
//      }
//      guard counter >= 0
//      else { throw CancellationError() }
//      return { (value: inout String) in
//        if counter == 0 {
//          throw CancellationError()
//        }
//        else {
//          value = "\(counter)"
//        }
//      }
//    }
//
//    var result: Array<String> = .init()
//    do {
//      for try await value in state {
//        result.append(value)
//      }
//    }
//    catch is CancellationError {
//      // ended
//    }
//    catch {
//      throw error
//    }
//
//    XCTAssertEqual(result, ["initial", "10", "9", "8", "7", "6", "5", "4", "3", "2", "1"])
//  }
//
//  func test_scheduleRecurringUpdates_doesNotCrashWhenLongRunning() async throws {
//    let state: MutableState<String> = .init(lazy: { "initial" })
//    let counter: CriticalState<Int> = .init(1_000)
//    state.scheduleRecurringUpdates {
//      let counter: Int = counter.access { (value: inout Int) in
//        defer { value -= 1 }
//        return value
//      }
//      guard counter >= 0
//      else { throw CancellationError() }
//      return { (value: inout String) in
//        if counter == 0 {
//          throw CancellationError()
//        }
//        else {
//          value = "\(counter)"
//        }
//      }
//    }
//
//    // iterate over to wait for the completion
//    while let _ = try? await state.nextValue {}
//  }
}
