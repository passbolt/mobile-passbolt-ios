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

import NetworkOperations

// MARK: Implementation

extension SessionCreateNetworkOperation {

  @Sendable fileprivate static func requestPreparation(
    _ input: Input
  ) -> Mutation<HTTPRequest> {
    .combined(
      .url(string: input.domain.rawValue),
      .pathSuffix("/auth/jwt/login.json"),
      .method(.post),
      .whenSome(
        input.mfaToken,
        then: { mfaToken in
          .header("Cookie", value: "passbolt_mfa=\(mfaToken)")
        }
      ),
      .jsonBody(from: input.requestBody)
    )
  }

  @Sendable fileprivate static func responseDecoder(
    _ input: Input,
    _ response: HTTPResponse
  ) throws -> Output {
    let mfaTokenIsValid: Bool
    if let mfaToken: SessionMFAToken = input.mfaToken {
      if let cookieHeaderValue: String = response.headers["Set-Cookie"],
        let mfaCookieBounds: Range<String.Index> = cookieHeaderValue.range(of: "passbolt_mfa=")
      {
        let mfaCookieValue: String = .init(
          cookieHeaderValue[mfaCookieBounds.upperBound...]
            .prefix(
              while: { !$0.isWhitespace && $0 != "," && $0 != ";" }
            )
        )
        if mfaToken.rawValue == mfaCookieValue {
          mfaTokenIsValid = true  // it was sent and server responded with same value - valid
        }
        else {
          mfaTokenIsValid = false  // it was sent but server responded with different value - invalid
        }
      }
      else {
        mfaTokenIsValid = false  // it was sent but server responded with no value - invalid
      }
    }
    else {
      mfaTokenIsValid = false  // it was not sent so it is not valid (but that does not matter if it is not required)
    }

    let decodedBody: ResponseBody =
      try NetworkResponseDecoder<Input, CommonNetworkResponse<ResponseBody>>
      .bodyAsJSON()
      .decode(
        input,
        response
      )
      .body

    return Output(
      mfaTokenIsValid: mfaTokenIsValid,
      challenge: .init(
        rawValue: decodedBody.challenge
      )
    )
  }
}

extension FeatureFactory {

  internal func usePassboltSessionCreateNetworkOperation() {
    self.use(
      FeatureLoader.networkOperation(
        of: SessionCreateNetworkOperation.self,
        requestPreparation: SessionCreateNetworkOperation.requestPreparation(_:),
        responseDecoding: SessionCreateNetworkOperation.responseDecoder(_:_:)
      )
    )
  }
}

extension SessionCreateNetworkOperationVariable {

  fileprivate var requestBody: RequestBody {
    .init(
      userID: self.userID,
      challenge: self.challenge
    )
  }
}

private struct RequestBody: Encodable {

  fileprivate var userID: Account.UserID
  fileprivate var challenge: ArmoredPGPMessage

  fileprivate init(
    userID: Account.UserID,
    challenge: ArmoredPGPMessage
  ) {
    self.userID = userID
    self.challenge = challenge
  }

  private enum CodingKeys: String, CodingKey {

    case userID = "user_id"
    case challenge = "challenge"
  }
}

private struct ResponseBody: Decodable {

  fileprivate var challenge: String
}
