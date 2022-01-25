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

// swift-format-ignore: AlwaysUseLowerCamelCase
public func XCTAssertTrue(
  _ expression: @autoclosure () throws -> Bool?,
  _ message: @autoclosure () -> String = "",
  file: StaticString = #filePath,
  line: UInt = #line
) {
  XCTAssertTrue(
    try expression() ?? false,
    message(),
    file: file,
    line: line
  )
}

// swift-format-ignore: AlwaysUseLowerCamelCase
public func XCTAssertFalse(
  _ expression: @autoclosure () throws -> Bool?,
  _ message: @autoclosure () -> String = "",
  file: StaticString = #filePath,
  line: UInt = #line
) {
  XCTAssertFalse(
    try expression() ?? true,
    message(),
    file: file,
    line: line
  )
}

// swift-format-ignore: AlwaysUseLowerCamelCase
public func XCTAssertSuccess<T, E>(
  _ result: Result<T, E>,
  _ file: StaticString = #filePath,
  _ line: UInt = #line
) where E: Error {
  switch result {
  case .success:
    break  // success

  case let .failure(error):
    XCTFail(
      "Unexpected failure with error: \(error)",
      file: file,
      line: line
    )
  }
}

// swift-format-ignore: AlwaysUseLowerCamelCase
public func XCTAssertSuccessEqual<T, E>(
  _ lhs: Result<T, E>,
  _ rhs: T,
  _ file: StaticString = #filePath,
  _ line: UInt = #line
) where T: Equatable, E: Error {
  switch lhs {
  case let .success(value):
    XCTAssertEqual(
      value,
      rhs,
      file: file,
      line: line
    )
  case let .failure(error):
    XCTFail(
      "Unexpected failure with error: \(error)",
      file: file,
      line: line
    )
  }
}

// swift-format-ignore: AlwaysUseLowerCamelCase
public func XCTAssertSuccessNotEqual<T, E>(
  _ lhs: Result<T, E>,
  _ rhs: T,
  _ file: StaticString = #filePath,
  _ line: UInt = #line
) where T: Equatable, E: Error {
  switch lhs {
  case let .success(value):
    XCTAssertNotEqual(
      value,
      rhs,
      file: file,
      line: line
    )
  case let .failure(error):
    XCTFail(
      "Unexpected failure with error: \(error)",
      file: file,
      line: line
    )
  }
}

// swift-format-ignore: AlwaysUseLowerCamelCase
public func XCTAssertFailure<T, E>(
  _ result: Result<T, E>,
  _ file: StaticString = #filePath,
  _ line: UInt = #line
) where E: Error {
  switch result {
  case let .success(value):
    XCTFail(
      "Unexpected success with value: \(value)",
      file: file,
      line: line
    )

  case .failure:
    break  // success
  }
}

// swift-format-ignore: AlwaysUseLowerCamelCase
public func XCTAssertFailureEqual<T, E>(
  _ lhs: Result<T, E>,
  _ rhs: E,
  _ file: StaticString = #filePath,
  _ line: UInt = #line
) where E: Equatable & Error {
  switch lhs {
  case let .success(value):
    XCTFail(
      "Unexpected success with value: \(value)",
      file: file,
      line: line
    )
  case let .failure(error):
    XCTAssertEqual(
      error,
      rhs,
      file: file,
      line: line
    )
  }
}

// swift-format-ignore: AlwaysUseLowerCamelCase
public func XCTAssertFailureNotEqual<T, E>(
  _ lhs: Result<T, E>,
  _ rhs: E,
  _ file: StaticString = #filePath,
  _ line: UInt = #line
) where E: Equatable & Error {
  switch lhs {
  case let .success(value):
    XCTFail(
      "Unexpected success with value: \(value)",
      file: file,
      line: line
    )
  case let .failure(error):
    XCTAssertNotEqual(
      error,
      rhs,
      file: file,
      line: line
    )
  }
}

