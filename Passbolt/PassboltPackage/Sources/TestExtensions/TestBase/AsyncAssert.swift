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

/// Asserts that a value eventually equals an expected value within a timeout period.
/// - Parameters:
///   - call: A closure that returns the value to be tested.
///   - expectedValue: The expected value to compare against.
///   - timeout: The maximum time to wait for the value to equal the expected value.
///   - timeResoultion: The interval between successive checks of the value.
///   - description: An optional description to include in the failure message.
///   - file: The file name to use in the failure message.
///   - line: The line number to use in the failure message.
public func verifyIf<Value>(
  _ operation: @autoclosure () async throws -> Value,
  eventuallyEquals expectedValue: Value,
  timeout: TimeInterval = 1.0,
  timeResoultion: UInt64 = 100,
  description: @autoclosure () -> String = "",
  file: StaticString = #file,
  line: UInt = #line,
) async throws where Value: Equatable {

  let startTime: Date = .now
  let endTime: Date = startTime.addingTimeInterval(timeout)

  while Date.now < endTime {
    let result = try await operation()
    if result == expectedValue {
      return
    }

    try await Task.sleep(nanoseconds: timeResoultion)
  }

  XCTFail("\(description()) - Expected value: \(expectedValue) not reached within \(timeout) seconds", file: file, line: line)
}
