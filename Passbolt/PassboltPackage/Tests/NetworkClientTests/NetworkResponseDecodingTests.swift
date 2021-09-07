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
import Environment
import Foundation
import TestExtensions
import XCTest

@testable import NetworkClient

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class NetworkResponseDecodingTests: XCTestCase {

  func test_rawBody_passesUnmodifiedData() {
    let decoding: NetworkResponseDecoding<Data> = .rawBody
    let expectedBody: Data = Data([0x65, 0x66, 0x67, 0x68])

    let decodingResult: Result<Data, TheError> =
      decoding
      .decode(
        HTTPResponse(
          url: .test,
          statusCode: 200,
          headers: [:],
          body: expectedBody
        )
      )

    XCTAssertSuccessEqual(decodingResult, expectedBody)
  }

  func test_bodyAsString_withValidString_decodesString() {
    let decoding: NetworkResponseDecoding<String> = .bodyAsString()
    let expectedBody: String = "abcd"

    let decodingResult: Result<String, TheError> =
      decoding
      .decode(
        HTTPResponse(
          url: .test,
          statusCode: 200,
          headers: [:],
          body: expectedBody.data(using: .utf8)!
        )
      )

    XCTAssertSuccessEqual(decodingResult, expectedBody)
  }

  func test_bodyAsString_withInvalidString_fails() {
    let decoding: NetworkResponseDecoding<String> = .bodyAsString()

    let decodingResult: Result<String, TheError> =
      decoding
      .decode(
        HTTPResponse(
          url: .test,
          statusCode: 200,
          headers: [:],
          body: Data([0xff])
        )
      )

    XCTAssertFailure(decodingResult)
  }

  func test_bodyJSON_withValidJSON_decodesJSON() {
    let decoding: NetworkResponseDecoding<TestCodable> = .bodyAsJSON()
    let expectedBody: TestCodable = .sample

    let decodingResult: Result<TestCodable, TheError> =
      decoding
      .decode(
        HTTPResponse(
          url: .test,
          statusCode: 200,
          headers: [:],
          body: TestCodable.sampleJSONData
        )
      )

    XCTAssertSuccessEqual(decodingResult, expectedBody)
  }

  func test_bodyJSON_withInvalidJSON_fails() {
    let decoding: NetworkResponseDecoding<TestCodable> = .bodyAsJSON()

    let decodingResult: Result<TestCodable, TheError> =
      decoding
      .decode(
        HTTPResponse(
          url: .test,
          statusCode: 200,
          headers: [:],
          body: "{invalid]".data(using: .utf8)!
        )
      )

    XCTAssertFailure(decodingResult)
  }

  func test_succeesCodes_withStatusOk_succeeds() {
    let decoding: NetworkResponseDecoding<Void> = .statusCodes(200..<400)

    let decodingResult: Result<Void, TheError> =
      decoding
      .decode(
        HTTPResponse(
          url: .test,
          statusCode: 201,
          headers: [:],
          body: .empty
        )
      )

    XCTAssertSuccess(decodingResult)
  }

  func test_succeesCodes_withInvalidStatus_fails() {
    let decoding: NetworkResponseDecoding<Void> = .statusCodes(200..<400)

    let decodingResult: Result<Void, TheError> =
      decoding
      .decode(
        HTTPResponse(
          url: .test,
          statusCode: 401,
          headers: [:],
          body: .empty
        )
      )

    XCTAssertFailure(decodingResult)
  }

  func test_mfaErrorDecodingUsingCorrectData_resultsInMfaRequiredError() {
    let decoding: NetworkResponseDecoding<MFARequiredResponse> = .bodyAsJSON()
    let body: MFARequiredResponseBody = .init(mfaProviders: [.yubikey, .totp])
    let response: CommonResponse<MFARequiredResponseBody> =
      CommonResponse(
        header: CommonResponseHeader(
          id: "1",
          message: "MFA authentication is required."
        ),
        body: body
      )

    let httpBody: Data = try! JSONEncoder().encode(response)

    let decodingResult: Result<MFARequiredResponse, TheError> =
      decoding
      .decode(
        HTTPResponse(
          url: .test,
          statusCode: 403,
          headers: [:],
          body: httpBody
        )
      )

    guard case let .failure(error) = decodingResult
    else {
      XCTFail("Unexpected success")
      return
    }

    XCTAssertEqual(error.identifier, .mfaRequired)
    XCTAssertEqual(error.mfaRequiredProviders, [MFAProvider.yubikey, MFAProvider.totp])
  }

  func test_mfaErrorDecodingUsingCorrectData_andEmptyProviders_resultsInForbiddenError() {
    let decoding: NetworkResponseDecoding<MFARequiredResponse> = .bodyAsJSON()
    let body: MFARequiredResponseBody = .init(mfaProviders: [])
    let response: CommonResponse<MFARequiredResponseBody> =
      CommonResponse(
        header: CommonResponseHeader(
          id: "1",
          message: "MFA authentication is required."
        ),
        body: body
      )

    let httpBody: Data = try! JSONEncoder().encode(response)

    let decodingResult: Result<MFARequiredResponse, TheError> =
      decoding
      .decode(
        HTTPResponse(
          url: .test,
          statusCode: 403,
          headers: [:],
          body: httpBody
        )
      )

    guard case let .failure(error) = decodingResult
    else {
      XCTFail("Unexpected success")
      return
    }

    XCTAssertEqual(error.identifier, .forbidden)
  }

  func test_mfaErrorDecodingUsingCorruptedData_resultsInForbiddenError() {
    let decoding: NetworkResponseDecoding<MFARequiredResponse> = .bodyAsJSON()

    let decodingResult: Result<MFARequiredResponse, TheError> =
      decoding
      .decode(
        HTTPResponse(
          url: .test,
          statusCode: 403,
          headers: [:],
          body: Data([0x01, 0x02, 0x03])
        )
      )

    guard case let .failure(error) = decodingResult
    else {
      XCTFail("Unexpected success")
      return
    }

    XCTAssertEqual(error.identifier, .forbidden)
  }
}
