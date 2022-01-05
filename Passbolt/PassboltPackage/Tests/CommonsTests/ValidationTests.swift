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
final class ValidationTests: XCTestCase {

  var testValue: TestValue!
  var testEmbeddedValue: TestEmbeddedValue!

  private let messageKeyInvalid: LocalizedString.Key = "key.invalid"

  override func setUp() {
    super.setUp()
    testValue = TestValue(answer: "42")
    testEmbeddedValue = TestEmbeddedValue(value: TestValue(answer: "42"))
  }

  override func tearDown() {
    testValue = nil
    testEmbeddedValue = nil
    super.tearDown()
  }

  func test_valid_producesValidValue() {
    let validator: Validator<TestValue> = .alwaysValid
    let validated: Validated<TestValue> = validator(testValue)

    XCTAssertEqual(validated.value, testValue)
    XCTAssertTrue(validated.isValid)
  }

  func test_invalid_producesInvalidValue() {
    let validator: Validator<TestValue> = .alwaysInvalid(
      displayable: .localized(key: messageKeyInvalid)
    )
    let validated: Validated<TestValue> = validator(testValue)

    XCTAssertEqual(validated.value, testValue)
    XCTAssert(validated.errors.first?.identifier == .validation)
    XCTAssertFalse(validated.isValid)
    XCTAssert(validated.errors.count == 1)
    XCTAssert(validated.errors.first?.displayableString?.string() == messageKeyInvalid.rawValue)
  }

  func test_invalid_producesError() {
    let validator: Validator<TestValue> = .alwaysInvalid(
      displayable: .localized(key: messageKeyInvalid)
    )
    let validated: Validated<TestValue> = validator(testValue)

    XCTAssertEqual(validated.value, testValue)
    XCTAssertFalse(validated.isValid)
    XCTAssert(validated.errors.count == 1)

    XCTAssert(validated.errors.first?.displayableString?.string() == messageKeyInvalid.rawValue)
  }

  func test_contraMapFromValid_producesValidValue() {
    let validator: Validator<TestEmbeddedValue> = Validator<TestValue>.alwaysValid
      .contraMap(\.value)
    let validated: Validated<TestEmbeddedValue> = validator(testEmbeddedValue)

    XCTAssertEqual(validated.value, testEmbeddedValue)
    XCTAssertTrue(validated.isValid)
  }

  func test_contraMapFromInvalid_producesInvalidValue() {
    let validator: Validator<TestEmbeddedValue> = Validator<TestValue>.alwaysInvalid(
      displayable: .localized(key: messageKeyInvalid)
    )
    .contraMap(\.value)
    let validated: Validated<TestEmbeddedValue> = validator(testEmbeddedValue)

    XCTAssertEqual(validated.value, testEmbeddedValue)
    XCTAssertFalse(validated.isValid)
    XCTAssert(validated.errors.count == 1)
    XCTAssert(validated.errors.first?.displayableString?.string() == messageKeyInvalid.rawValue)
  }

  func test_zipFromValid_producesValidValue() {
    let validator: Validator<TestValue> = zip(
      Validator<TestValue>.alwaysValid,
      .alwaysValid
    )
    let validated: Validated<TestValue> = validator(testValue)

    XCTAssertEqual(validated.value, testValue)
    XCTAssertTrue(validated.isValid)
  }

  func test_zipFromInvalid_producesInvalidValueWithAllErrors() {
    let validator: Validator<TestValue> = zip(
      Validator<TestValue>
        .alwaysInvalid(
          displayable: .localized(key: messageKeyInvalid)
        ),
      .alwaysInvalid(
        displayable: .localized(key: messageKeyInvalid)
      )
    )
    let validated: Validated<TestValue> = validator(testValue)

    XCTAssertEqual(validated.value, testValue)
    XCTAssertFalse(validated.isValid)
    XCTAssert(validated.errors.count == 2)
    XCTAssert(validated.errors.first?.displayableString?.string() == messageKeyInvalid.rawValue)
  }
}

extension ValidationTests {

  struct TestValue: Equatable {

    var answer: String
  }

  struct TestEmbeddedValue: Equatable {

    var value: TestValue
  }
}
