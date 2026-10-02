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

import TestExtensions

@testable import PassboltSession

// swift-format-ignore: AlwaysUseLowerCamelCase
final class WebauthnDelegatedTokenVerificationTests: TestCase {

  func test_verify_succeeds_withValidToken() throws {
    try verify(DelegatedTokenClaims.valid.encoded())
  }

  func test_verify_succeeds_withIssuerWithoutTrailingSlash() throws {
    var claims: DelegatedTokenClaims = .valid
    claims.iss = "https://passbolt.example.com"

    try verify(claims.encoded())
  }

  func test_verify_succeeds_withSubfolderDomain() throws {
    var claims: DelegatedTokenClaims = .valid
    claims.iss = "https://example.com/passbolt/"

    try verify(
      claims.encoded(),
      expectedIssuer: "https://example.com/passbolt"
    )
  }

  func test_verify_succeeds_withAnyPayloadLength() throws {
    // growing the payload by one byte at a time covers every base64 padding length
    for tokenID: String in ["a", "ab", "abc"] {
      var claims: DelegatedTokenClaims = .valid
      claims.jti = tokenID

      try verify(claims.encoded())
    }
  }

  func test_verify_throws_withMalformedToken() {
    XCTAssertThrowsError(
      try verify("not-a-token")
    ) { (error: Error) in
      XCTAssertTrue(error is WebauthnAuthorizationFailure)
    }
  }

  func test_verify_throws_withoutCeremonyID() {
    var claims: DelegatedTokenClaims = .valid
    claims.cid = .none

    XCTAssertThrowsError(
      try verify(claims.encoded())
    ) { (error: Error) in
      XCTAssertTrue(error is WebauthnAuthorizationFailure)
    }
  }

  func test_verify_throws_whenSignatureVerificationFails() {
    XCTAssertThrowsError(
      try verify(
        DelegatedTokenClaims.valid.encoded(),
        signatureVerification: .mock { _, _, _ in .failure(MockIssue.error()) }
      )
    ) { (error: Error) in
      XCTAssertTrue(error is WebauthnAuthorizationFailure)
    }
  }

  func test_verify_verifiesSignature_ofSignedPartWithServerKey() throws {
    let token: String = try DelegatedTokenClaims.valid.encoded()
    let expectedSignedData: Data = .init(
      token
        .components(separatedBy: ".")
        .prefix(2)
        .joined(separator: ".")
        .utf8
    )
    let verifiedData: CriticalState<Data?> = .init(.none)
    let verifiedKey: CriticalState<PEMRSAPublicKey?> = .init(.none)

    try verify(
      token,
      signatureVerification: .mock { (data: Data, _, key: PEMRSAPublicKey) in
        verifiedData.set(data)
        verifiedKey.set(key)
        return .success(Void())
      }
    )

    XCTAssertEqual(verifiedData.get(), expectedSignedData)
    XCTAssertEqual(verifiedKey.get(), "server-rsa-key")
  }

  func test_verify_throws_withExpiredToken() {
    XCTAssertThrowsError(
      try verify(
        DelegatedTokenClaims.valid.encoded(),
        timestamp: Timestamp(rawValue: DelegatedTokenClaims.valid.exp)
      )
    ) { (error: Error) in
      XCTAssertTrue(error is WebauthnAuthorizationFailure)
    }
  }

  func test_verify_throws_withOtherIssuer() {
    var claims: DelegatedTokenClaims = .valid
    claims.iss = "https://other.example.com/"

    XCTAssertThrowsError(
      try verify(claims.encoded())
    ) { (error: Error) in
      XCTAssertTrue(error is WebauthnAuthorizationFailure)
    }
  }

  func test_verify_throws_withoutIssuer() {
    var claims: DelegatedTokenClaims = .valid
    claims.iss = .none

    XCTAssertThrowsError(
      try verify(claims.encoded())
    ) { (error: Error) in
      XCTAssertTrue(error is WebauthnAuthorizationFailure)
    }
  }

  func test_verify_throws_withOtherAudience() {
    var claims: DelegatedTokenClaims = .valid
    claims.aud = "passbolt-other-audience"

    XCTAssertThrowsError(
      try verify(claims.encoded())
    ) { (error: Error) in
      XCTAssertTrue(error is WebauthnAuthorizationFailure)
    }
  }

  func test_verify_throws_withOtherState() {
    XCTAssertThrowsError(
      try verify(
        DelegatedTokenClaims.valid.encoded(),
        expectedState: "other-state"
      )
    ) { (error: Error) in
      XCTAssertTrue(error is WebauthnAuthorizationFailure)
    }
  }

  func test_verify_throws_withStatePrefix() {
    XCTAssertThrowsError(
      try verify(
        DelegatedTokenClaims.valid.encoded(),
        expectedState: "delegated"
      )
    ) { (error: Error) in
      XCTAssertTrue(error is WebauthnAuthorizationFailure)
    }
  }

  private func verify(
    _ delegatedToken: String,
    expectedIssuer: URLString = "https://passbolt.example.com",
    expectedState: String = "delegated-state",
    timestamp: Timestamp = 0,
    signatureVerification: SignatureVerification = .mock { _, _, _ in .success(Void()) }
  ) throws {
    try WebauthnDelegatedTokenVerification
      .verify(
        delegatedToken,
        expectedIssuer: expectedIssuer,
        expectedState: expectedState,
        serverPublicRSAKey: "server-rsa-key",
        timestamp: timestamp,
        signatureVerification: signatureVerification
      )
  }
}

/// Claims of the delegated token as issued by `MfaWebauthnDelegatedTokenService::create()`.
private struct DelegatedTokenClaims: Encodable {

  fileprivate static let valid: Self = .init(
    iss: "https://passbolt.example.com/",
    aud: WebauthnDelegatedTokenVerification.expectedAudience,
    sub: "user-id",
    cid: "delegated-state",
    jti: "token-id",
    iat: 0,
    exp: 1_000
  )

  fileprivate var iss: String?
  fileprivate var aud: String
  fileprivate var sub: String
  fileprivate var cid: String?
  fileprivate var jti: String
  fileprivate var iat: Int64
  fileprivate var exp: Int64

  /// Encodes the claims into a token, its signature is not valid
  /// so the signature verification has to be mocked.
  fileprivate func encoded() throws -> String {
    let header: String = #"{"alg":"RS256","typ":"JWT"}"#
    let payload: Data = try JSONEncoder().encode(self)
    return [
      Self.base64URLEncoded(Data(header.utf8)),
      Self.base64URLEncoded(payload),
      Self.base64URLEncoded(Data("signature".utf8)),
    ]
    .joined(separator: ".")
  }

  private static func base64URLEncoded(
    _ data: Data
  ) -> String {
    data
      .base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }
}

extension SignatureVerification {

  fileprivate static func mock(
    _ verify: @escaping @Sendable (Data, Data, PEMRSAPublicKey) -> Result<Void, Error>
  ) -> Self {
    var verification: Self = .placeholder
    verification.verify = verify
    return verification
  }
}
