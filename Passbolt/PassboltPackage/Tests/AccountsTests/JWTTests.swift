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

import Features
import TestExtensions
import XCTest

@testable import Crypto

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class JWTTests: TestCase {

  func test_decodeValidToken_Succeeds() async throws {
    let jwt: JWT = try! .from(rawValue: validToken).get()

    XCTAssertEqual(jwt.header.algorithm, .rs256)
    XCTAssertEqual(jwt.header.type, "JWT")

    XCTAssertEqual(jwt.payload.audience, "ios")
    XCTAssertEqual(jwt.payload.expiration, 1_516_239_022)
    XCTAssertEqual(jwt.payload.subject, "1234567890")
  }

  func test_decode_withInvalidHeader_Fails() async throws {
    let result: Result<JWT, Error> = JWT.from(rawValue: tokenWithInvalidHeader)

    XCTAssertFailureUnderlyingError(
      result,
      matches: DataInvalid.self
    )
  }

  func test_decode_withInvalidPayload_Fails() async throws {
    let result: Result<JWT, Error> = JWT.from(rawValue: tokenWithInvalidPayload)

    XCTAssertFailureUnderlyingError(
      result,
      matches: DataInvalid.self
    )
  }

  func test_decode_withEmptyToken_Fails() async throws {
    let result: Result<JWT, Error> = JWT.from(rawValue: "")

    XCTAssertFailureUnderlyingError(
      result,
      matches: DataInvalid.self
    )
  }

  func test_decode_withMissingSignature_Fails() async throws {
    let result: Result<JWT, Error> = JWT.from(rawValue: tokenWithoutSignature)

    XCTAssertFailureUnderlyingError(
      result,
      matches: DataInvalid.self
    )
  }

  func test_decode_withMalformedToken_Fails() async throws {
    let result: Result<JWT, Error> = JWT.from(rawValue: malformedToken)

    XCTAssertFailureUnderlyingError(
      result,
      matches: DataInvalid.self
    )
  }

  func test_tokenIsNotExpired() async throws {
    let jwt: JWT = try! .from(rawValue: validToken).get()  // expiration = 1_516_239_022
    XCTAssertFalse(jwt.isExpired(timestamp: 1_516_000_000))
  }

  func test_tokenIsExpired() async throws {
    let jwt: JWT = try! .from(rawValue: validToken).get()  // expiration = 1_516_239_022
    XCTAssertTrue(jwt.isExpired(timestamp: 2_000_000_000))
  }

  func test_tokenIsExpiredEarlierWithLeeway() async throws {
    let jwt: JWT = try! .from(rawValue: validToken).get()  // expiration = 1_516_239_022
    XCTAssertTrue(jwt.isExpired(timestamp: 1_516_239_012, leeway: 10))
  }
}

private let validToken: String = """
  eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJpb3MiLCJleHAiOjE1MTYyMzkwMjIsImlzcyI6IlBhc3Nib2x0Iiwic3ViIjoiMTIzNDU2Nzg5MCJ9.mooyAR9uQ1F6sHMaA3Ya4bRKPazydqowEsgm-Sbr7RmED36CShWdF3a-FdxyezcgI85FPyF0Df1_AhTOknb0sPs-Yur1Oa0XwsDsXfpw-xJsnlx9JCylp6C6rm_rypJL1E8t_63QCS_k5rv7hpDc8ctjLW8mXoFXXP_bDkSezyPVUaRDvjLgaDm01Ocin112h1FvQZTittQhhdL-KU5C1HjCJn03zNmH46TihstdK7PZ7mRz2YgIpm9P-5JzYYmSV3eP70_0dVCC_lv0N3VJFLKVB9FP99R4jChJv5DEilEgMwi_73YsP3Z55rGDaoyjhj661rDteq-42LMXcvSmOg
  """

private let tokenWithInvalidHeader = """
  invalidHeader.eyJhdWQiOiJpb3MiLCJleHAiOjE1MTYyMzkwMjIsImlzcyI6IlBhc3Nib2x0Iiwic3ViIjoiMTIzNDU2Nzg5MCJ9.mooyAR9uQ1F6sHMaA3Ya4bRKPazydqowEsgm-Sbr7RmED36CShWdF3a-FdxyezcgI85FPyF0Df1_AhTOknb0sPs-Yur1Oa0XwsDsXfpw-xJsnlx9JCylp6C6rm_rypJL1E8t_63QCS_k5rv7hpDc8ctjLW8mXoFXXP_bDkSezyPVUaRDvjLgaDm01Ocin112h1FvQZTittQhhdL-KU5C1HjCJn03zNmH46TihstdK7PZ7mRz2YgIpm9P-5JzYYmSV3eP70_0dVCC_lv0N3VJFLKVB9FP99R4jChJv5DEilEgMwi_73YsP3Z55rGDaoyjhj661rDteq-42LMXcvSmOg
  """

private let tokenWithInvalidPayload: String = """
  eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.invalidPayload.mooyAR9uQ1F6sHMaA3Ya4bRKPazydqowEsgm-Sbr7RmED36CShWdF3a-FdxyezcgI85FPyF0Df1_AhTOknb0sPs-Yur1Oa0XwsDsXfpw-xJsnlx9JCylp6C6rm_rypJL1E8t_63QCS_k5rv7hpDc8ctjLW8mXoFXXP_bDkSezyPVUaRDvjLgaDm01Ocin112h1FvQZTittQhhdL-KU5C1HjCJn03zNmH46TihstdK7PZ7mRz2YgIpm9P-5JzYYmSV3eP70_0dVCC_lv0N3VJFLKVB9FP99R4jChJv5DEilEgMwi_73YsP3Z55rGDaoyjhj661rDteq-42LMXcvSmOg
  """

private let tokenWithoutSignature: String = """
  eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJpb3MiLCJleHAiOjE1MTYyMzkwMjIsImlzcyI6IlBhc3Nib2x0Iiwic3ViIjoiMTIzNDU2Nzg5MCJ
  """

private let malformedToken: String = """
  eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9#eyJhdWQiOiJpb3MiLCJleHAiOjE1MTYyMzkwMjIsImlzcyI6IlBhc3Nib2x0Iiwic3ViIjoiMTIzNDU2Nzg5MCJ9,mooyAR9uQ1F6sHMaA3Ya4bRKPazydqowEsgm-Sbr7RmED36CShWdF3a-FdxyezcgI85FPyF0Df1_AhTOknb0sPs-Yur1Oa0XwsDsXfpw-xJsnlx9JCylp6C6rm_rypJL1E8t_63QCS_k5rv7hpDc8ctjLW8mXoFXXP_bDkSezyPVUaRDvjLgaDm01Ocin112h1FvQZTittQhhdL-KU5C1HjCJn03zNmH46TihstdK7PZ7mRz2YgIpm9P-5JzYYmSV3eP70_0dVCC_lv0N3VJFLKVB9FP99R4jChJv5DEilEgMwi_73YsP3Z55rGDaoyjhj661rDteq-42LMXcvSmOg
  """

extension JWT: Equatable {

  public static func == (lhs: JWT, rhs: JWT) -> Bool {
    lhs.header == rhs.header && lhs.payload == rhs.payload && lhs.signature == rhs.signature
      && lhs.rawValue == rhs.rawValue
  }
}
