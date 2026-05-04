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

@preconcurrency import CoreNFC
import TestExtensions
import XCTest

@testable import NFC

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class NDEFParserTests: XCTestCase {

  @MainActor func test_parsePayloadContainingURI_succeeds() {
    let parser: NDEFParser = .yubiKeyOTPParser()
    let messages: Array<NFCNDEFMessage> = [
      .init(records: [validPayloadContaingURI])
    ]

    let result: Result<String, Error> = parser.parse(messages)

    XCTAssertSuccessEqual(result, "cccccccccccggvetntitdeguhrledeeeeeeivbfeehe")
  }

  @MainActor func test_parsePayloadContainingTextEmbeddedInURI_succeeds() {
    let parser: NDEFParser = .yubiKeyOTPParser()
    let messages: Array<NFCNDEFMessage> = [
      .init(records: [validPayloadContaingTextEmbeddedInURI])
    ]

    let result: Result<String, Error> = parser.parse(messages)

    XCTAssertSuccessEqual(result, "cccccccccccccvetntitdeguhrledeeeeeeivbfeehe")
  }

  @MainActor func test_parsePayloadContainingText_succeeds() {
    let parser: NDEFParser = .yubiKeyOTPParser()
    let messages: Array<NFCNDEFMessage> = [
      .init(records: [validPayloadContainingText])
    ]

    let result: Result<String, Error> = parser.parse(messages)

    XCTAssertSuccessEqual(result, "cccccccccccccvetntitdeguhrledeeeeeeivbfeehe")
  }

  @MainActor func test_parsePayloadContainingUnsupportedFormat_fails() {
    let parser: NDEFParser = .yubiKeyOTPParser()
    let messages: Array<NFCNDEFMessage> = [
      .init(records: [invalidPayloadContainingURIWithUnsupportedFormat])
    ]

    let result: Result<String, Error> = parser.parse(messages)

    XCTAssertFailure(result)
  }

  @MainActor func test_parsePayloadContainingUnsupportedType_fails() {
    let parser: NDEFParser = .yubiKeyOTPParser()
    let messages: Array<NFCNDEFMessage> = [
      .init(records: [invalidPayloadContainingURIWithInvalidType])
    ]

    let result: Result<String, Error> = parser.parse(messages)

    XCTAssertFailure(result)
  }

  @MainActor func test_parsePayloadContainingURI_withIllegalCharactersInOTP_fails() {
    let parser: NDEFParser = .yubiKeyOTPParser()
    let messages: Array<NFCNDEFMessage> = [
      .init(records: [invalidPayloadContainingURIwithIllegalCharactersInOTP])
    ]

    let result: Result<String, Error> = parser.parse(messages)

    XCTAssertFailure(result)
  }

  @MainActor func test_parsePayloadContainingURI_withOTPLessThanMinLength_fails() {
    let parser: NDEFParser = .yubiKeyOTPParser()
    let messages: Array<NFCNDEFMessage> = [
      .init(records: [invalidPayloadContainingUriWithOTPLessThanMinLength])
    ]

    let result: Result<String, Error> = parser.parse(messages)

    XCTAssertFailure(result)
  }

  @MainActor func test_parsePayloadContainingURI_withOTPExceedingMaxLength_fails() {
    let parser: NDEFParser = .yubiKeyOTPParser()
    let messages: Array<NFCNDEFMessage> = [
      .init(records: [invalidPayloadContainingUriWithOTPExceedingMaxLength])
    ]

    let result: Result<String, Error> = parser.parse(messages)

    XCTAssertFailure(result)
  }

  @MainActor func test_parsePayloadContainingURI_withEmptyOTP_fails() {
    let parser: NDEFParser = .yubiKeyOTPParser()
    let messages: Array<NFCNDEFMessage> = [
      .init(records: [emptyURIPayload])
    ]

    let result: Result<String, Error> = parser.parse(messages)

    XCTAssertFailure(result)
  }

  @MainActor func test_parsePayloadContainingText_withEmptyOTP_fails() {
    let parser: NDEFParser = .yubiKeyOTPParser()
    let messages: Array<NFCNDEFMessage> = [
      .init(records: [emptyTextPayload])
    ]

    let result: Result<String, Error> = parser.parse(messages)

    XCTAssertFailure(result)
  }
}

