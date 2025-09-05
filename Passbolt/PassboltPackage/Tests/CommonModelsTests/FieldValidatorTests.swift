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

@testable import CommonModels

final class FieldValidatorTests: XCTestCase {

  func test_base32_validString_passes() throws {
    let validator = FieldValidator<String>.base32

    XCTAssertNoThrow(
      try validator("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")
    )
  }

  func test_base32_validStringWithPadding_passes() throws {
    let validator = FieldValidator<String>.base32

    XCTAssertNoThrow(
      try validator("MFRGG43FMZQW4ZLNMVZGG2LOM4======")
    )
  }

  func test_base32_emptyString_passes() throws {
    let validator = FieldValidator<String>.base32

    XCTAssertNoThrow(
      try validator("")
    )
  }

  func test_base32_lowercaseString_passes() throws {
    let validator = FieldValidator<String>.base32

    XCTAssertNoThrow(
      try validator("mfrgg43fmzqw4zlnmvzgg2lom4")
    )
  }

  func test_base32_mixedCaseString_passes() throws {
    let validator = FieldValidator<String>.base32

    XCTAssertNoThrow(
      try validator("MfRgG43FmZqW4zLnMvZgG2LoM4")
    )
  }

  func test_base32_invalidCharacter_throws() throws {
    let validator = FieldValidator<String>.base32

    XCTAssertThrowsError(
      try validator("INVALID8CHARACTER")
    ) { error in
      guard
        let validationError = error as? FieldValidator<String>.ValidationError
      else {
        XCTFail("Expected ValidationError")
        return
      }
      XCTAssertEqual(
        String(describing: validationError.message),
        "Value is not valid base32 encoded string"
      )
    }
  }

  func test_base32_numberZero_throws() throws {
    let validator = FieldValidator<String>.base32

    XCTAssertThrowsError(
      try validator("INVALID0CHARACTER")
    ) { error in
      XCTAssertTrue(error is FieldValidator<String>.ValidationError)
    }
  }

  func test_base32_numberOne_throws() throws {
    let validator = FieldValidator<String>.base32

    XCTAssertThrowsError(
      try validator("INVALID1CHARACTER")
    ) { error in
      XCTAssertTrue(error is FieldValidator<String>.ValidationError)
    }
  }

  func test_base32_numberNine_throws() throws {
    let validator = FieldValidator<String>.base32

    XCTAssertThrowsError(
      try validator("INVALID9CHARACTER")
    ) { error in
      XCTAssertTrue(error is FieldValidator<String>.ValidationError)
    }
  }

  func test_base32_specialCharacters_throws() throws {
    let validator = FieldValidator<String>.base32

    let invalidStrings = [
      "ABC!DEF",
      "ABC@DEF",
      "ABC#DEF",
      "ABC$DEF",
      "ABC%DEF",
      "ABC^DEF",
      "ABC&DEF",
      "ABC*DEF",
      "ABC(DEF",
      "ABC)DEF",
      "ABC-DEF",
      "ABC_DEF",
      "ABC+DEF",
      "ABC DEF",
      "ABC.DEF",
      "ABC/DEF",
    ]

    for invalidString in invalidStrings {
      XCTAssertThrowsError(
        try validator(invalidString)
      ) { error in
        XCTAssertTrue(error is FieldValidator<String>.ValidationError)
      }
    }
  }

  func test_base32_unicodeCharacters_throws() throws {
    let validator = FieldValidator<String>.base32

    XCTAssertThrowsError(
      try validator("ABC🚀DEF")
    ) { error in
      XCTAssertTrue(error is FieldValidator<String>.ValidationError)
    }
  }

  func test_base32_validBase32EncodedStrings_pass() throws {
    let validator = FieldValidator<String>.base32

    let validBase32Strings = [
      "JBSWY3DPEHPK3PXP",
      "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ",
      "MFRGG43FMZQW4ZLNMVZGG2LOM4======",
      "NRXXEZLNMQQHK3TPOMQGC3LMMU======",
      "A",
      "AB",
      "ABC",
      "ABCD",
      "ABCDE",
      "ABCDEF",
      "ABCDEFG",
    ]

    for validString in validBase32Strings {
      XCTAssertNoThrow(
        try validator(validString),
        "Should not throw for valid base32 string: \(validString)"
      )
    }
  }

  func test_base32_allValidCharacters_pass() throws {
    let validator = FieldValidator<String>.base32

    let allValidCharacters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567="

    XCTAssertNoThrow(
      try validator(allValidCharacters)
    )
  }

  func test_base32_onlyPaddingCharacters_passes() throws {
    let validator = FieldValidator<String>.base32

    XCTAssertNoThrow(
      try validator("========")
    )
  }

  func test_base32_longValidString_passes() throws {
    let validator = FieldValidator<String>.base32

    let longValidString = String(
      repeating: "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567",
      count: 100
    )

    XCTAssertNoThrow(
      try validator(longValidString)
    )
  }
}
