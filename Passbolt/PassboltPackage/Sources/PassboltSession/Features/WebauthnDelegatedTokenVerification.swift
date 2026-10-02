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

import Crypto
import Session

import struct Foundation.Data
import class Foundation.JSONDecoder

/// Local verification of the delegated token handed back by the passkey ceremony page.
///
/// The server verifies the token again when it is consumed, checking it here first
/// ensures the token was issued by the account server for the ceremony prompted by
/// this application before it is sent anywhere.
/// Mirrors `MfaWebauthnDelegatedTokenService::create()` on the server side.
internal enum WebauthnDelegatedTokenVerification {

  /// Matches `MfaWebauthnDelegatedTokenService::AUDIENCE` on the server side.
  internal static let expectedAudience: String = "passbolt-mobile-mfa-exchange"

  internal static func verify(
    _ delegatedToken: String,
    expectedIssuer: URLString,
    expectedState: String,
    serverPublicRSAKey: PEMRSAPublicKey,
    timestamp: Timestamp,
    signatureVerification: SignatureVerification
  ) throws {
    let token: JWT
    let ceremonyID: String
    do {
      token = try JWT.from(rawValue: delegatedToken).get()
      ceremonyID = try decodeCeremonyID(from: delegatedToken)
    }
    catch {
      throw
        WebauthnAuthorizationFailure
        .error("Failed to decode the passkey delegated token")
        .recording(error, for: "underlyingError")
    }

    guard
      let signature: Data = token.signature.rawValue.base64DecodeFromURLEncoded(),
      let signedData: Data = token.signedPayload.data(using: .utf8)
    else {
      throw
        WebauthnAuthorizationFailure
        .error("Failed to prepare the passkey delegated token signature verification")
    }

    do {
      try signatureVerification
        .verify(
          signedData,
          signature,
          serverPublicRSAKey
        )
        .get()
    }
    catch {
      throw
        WebauthnAuthorizationFailure
        .error("The passkey delegated token signature verification failed")
        .recording(error, for: "underlyingError")
    }

    guard !token.isExpired(timestamp: timestamp)
    else {
      throw
        WebauthnAuthorizationFailure
        .error("The passkey delegated token is expired")
    }

    guard
      let issuer: String = token.payload.issuer,
      issuerMatches(issuer, expectedIssuer: expectedIssuer)
    else {
      throw
        WebauthnAuthorizationFailure
        .error("The passkey delegated token issuer does not match the account domain")
    }

    guard token.payload.audience == expectedAudience
    else {
      throw
        WebauthnAuthorizationFailure
        .error("The passkey delegated token audience is not valid")
    }

    guard constantTimeEquals(ceremonyID, expectedState)
    else {
      throw
        WebauthnAuthorizationFailure
        .error("The passkey delegated token was not issued for the prompted ceremony")
    }
  }

  // the server issues the token with its full base url (`Router::url('/', true)`),
  // which ends with a slash, while the account domain is stored without it
  private static func issuerMatches(
    _ issuer: String,
    expectedIssuer: URLString
  ) -> Bool {
    trimmingTrailingSlashes(issuer) == trimmingTrailingSlashes(expectedIssuer.rawValue)
  }

  private static func trimmingTrailingSlashes(
    _ value: String
  ) -> String {
    var trimmed: Substring = Substring(value)
    while trimmed.hasSuffix("/") {
      trimmed = trimmed.dropLast()
    }
    return String(trimmed)
  }

  private static func constantTimeEquals(
    _ lhs: String,
    _ rhs: String
  ) -> Bool {
    let lhsBytes: Array<UInt8> = Array(lhs.utf8)
    let rhsBytes: Array<UInt8> = Array(rhs.utf8)
    guard lhsBytes.count == rhsBytes.count
    else { return false }

    var difference: UInt8 = 0
    for index: Int in lhsBytes.indices {
      difference |= lhsBytes[index] ^ rhsBytes[index]
    }
    return difference == 0
  }

  private static func decodeCeremonyID(
    from delegatedToken: String
  ) throws -> String {
    let components: Array<String> = delegatedToken.components(separatedBy: ".")
    guard
      components.count == 3,
      let payloadData: Data = components[1].base64DecodeFromURLEncoded()
    else {
      throw
        DataInvalid
        .error("Invalid passkey delegated token payload")
    }

    return
      try JSONDecoder.default
      .decode(
        CeremonyClaims.self,
        from: payloadData
      )
      .ceremonyID
  }
}

private struct CeremonyClaims: Decodable {

  fileprivate var ceremonyID: String

  private enum CodingKeys: String, CodingKey {
    case ceremonyID = "cid"
  }
}