private let uriWithOTP: Data = "https://my.yubico.com/yk/#cccccccccccggvetntitdeguhrledeeeeeeivbfeehe"
  .data(
    using: .utf8
  )!
private let otpTextEmbeddedInURI: Data = "https://my.yubico.com/yk/cccccccccccccvetntitdeguhrledeeeeeeivbfeehe"
  .data(
    using: .utf8
  )!
private let otpText: Data = "cccccccccccccvetntitdeguhrledeeeeeeivbfeehe".data(using: .utf8)!
private let uriWithIllegalCharactersInOTP: Data = "https://my.yubico.com/yk/#passbolt_passbolt_passbolt_passbolt"
  .data(
    using: .utf8
  )!
private let uriWithOTPLessThanMinLength: Data = "https://my.yubico.com/yk/#cc".data(using: .utf8)!
private let uriWithOTPExceedingMaxLength: Data =
  ("https://my.yubico.com/yk/#" + String(repeating: "cccccccccccccvetntitdeguhrledeeeeeeivbfeehe", count: 10))
  .data(
    using: .utf8
  )!

@MainActor private let validPayloadContaingURI: NFCNDEFPayload = .init(
  format: .nfcWellKnown,
  type: .init([0x55]),
  identifier: .init(),
  payload: .init(uriWithOTP)
)

@MainActor private let validPayloadContaingTextEmbeddedInURI: NFCNDEFPayload = .init(
  format: .nfcWellKnown,
  type: .init([0x54]),
  identifier: .init(),
  payload: .init(otpTextEmbeddedInURI)
)

@MainActor private let validPayloadContainingText: NFCNDEFPayload = .init(
  format: .nfcWellKnown,
  type: .init([0x54]),
  identifier: .init(),
  payload: .init(otpText)
)

@MainActor private let invalidPayloadContainingURIWithUnsupportedFormat: NFCNDEFPayload = .init(
  format: .unknown,
  type: .init([0x55]),
  identifier: .init(),
  payload: .init(uriWithOTP)
)

@MainActor private let invalidPayloadContainingURIWithInvalidType: NFCNDEFPayload = .init(
  format: .nfcWellKnown,
  type: .init([0xFF]),
  identifier: .init(),
  payload: .init(uriWithOTP)
)

@MainActor private let invalidPayloadContainingURIwithIllegalCharactersInOTP: NFCNDEFPayload = .init(
  format: .nfcWellKnown,
  type: .init([0x55]),
  identifier: .init(),
  payload: .init(uriWithIllegalCharactersInOTP)
)

@MainActor private let invalidPayloadContainingUriWithOTPLessThanMinLength: NFCNDEFPayload = .init(
  format: .nfcWellKnown,
  type: .init([0x55]),
  identifier: .init(),
  payload: .init(uriWithOTPLessThanMinLength)
)

@MainActor private let invalidPayloadContainingUriWithOTPExceedingMaxLength: NFCNDEFPayload = .init(
  format: .nfcWellKnown,
  type: .init([0x55]),
  identifier: .init(),
  payload: .init(uriWithOTPExceedingMaxLength)
)

@MainActor private let emptyURIPayload: NFCNDEFPayload = .init(
  format: .nfcWellKnown,
  type: .init([0x55]),
  identifier: .init(),
  payload: .init()
)

@MainActor private let emptyTextPayload: NFCNDEFPayload = .init(
  format: .nfcWellKnown,
  type: .init([0x54]),
  identifier: .init(),
  payload: .init()
)
