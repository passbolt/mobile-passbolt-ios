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

import CommonModels
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
public func XCTAssertError<ExpectedError>(
  _ expression: @autoclosure () -> Error?,
  matches _: ExpectedError.Type,
  verification: (ExpectedError) -> Bool = { _ in true },
  _ message: @autoclosure () -> String? = nil,
  file: StaticString = #filePath,
  line: UInt = #line
) where ExpectedError: Error {
  let error: Error? = expression()
  XCTAssert(
    (error as? ExpectedError).map(verification) ?? false,
    message() ?? "\(error.map { "\(type(of: $0))" } ?? "nil") is not matching \(ExpectedError.self)",
    file: file,
    line: line
  )
}

// swift-format-ignore: AlwaysUseLowerCamelCase
public func XCTAssertUnderlyingError<ExpectedError>(
  _ expression: @autoclosure () -> TheErrorWrapper?,
  matches _: ExpectedError.Type,
  verification: (ExpectedError) -> Bool = { _ in true },
  _ message: @autoclosure () -> String? = nil,
  file: StaticString = #filePath,
  line: UInt = #line
) where ExpectedError: Error {
  let error: TheErrorWrapper? = expression()
  XCTAssert(
    (error?.underlyingError as? ExpectedError).map(verification) ?? false,
    message()
      ?? "\((error?.underlyingError).map { "\(type(of: $0))" } ?? "nil")) is not matching \(ExpectedError.self)",
    file: file,
    line: line
  )
}

