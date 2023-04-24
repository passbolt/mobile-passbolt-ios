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
import Environment
import Foundation
import TestExtensions
import XCTest

@testable

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class NetworkResponseDecodingTests: XCTestCase {

  func test_rawBody_passesUnmodifiedData() async throws {
    let decoding: NetworkResponseDecoding<Void, Void, Data> = .rawBody
    let expectedBody: Data = Data([0x65, 0x66, 0x67, 0x68])

    let decodingResult: Data =
      try decoding
      .decode(
        Void(),
        Void(),
        HTTPRequest(
          url: .test,
          method: .get,
          headers: [:],
          body: .init()
        ),
        HTTPResponse(
          url: .test,
          statusCode: 200,
          headers: [:],
          body: expectedBody
        )
      )

    XCTAssertEqual(decodingResult, expectedBody)
  }

  func test_bodyAsString_withValidString_decodesString() throws {
    let decoding: NetworkResponseDecoding<Void, Void, String> = .bodyAsString()
    let expectedBody: String = "abcd"

    let decodingResult: String =
      try decoding
      .decode(
        Void(),
        Void(),
        HTTPRequest(
          url: .test,
          method: .get,
          headers: [:],
          body: .init()
        ),
        HTTPResponse(
          url: .test,
          statusCode: 200,
          headers: [:],
          body: expectedBody.data(using: .utf8)!
        )
      )

    XCTAssertEqual(decodingResult, expectedBody)
  }

  func test_bodyAsString_withInvalidString_fails() {
    let decoding: NetworkResponseDecoding<Void, Void, String> = .bodyAsString()

    do {
      _ =
        try decoding
        .decode(
          Void(),
          Void(),
          HTTPRequest(
            url: .test,
            method: .get,
            headers: [:],
            body: .init()
          ),
          HTTPResponse(
            url: .test,
            statusCode: 200,
            headers: [:],
            body: Data([0xff])
          )
        )
      XCTFail()
    }
    catch {
      // expected
    }
  }

  func test_bodyJSON_withValidJSON_decodesJSON() throws {
    let decoding: NetworkResponseDecoding<Void, Void, TestCodable> = .bodyAsJSON()
    let expectedBody: TestCodable = .sample

    let decodingResult: TestCodable =
      try decoding
      .decode(
        Void(),
        Void(),
        HTTPRequest(
          url: .test,
          method: .get,
          headers: [:],
          body: .init()
        ),
        HTTPResponse(
          url: .test,
          statusCode: 200,
          headers: [:],
          body: TestCodable.sampleJSONData
        )
      )

    XCTAssertEqual(decodingResult, expectedBody)
  }

  func test_bodyJSON_withInvalidJSON_fails() {
    let decoding: NetworkResponseDecoding<Void, Void, TestCodable> = .bodyAsJSON()

    do {
      _ =
        try decoding
        .decode(
          Void(),
          Void(),
          HTTPRequest(
            url: .test,
            method: .get,
            headers: [:],
            body: .init()
          ),
          HTTPResponse(
            url: .test,
            statusCode: 200,
            headers: [:],
            body: "{invalid]".data(using: .utf8)!
          )
        )
      XCTFail()
    }
    catch {
      // expected
    }
  }

  func test_succeesCodes_withStatusOk_succeeds() {
    let decoding: NetworkResponseDecoding<Void, Void, Void> = .statusCodes(200 ..< 400)

    do {
      _ =
        try decoding
        .decode(
          Void(),
          Void(),
          HTTPRequest(
            url: .test,
            method: .get,
            headers: [:],
            body: .init()
          ),
          HTTPResponse(
            url: .test,
            statusCode: 201,
            headers: [:],
            body: .empty
          )
        )
    }
    catch {
      XCTFail()
    }
  }

  func test_succeesCodes_withInvalidStatus_fails() {
    let decoding: NetworkResponseDecoding<Void, Void, Void> = .statusCodes(200 ..< 400)
    do {
      try decoding
        .decode(
          Void(),
          Void(),
          HTTPRequest(
            url: .test,
            method: .get,
            headers: [:],
            body: .init()
          ),
          HTTPResponse(
            url: .test,
            statusCode: 401,
            headers: [:],
            body: .empty
          )
        )
      XCTFail()
    }
    catch {
      // expected
    }
  }

  func test_mfaErrorDecodingUsingCorrectData_resultsInMfaRequiredError() {
    let decoding: NetworkResponseDecoding<Void, Void, MFARequiredResponse> = .bodyAsJSON()
    let body: MFARequiredResponseBody = .init(mfaProviders: [.yubiKey, .totp])
    let response: CommonResponse<MFARequiredResponseBody> =
      CommonResponse(
        header: CommonResponseHeader(
          id: "1",
          message: "MFA authentication is required."
        ),
        body: body
      )

    let httpBody: Data = try! JSONEncoder().encode(response)

    do {
      _ =
        try decoding
        .decode(
          Void(),
          Void(),
          HTTPRequest(
            url: .test,
            method: .get,
            headers: [:],
            body: .init()
          ),
          HTTPResponse(
            url: .test,
            statusCode: 403,
            headers: [:],
            body: httpBody
          )
        )
      XCTFail("Unexpected success")
    }
    catch {
      XCTAssertError(
        error,
        matches: SessionMFAAuthorizationRequired.self
      ) { error in
        error.mfaProviders == [MFAProvider.yubiKey, MFAProvider.totp]
      }
    }
  }

  func test_mfaErrorDecodingUsingCorrectData_andEmptyProviders_resultsMFARequiredError() {
    let decoding: NetworkResponseDecoding<Void, Void, MFARequiredResponse> = .bodyAsJSON()
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

    do {
      _ =
        try decoding
        .decode(
          Void(),
          Void(),
          HTTPRequest(
            url: .test,
            method: .get,
            headers: [:],
            body: .init()
          ),
          HTTPResponse(
            url: .test,
            statusCode: 403,
            headers: [:],
            body: httpBody
          )
        )
      XCTFail("Unexpected success")
    }
    catch {
      XCTAssertError(error, matches: SessionMFAAuthorizationRequired.self)
    }
  }

  func test_mfaErrorDecodingUsingCorruptedData_resultsInForbiddenError() {
    let decoding: NetworkResponseDecoding<Void, Void, MFARequiredResponse> = .bodyAsJSON()

    do {
      _ =
        try decoding
        .decode(
          Void(),
          Void(),
          HTTPRequest(
            url: .test,
            method: .get,
            headers: [:],
            body: .init()
          ),
          HTTPResponse(
            url: .test,
            statusCode: 403,
            headers: [:],
            body: Data([0x01, 0x02, 0x03])
          )
        )
      XCTFail("Unexpected success")
    }
    catch {
      XCTAssertError(error, matches: HTTPForbidden.self)
    }
  }

  func test_redirectWithLocationHeader_fails_withRedirectError() {
    let decoding: NetworkResponseDecoding<Void, Void, MFARequiredResponse> = .bodyAsJSON()

    do {
      _ =
        try decoding
        .decode(
          Void(),
          Void(),
          HTTPRequest(
            url: .test,
            method: .get,
            headers: [:],
            body: .init()
          ),
          HTTPResponse(
            url: .test,
            statusCode: 302,
            headers: ["Location": "https://passbolt.com"],
            body: Data([0x01, 0x02, 0x03])
          )
        )
      XCTFail("Unexpected success")
    }
    catch {
      XCTAssertError(
        error,
        matches: HTTPRedirect.self
      ) { error in
        error.location == URL(string: "https://passbolt.com")!
      }
    }
  }

  func test_redirectWithNoLocationHeader_fails_withInvalidResponseError() {
    let decoding: NetworkResponseDecoding<Void, Void, MFARequiredResponse> = .bodyAsJSON()

    do {
      _ =
        try decoding
        .decode(
          Void(),
          Void(),
          HTTPRequest(
            url: .test,
            method: .get,
            headers: [:],
            body: .init()
          ),
          HTTPResponse(
            url: .test,
            statusCode: 302,
            headers: [:],
            body: Data([0x01, 0x02, 0x03])
          )
        )
      XCTFail("Unexpected success")
    }
    catch {
      XCTAssertError(error, matches: NetworkResponseInvalid.self)
    }
  }

  func test_decodeBadRequest_fromResponse_withEmptyBody_fails_networkResponseDecodingFailedError() {
    let decoding: NetworkResponseDecoding<Void, Void, TestCodable> = .bodyAsJSON()

    do {
      _ =
        try decoding
        .decode(
          Void(),
          Void(),
          HTTPRequest(
            url: .test,
            method: .get,
            headers: [:],
            body: .init()
          ),
          HTTPResponse(
            url: .test,
            statusCode: 400,
            headers: [:],
            body: Data()
          )
        )
      XCTFail("Unexpected success")
    }
    catch {
      XCTAssertError(error, matches: NetworkResponseDecodingFailure.self)
    }
  }

  func test_decodeBadRequest_fromResponse_withEmptyJsonInBody_fails_validationViolationError() {
    let decoding: NetworkResponseDecoding<Void, Void, TestCodable> = .bodyAsJSON()

    do {
      _ =
        try decoding
        .decode(
          Void(),
          Void(),
          HTTPRequest(
            url: .test,
            method: .get,
            headers: [:],
            body: .init()
          ),
          HTTPResponse(
            url: .test,
            statusCode: 400,
            headers: [:],
            body: "{}".data(using: .utf8)!
          )
        )
      XCTFail("Unexpected success")
    }
    catch {
      XCTAssertError(error, matches: NetworkRequestValidationFailure.self)
    }
  }

  func test_decodeBadRequest_fromResponse_withValidJsonInBody_fails_validationViolationError() {
    let decoding: NetworkResponseDecoding<Void, Void, TestCodable> = .bodyAsJSON()

    do {
      _ =
        try decoding
        .decode(
          Void(),
          Void(),
          HTTPRequest(
            url: .test,
            method: .get,
            headers: [:],
            body: .init()
          ),
          HTTPResponse(
            url: .test,
            statusCode: 400,
            headers: [:],
            body: TestCodable.sampleJSONData
          )
        )
      XCTFail("Unexpected success")
    }
    catch {
      XCTAssertError(
        error,
        matches: NetworkRequestValidationFailure.self
      ) { error in
        !error.validationViolations.isEmpty
      }
    }
  }
}
