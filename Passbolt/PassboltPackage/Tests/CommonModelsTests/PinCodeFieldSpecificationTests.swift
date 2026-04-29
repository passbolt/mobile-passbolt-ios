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

@testable import CommonModels

final class PinCodeFieldSpecificationTests: XCTestCase {

  // MARK: - Validation

  func test_validate_validDigitsWithinRange_doesNotThrow() throws {
    let spec: ResourceFieldSpecification = makeSpec(minLength: 4, maxLength: 8)

    XCTAssertNoThrow(try spec.validate(.string("1234")))
    XCTAssertNoThrow(try spec.validate(.string("12345")))
    XCTAssertNoThrow(try spec.validate(.string("12345678")))
  }

  func test_validate_boolJSON_throwsTypeError() {
    let spec: ResourceFieldSpecification = makeSpec(minLength: 4, maxLength: 8)
    let json: JSON = .bool(true)

    let expected: InvalidResourceField = .type(
      specification: spec,
      path: spec.path,
      value: json
    )

    XCTAssertThrowsError(try spec.validate(json)) { error in
      XCTAssertEqual(error as? InvalidResourceField, expected)
    }
  }

  func test_validate_integerJSON_isCoercedToDigitString() {
    let spec: ResourceFieldSpecification = makeSpec(minLength: 4, maxLength: 8)

    XCTAssertNoThrow(try spec.validate(.integer(1234)))
  }

  func test_validate_containsNonDigitCharacter_throwsDigitsOnlyError() {
    let spec: ResourceFieldSpecification = makeSpec(minLength: 4, maxLength: 8)

    let invalidValues: Array<String> = [
      "12a4",  // letter
      "1 34",  // space
      "12-4",  // dash
      "abcd",  // all letters
      "12.4",  // dot
      "1234😀",  // emoji
    ]

    for value in invalidValues {
      let json: JSON = .string(value)
      let expected: InvalidResourceField = .digitsOnly(
        specification: spec,
        path: spec.path,
        value: json
      )
      XCTAssertThrowsError(try spec.validate(json), "Expected throw for \(value)") { error in
        XCTAssertEqual(
          error as? InvalidResourceField,
          expected,
          "Mismatch for value: \(value)"
        )
      }
    }
  }

  func test_validate_belowMinimumLength_throwsMinimumLengthError() {
    let spec: ResourceFieldSpecification = makeSpec(minLength: 4, maxLength: 8)
    let json: JSON = .string("12")

    let expected: InvalidResourceField = .minimumLength(
      of: 4,
      specification: spec,
      path: spec.path,
      value: json
    )

    XCTAssertThrowsError(try spec.validate(json)) { error in
      XCTAssertEqual(error as? InvalidResourceField, expected)
    }
  }

  func test_validate_aboveMaximumLength_throwsMaximumLengthError() {
    let spec: ResourceFieldSpecification = makeSpec(minLength: 4, maxLength: 8)
    let json: JSON = .string("123456789")

    let expected: InvalidResourceField = .maximumLength(
      of: 8,
      specification: spec,
      path: spec.path,
      value: json
    )

    XCTAssertThrowsError(try spec.validate(json)) { error in
      XCTAssertEqual(error as? InvalidResourceField, expected)
    }
  }

  func test_validate_emptyStringWhenMinLengthPositive_throwsMinimumLengthError() {
    // Empty string passes the all-digit predicate vacuously, so the next
    // length check should fire — not the digits-only one.
    let spec: ResourceFieldSpecification = makeSpec(minLength: 4, maxLength: 8)
    let json: JSON = .string("")

    let expected: InvalidResourceField = .minimumLength(
      of: 4,
      specification: spec,
      path: spec.path,
      value: json
    )

    XCTAssertThrowsError(try spec.validate(json)) { error in
      XCTAssertEqual(error as? InvalidResourceField, expected)
    }
  }

  func test_validate_nullWhenRequired_throwsRequiredError() {
    let spec: ResourceFieldSpecification = makeSpec(
      minLength: 4,
      maxLength: 8,
      required: true
    )

    let expected: InvalidResourceField = .required(
      specification: spec,
      path: spec.path,
      value: .null
    )

    XCTAssertThrowsError(try spec.validate(.null)) { error in
      XCTAssertEqual(error as? InvalidResourceField, expected)
    }
  }

  func test_validate_nullWhenNotRequired_doesNotThrow() {
    let spec: ResourceFieldSpecification = makeSpec(
      minLength: 4,
      maxLength: 8,
      required: false
    )

    XCTAssertNoThrow(try spec.validate(.null))
  }

  func test_validate_minAndMaxEqual_acceptsExactLength() {
    let spec: ResourceFieldSpecification = makeSpec(minLength: 6, maxLength: 6)

    XCTAssertNoThrow(try spec.validate(.string("123456")))
    XCTAssertThrowsError(try spec.validate(.string("12345")))
    XCTAssertThrowsError(try spec.validate(.string("1234567")))
  }

  // MARK: - Semantics

  func test_init_pincodeContent_assignsPinCodeSemantics() {
    let spec: ResourceFieldSpecification = makeSpec(minLength: 4, maxLength: 8)

    if case .pinCode = spec.semantics {
      // expected
    }
    else {
      XCTFail("Expected .pinCode semantics, got \(spec.semantics)")
    }
  }

  // MARK: - Helpers

  private func makeSpec(
    minLength: Int,
    maxLength: Int,
    required: Bool = true
  ) -> ResourceFieldSpecification {
    ResourceFieldSpecification(
      path: \.secret.pin_code,
      name: .pinCode,
      content: .pincode(minLength: minLength, maxLength: maxLength),
      required: required,
      encrypted: true
    )
  }
}
