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

import struct Foundation.Data

@testable import Database

// Guards the exact bytes handed to SQLCipher. The legacy length in particular is load bearing:
// databases created before the raw key migration were keyed including the terminating NUL,
// so shortening it by one byte would make every one of them fail to decrypt.
// swift-format-ignore: AlwaysUseLowerCamelCase
final class SQLiteConnectionKeyTests: XCTestCase {

  func test_rawKey_isWrappedInSQLCipherRawKeySyntax() {
    let key: SQLiteConnectionKey = .raw(Data([0x00, 0x01, 0xab, 0xff]))

    XCTAssertEqual(key.sqlCipherRepresentation, "x'0001abff'")
  }

  func test_rawKey_byteCountExcludesTerminator() {
    let key: SQLiteConnectionKey = .raw(Data(repeating: 0x2d, count: 32))

    // "x'" + 64 hex characters + "'"
    XCTAssertEqual(key.sqlCipherByteCount, 67)
    XCTAssertEqual(
      Int(key.sqlCipherByteCount),
      key.sqlCipherRepresentation.utf8.count
    )
  }

  func test_passphraseDerivedKey_isPassedThroughUnchanged() {
    let derived: String = String(repeating: "a", count: 128)
    let key: SQLiteConnectionKey = .passphraseDerived(derived)

    XCTAssertEqual(key.sqlCipherRepresentation, derived)
  }

  func test_passphraseDerivedKey_byteCountIncludesTerminator() {
    let derived: String = String(repeating: "a", count: 128)
    let key: SQLiteConnectionKey = .passphraseDerived(derived)

    XCTAssertEqual(key.sqlCipherByteCount, 129)
  }
}
