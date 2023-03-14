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

final class Base32DecoderTests: XCTestCase {

  func test_base32Decode_failsWithInvalidData() {
    XCTAssertNil(
      Data(base32Encoded: "1")
    )
    XCTAssertNil(
      Data(base32Encoded: "🤪")
    )
    XCTAssertNil(
      Data(base32Encoded: ";")
    )
  }

  func test_base32Decode_decodesValidData() {
    XCTAssertEqual(
      Data(base32Encoded: "")?.count,
      0
    )
    XCTAssertEqual(
      Data(base32Encoded: "a")?.count,
      0
    )
    XCTAssertEqual(
      Data(base32Encoded: "ab")?.count,
      2
    )
    XCTAssertEqual(
      Data(base32Encoded: "abc")?.count,
      2
    )
    XCTAssertEqual(
      Data(base32Encoded: "abcd")?.count,
      3
    )
    XCTAssertEqual(
      Data(base32Encoded: "I65VU7K5ZQL7WB4E")?.count,
      10
    )
    XCTAssertEqual(
      Data(base32Encoded: "OBQXG43CN5WHI==="),
      "passbolt".data(using: .utf8)
    )
    XCTAssertEqual(
      Data(base32Encoded: "OBQXG43CN5WHI"),
      "passbolt".data(using: .utf8)
    )
    XCTAssertEqual(
      Data(base32Encoded: "KRUGKIDROVUWG2ZAMJZG653OEBTG66BANJ2W24DTEBXXMZLSEB2GQZJANRQXU6JAMRXWOLQ="),
      "The quick brown fox jumps over the lazy dog.".data(using: .utf8)
    )
    XCTAssertEqual(
      Data(base32Encoded: "MY======"),
      "f".data(using: .utf8)
    )
    XCTAssertEqual(
      Data(base32Encoded: "MZXQ===="),
      "fo".data(using: .utf8)
    )
    XCTAssertEqual(
      Data(base32Encoded: "MZXW6==="),
      "foo".data(using: .utf8)
    )
    XCTAssertEqual(
      Data(base32Encoded: "MZXW6YQ="),
      "foob".data(using: .utf8)
    )
    XCTAssertEqual(
      Data(base32Encoded: "MZXW6YTB"),
      "fooba".data(using: .utf8)
    )
    XCTAssertEqual(
      Data(base32Encoded: "MZXW6YTBOI======"),
      "foobar".data(using: .utf8)
    )
  }
}
