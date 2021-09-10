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

import CoreNFC
@testable import NFC
import TestExtensions
import XCTest

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class NDEFParserTests: TestCase {

  func test_parsePayloadContainingURI_succeeds() {
    let parser: NDEFParser = .yubikeyOTPParser()
    let messages: Array<NFCNDEFMessage> = [
      .init(records: [validPayloadContaingURI])
    ]

    let result: String? = parser.parse(messages)

    XCTAssertEqual(result, "cccccccccccggvetntitdeguhrledeeeeeeivbfeehe")
  }

  func test_parsePayloadContainingTextEmbeddedInURI_succeeds() {
    let parser: NDEFParser = .yubikeyOTPParser()
    let messages: Array<NFCNDEFMessage> = [
      .init(records: [validPayloadContaingTextEmbeddedInURI])
    ]

    let result: String? = parser.parse(messages)

    XCTAssertEqual(result, "cccccccccccccvetntitdeguhrledeeeeeeivbfeehe")
  }

  func test_parsePayloadContainingText_succeeds() {
    let parser: NDEFParser = .yubikeyOTPParser()
    let messages: Array<NFCNDEFMessage> = [
      .init(records: [validPayloadContainingText])
    ]

    let result: String? = parser.parse(messages)

    XCTAssertEqual(result, "cccccccccccccvetntitdeguhrledeeeeeeivbfeehe")
  }

  func test_parsePayloadContainingUnsupportedFormat_fails() {
    let parser: NDEFParser = .yubikeyOTPParser()
    let messages: Array<NFCNDEFMessage> = [
      .init(records: [invalidPayloadContainingURIWithUnsupportedFormat])
    ]

    let result: String? = parser.parse(messages)

    XCTAssertNil(result)
  }

  func test_parsePayloadContainingUnsupportedType_fails() {
    let parser: NDEFParser = .yubikeyOTPParser()
    let messages: Array<NFCNDEFMessage> = [
      .init(records: [invalidPayloadContainingURIWithInvalidType])
    ]

    let result: String? = parser.parse(messages)

    XCTAssertNil(result)
  }

  func test_parsePayloadContainingURI_withIllegalCharactersInOTP_fails() {
    let parser: NDEFParser = .yubikeyOTPParser()
    let messages: Array<NFCNDEFMessage> = [
      .init(records: [invalidPayloadContainingURIwithIllegalCharactersInOTP])
    ]

    let result: String? = parser.parse(messages)

    XCTAssertNil(result)
  }

  func test_parsePayloadContainingURI_withOTPLessThanMinLength_fails() {
    let parser: NDEFParser = .yubikeyOTPParser()
    let messages: Array<NFCNDEFMessage> = [
      .init(records: [invalidPayloadContainingUriWithOTPLessThanMinLength])
    ]

    let result: String? = parser.parse(messages)

    XCTAssertNil(result)
  }

  func test_parsePayloadContainingURI_withOTPExceedingMaxLength_fails() {
    let parser: NDEFParser = .yubikeyOTPParser()
    let messages: Array<NFCNDEFMessage> = [
      .init(records: [invalidPayloadContainingUriWithOTPExceedingMaxLength])
    ]

    let result: String? = parser.parse(messages)

    XCTAssertNil(result)
  }

  func test_parsePayloadContainingURI_withEmptyOTP_fails() {
    let parser: NDEFParser = .yubikeyOTPParser()
    let messages: Array<NFCNDEFMessage> = [
      .init(records: [emptyURIPayload])
    ]

    let result: String? = parser.parse(messages)

    XCTAssertNil(result)
  }

  func test_parsePayloadContainingText_withEmptyOTP_fails() {
    let parser: NDEFParser = .yubikeyOTPParser()
    let messages: Array<NFCNDEFMessage> = [
      .init(records: [emptyTextPayload])
    ]

    let result: String? = parser.parse(messages)

    XCTAssertNil(result)
  }
}

private let uriWithOTP: Data = "https://my.yubico.com/yk/#cccccccccccggvetntitdeguhrledeeeeeeivbfeehe".data(using: .utf8)!
private let otpTextEmbeddedInURI: Data = "https://my.yubico.com/yk/cccccccccccccvetntitdeguhrledeeeeeeivbfeehe".data(using: .utf8)!
private let otpText: Data = "cccccccccccccvetntitdeguhrledeeeeeeivbfeehe".data(using: .utf8)!
private let uriWithIllegalCharactersInOTP: Data = "https://my.yubico.com/yk/#passbolt_passbolt_passbolt_passbolt".data(using: .utf8)!
private let uriWithOTPLessThanMinLength: Data = "https://my.yubico.com/yk/#cc".data(using: .utf8)!
private let uriWithOTPExceedingMaxLength: Data = ("https://my.yubico.com/yk/#" + String(repeating: "cccccccccccccvetntitdeguhrledeeeeeeivbfeehe", count: 10)).data(using: .utf8)!

private let validPayloadContaingURI: NFCNDEFPayload = .init(
  format: .nfcWellKnown,
  type: .init([0x55]),
  identifier: .init(),
  payload: .init(uriWithOTP)
)

private let validPayloadContaingTextEmbeddedInURI: NFCNDEFPayload = .init(
  format: .nfcWellKnown,
  type: .init([0x54]),
  identifier: .init(),
  payload: .init(otpTextEmbeddedInURI)
)

private let validPayloadContainingText: NFCNDEFPayload = .init(
  format: .nfcWellKnown,
  type: .init([0x54]),
  identifier: .init(),
  payload: .init(otpText)
)

private let invalidPayloadContainingURIWithUnsupportedFormat: NFCNDEFPayload = .init(
  format: .unknown,
  type: .init([0x55]),
  identifier: .init(),
  payload: .init(uriWithOTP)
)

private let invalidPayloadContainingURIWithInvalidType: NFCNDEFPayload = .init(
  format: .nfcWellKnown,
  type: .init([0xFF]),
  identifier: .init(),
  payload: .init(uriWithOTP)
)

private let invalidPayloadContainingURIwithIllegalCharactersInOTP: NFCNDEFPayload = .init(
  format: .nfcWellKnown,
  type: .init([0x55]),
  identifier: .init(),
  payload: .init(uriWithIllegalCharactersInOTP)
)

private let invalidPayloadContainingUriWithOTPLessThanMinLength: NFCNDEFPayload = .init(
  format: .nfcWellKnown,
  type: .init([0x55]),
  identifier: .init(),
  payload: .init(uriWithOTPLessThanMinLength)
)

private let invalidPayloadContainingUriWithOTPExceedingMaxLength: NFCNDEFPayload = .init(
  format: .nfcWellKnown,
  type: .init([0x55]),
  identifier: .init(),
  payload: .init(uriWithOTPExceedingMaxLength)
)

private let emptyURIPayload: NFCNDEFPayload = .init(
  format: .nfcWellKnown,
  type: .init([0x55]),
  identifier: .init(),
  payload: .init()
)

private let emptyTextPayload: NFCNDEFPayload = .init(
  format: .nfcWellKnown,
  type: .init([0x54]),
  identifier: .init(),
  payload: .init()
)
