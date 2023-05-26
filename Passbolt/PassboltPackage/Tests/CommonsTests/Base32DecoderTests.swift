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
    XCTAssertNotNil(
      Data(base32Encoded: "ABCDEFGHIJKLMNOPQRSTUWXYZ234567")
    )
    XCTAssertEqual(
      Data(base32Encoded: "abcdefghijklmnopqrstuwxyz234567"),
      Data(base32Encoded: "ABCDEFGHIJKLMNOPQRSTUWXYZ234567")
    )
    XCTAssertEqual(
      Data(base32Encoded: ""),
      Data([])
    )
    XCTAssertEqual(
      Data(base32Encoded: "z"),
      Data([])
    )
    XCTAssertEqual(
      Data(base32Encoded: "zx"),
      Data([0xCD])
    )
    XCTAssertEqual(
      Data(base32Encoded: "zxy"),
      Data([0xCD])
    )
    XCTAssertEqual(
      Data(base32Encoded: "zxyw"),
      Data([0xCD, 0xF1])
    )
    XCTAssertEqual(
      Data(base32Encoded: "I65VU7K5ZQL7WB4E"),
      Data([0x47, 0xBB, 0x5A, 0x7D, 0x5D, 0xCC, 0x17, 0xFB, 0x07, 0x84])
    )
    XCTAssertEqual(
      Data(base32Encoded: "AAAB"),
      Data([0x0, 0x0])
    )
    XCTAssertEqual(
      Data(base32Encoded: "OBQXG43CN5WHI===")
        .map { String(data: $0, encoding: .utf8) },
      "passbolt"
    )
    XCTAssertEqual(
      Data(base32Encoded: "OBQXG43CN5WHI")
        .map { String(data: $0, encoding: .utf8) },
      "passbolt"
    )
    XCTAssertEqual(
      Data(base32Encoded: "KRUGKIDROVUWG2ZAMJZG653OEBTG66BANJ2W24DTEBXXMZLSEB2GQZJANRQXU6JAMRXWOLQ=".uppercased()),
      Data(base32Encoded: "KRUGKIDROVUWG2ZAMJZG653OEBTG66BANJ2W24DTEBXXMZLSEB2GQZJANRQXU6JAMRXWOLQ=".lowercased())
    )
    XCTAssertEqual(
      Data(base32Encoded: "KRUGKIDROVUWG2ZAMJZG653OEBTG66BANJ2W24DTEBXXMZLSEB2GQZJANRQXU6JAMRXWOLQ=")
        .map { String(data: $0, encoding: .utf8) },
      "The quick brown fox jumps over the lazy dog."
    )
    XCTAssertEqual(
      Data(base32Encoded: "MY======")
        .map { String(data: $0, encoding: .utf8) },
      "f"
    )
    XCTAssertEqual(
      Data(base32Encoded: "MZXQ====")
        .map { String(data: $0, encoding: .utf8) },
      "fo"
    )
    XCTAssertEqual(
      Data(base32Encoded: "MZXW6===")
        .map { String(data: $0, encoding: .utf8) },
      "foo"
    )
    XCTAssertEqual(
      Data(base32Encoded: "MZXW6YQ=")
        .map { String(data: $0, encoding: .utf8) },
      "foob"
    )
    XCTAssertEqual(
      Data(base32Encoded: "MZXW6YTB")
        .map { String(data: $0, encoding: .utf8) },
      "fooba"
    )
    XCTAssertEqual(
      Data(base32Encoded: "MZXW6YTBOI======")
        .map { String(data: $0, encoding: .utf8) },
      "foobar"
    )
  }
}