// swift-format-ignore: AlwaysUseLowerCamelCase
public func XCTAssertThrows<T>(
  _ errorType: Error.Type = Error.self,
  _ test: @escaping () async throws -> T,
  _ file: StaticString = #filePath,
  _ line: UInt = #line
) {
  let sem: DispatchSemaphore = .init(value: 0)
  Task {
    do {
      _ = try await test()
      XCTFail(
        "Unexpected success",
        file: file,
        line: line
      )
    }
    catch let error {
      if errorType == Error.self || type(of: error) == errorType {
        /* NOP */
      }
      else {
        XCTFail(
          "Unexpected error: \(error)",
          file: file,
          line: line
        )
      }
    }
    sem.signal()
  }
  sem.wait()
}

// swift-format-ignore: AlwaysUseLowerCamelCase
public func XCTAssertThrows<T>(
  _ errorType: TheErrorLegacy.Type,
  identifier: TheErrorLegacy.ID,
  _ test: @escaping () async throws -> T,
  _ file: StaticString = #filePath,
  _ line: UInt = #line
) {
  let sem: DispatchSemaphore = .init(value: 0)
  Task {
    do {
      _ = try await test()
      XCTFail(
        "Unexpected success",
        file: file,
        line: line
      )
    }
    catch let error as TheErrorLegacy {
      if error.identifier == identifier {
        /* NOP */
      }
      else {
        XCTFail(
          "Unexpected error: \(error)",
          file: file,
          line: line
        )
      }
    }
    catch let error {
      XCTFail(
        "Unexpected error: \(error)",
        file: file,
        line: line
      )
    }
    sem.signal()
  }
  sem.wait()
}

// swift-format-ignore: AlwaysUseLowerCamelCase
public func XCTAssertTrue(
  _ message: @autoclosure @escaping () -> String = "",
  _ test: @escaping () async throws -> Bool,
  file: StaticString = #filePath,
  line: UInt = #line
) {
  let sem: DispatchSemaphore = .init(value: 0)
  Task {
    do {
      let result: Bool = try await test()
      XCTAssertTrue(
        result,
        message(),
        file: file,
        line: line
      )
    }
    catch {
      XCTFail(
        message(),
        file: file,
        line: line
      )
    }
    sem.signal()
  }
  sem.wait()
}

// swift-format-ignore: AlwaysUseLowerCamelCase
public func XCTAssertFalse(
  _ message: @autoclosure @escaping () -> String = "",
  _ test: @escaping () async throws -> Bool,
  file: StaticString = #filePath,
  line: UInt = #line
) {
  let sem: DispatchSemaphore = .init(value: 0)
  Task {
    do {
      let result: Bool = try await test()
      XCTAssertFalse(
        result,
        message(),
        file: file,
        line: line
      )
    }
    catch {
      XCTFail(
        message(),
        file: file,
        line: line
      )
    }
    sem.signal()
  }
  sem.wait()
}

// swift-format-ignore: AlwaysUseLowerCamelCase
public func XCTAssertError<ExpectedError>(
  _ expression: @autoclosure () -> Error?,
  matches _: ExpectedError.Type,
  verification: (ExpectedError) -> Bool = { _ in true },
  _ message: @autoclosure () -> String? = nil,
  file: StaticString = #filePath,
  line: UInt = #line
) where ExpectedError: TheError {
  let error: Error? = expression()
  XCTAssert(
    (error as? ExpectedError).map(verification) ?? false,
    message() ?? "\(error.map { "\(type(of: $0))" } ?? "nil")) is not matching \(ExpectedError.self)",
    file: file,
    line: line
  )
}

// swift-format-ignore: AlwaysUseLowerCamelCase
public func XCTAssertErrorThrown<ExpectedError, Value>(
  _ expression: @autoclosure () throws -> Value,
  matches _: ExpectedError.Type,
  verification: (ExpectedError) -> Bool = { _ in true },
  _ message: @autoclosure () -> String? = nil,
  file: StaticString = #filePath,
  line: UInt = #line
) where ExpectedError: TheError {
  let thrownError: Error?
  do {
    _ = try expression()
    thrownError = nil
  }
  catch {
    thrownError = error
  }

  XCTAssert(
    (thrownError as? ExpectedError).map(verification) ?? false,
    message() ?? "\(thrownError.map { "\(type(of: $0))" } ?? "nil")) is not matching \(ExpectedError.self)",
    file: file,
    line: line
  )
}