// swift-format-ignore: AlwaysUseLowerCamelCase
public func XCTAssertUnderlyingError<ExpectedRootError, ExpectedError>(
  _ expression: @autoclosure () -> Error?,
  root _: ExpectedRootError.Type,
  matches _: ExpectedError.Type,
  verification: (ExpectedError) -> Bool = { _ in true },
  _ message: @autoclosure () -> String? = nil,
  file: StaticString = #filePath,
  line: UInt = #line
) where ExpectedRootError: TheErrorWrapper, ExpectedError: Error {
  let error: Error? = expression()
  XCTAssert(
    ((error as? ExpectedRootError)?.underlyingError as? ExpectedError).map(verification) ?? false,
    message()
      ?? "\(((error as? ExpectedRootError)?.underlyingError).map { "\(type(of: $0))" } ?? "nil")) is not matching \(ExpectedError.self)",
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
) where ExpectedError: Error {
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

// swift-format-ignore: AlwaysUseLowerCamelCase
public func XCTAssertFailureError<Value, Failure, ExpectedError>(
  _ expression: @autoclosure () -> Result<Value, Failure>,
  matches _: ExpectedError.Type,
  verification: (ExpectedError) -> Bool = { _ in true },
  _ message: @autoclosure () -> String? = nil,
  file: StaticString = #filePath,
  line: UInt = #line
) where Failure: Error, ExpectedError: Error {
  let result: Result<Value, Failure> = expression()
  guard case let .failure(error) = result
  else {
    return XCTFail(
      message() ?? "\(result)) is not a failure",
      file: file,
      line: line
    )
  }
  XCTAssert(
    (error as? ExpectedError).map(verification) ?? false,
    message() ?? "\(type(of: error)) is not matching \(ExpectedError.self)",
    file: file,
    line: line
  )
}

// swift-format-ignore: AlwaysUseLowerCamelCase
public func XCTAssertFailureError<Value, Failure>(
  _ expression: @autoclosure () -> Result<Value, Failure>,
  verification: (Failure) -> Bool,
  _ message: @autoclosure () -> String? = nil,
  file: StaticString = #filePath,
  line: UInt = #line
) where Failure: Error {
  XCTAssertFailureError(
    expression(),
    matches: Failure.self,
    verification: verification,
    message(),
    file: file,
    line: line
  )
}

// swift-format-ignore: AlwaysUseLowerCamelCase
public func XCTAssertFailureUnderlyingError<Value, Failure, ExpectedError>(
  _ expression: @autoclosure () -> Result<Value, Failure>,
  matches _: ExpectedError.Type,
  verification: (ExpectedError) -> Bool = { _ in true },
  _ message: @autoclosure () -> String? = nil,
  file: StaticString = #filePath,
  line: UInt = #line
) where Failure: Error, ExpectedError: Error {
  let result: Result<Value, Failure> = expression()
  guard case let .failure(error) = result
  else {
    return XCTFail(
      message() ?? "\(result)) is not a failure",
      file: file,
      line: line
    )
  }
  XCTAssert(
    ((error as? TheErrorWrapper)?.underlyingError as? ExpectedError).map(verification) ?? false,
    message() ?? "\(type(of: (error as? TheErrorWrapper)?.underlyingError)) is not matching \(ExpectedError.self)",
    file: file,
    line: line
  )
}

// swift-format-ignore: AlwaysUseLowerCamelCase
public func XCTAssertFailureUnderlyingError<Value, Failure, ExpectedRootError, ExpectedError>(
  _ expression: @autoclosure () -> Result<Value, Failure>,
  root _: ExpectedRootError.Type,
  matches _: ExpectedError.Type,
  verification: (ExpectedError) -> Bool = { _ in true },
  _ message: @autoclosure () -> String? = nil,
  file: StaticString = #filePath,
  line: UInt = #line
) where Failure: Error, ExpectedRootError: TheErrorWrapper, ExpectedError: Error {
  let result: Result<Value, Failure> = expression()
  guard case let .failure(error) = result
  else {
    return XCTFail(
      message() ?? "\(result)) is not a failure",
      file: file,
      line: line
    )
  }
  guard let rootError: ExpectedRootError = error as? ExpectedRootError
  else {
    return XCTFail(
      message() ?? "\(type(of: error)) is not matching expected root error",
      file: file,
      line: line
    )
  }
  guard let expectedError: ExpectedError = rootError.underlyingError as? ExpectedError
  else {
    return XCTFail(
      message() ?? "\(type(of: rootError.underlyingError)) is not matching expected error",
      file: file,
      line: line
    )
  }
  XCTAssert(
    verification(expectedError),
    message() ?? "\(expectedError) is not passing verification",
    file: file,
    line: line
  )
}

// |==| |==|

// swift-format-ignore: AlwaysUseLowerCamelCase
public func XCTAssertValue<Value>(
  equal expectedValue: Value,
  file: StaticString = #filePath,
  line: UInt = #line,
  _ expression: () async throws -> Value
) async where Value: Equatable {
  let value: Value?
  do {
    value = try await expression()
    XCTAssertEqual(
      value,
      expectedValue,
      file: file,
      line: line
    )
  }
  catch {
    return XCTFail(
      "Unexpected error thrown: \(error)",
      file: file,
      line: line
    )
  }
}

// swift-format-ignore: AlwaysUseLowerCamelCase
public func XCTAssertError<ExpectedError, Value>(
  matches _: ExpectedError.Type,
  verification: (ExpectedError) -> Bool = { _ in true },
  file: StaticString = #filePath,
  line: UInt = #line,
  _ expression: () async throws -> Value
) async where ExpectedError: Error {
  do {
    let value: Value = try await expression()
    return XCTFail(
      "Expected error was not thrown, received: \(value)",
      file: file,
      line: line
    )
  }
  catch {
    if let expectedError: ExpectedError = error as? ExpectedError {
      XCTAssertTrue(
        verification(expectedError),
        "\(error) is not passing verification",
        file: file,
        line: line
      )
    }
    else {
      XCTFail(
        "\(type(of: error)) is not matching \(ExpectedError.self)",
        file: file,
        line: line
      )
    }
  }
}

// swift-format-ignore: AlwaysUseLowerCamelCase
public func XCTAssertNoError<Value>(
  file: StaticString = #filePath,
  line: UInt = #line,
  _ expression: () async throws -> Value
) async {
  do {
    let _: Value = try await expression()
  }
  catch {
    XCTFail(
      "\(type(of: error)) thrown while no error was expected.",
      file: file,
      line: line
    )
  }
}
