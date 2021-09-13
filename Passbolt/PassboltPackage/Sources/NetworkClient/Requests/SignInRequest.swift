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
import Crypto
import Environment

public typealias SignInRequest = NetworkRequest<DomainSessionVariable, SignInRequestVariable, SignInResponse>

extension SignInRequest {

  internal static func live(
    using networking: Networking,
    with sessionVariablePublisher: AnyPublisher<DomainSessionVariable, TheError>
  ) -> Self {
    Self(
      template: .init { sessionVariable, requestVariable in
        .combined(
          .url(string: sessionVariable.domain),
          .path("/auth/jwt/login.json"),
          .method(.post),
          .whenSome(
            requestVariable.mfaToken,
            then: { mfaToken in
              .header("Cookie", value: "passbolt_mfa=\(mfaToken)")
            }
          ),
          .jsonBody(from: requestVariable.signInRequestBody)
        )
      },
      responseDecoder: .bodyAsJSON(),
      using: networking,
      with: sessionVariablePublisher
    )
  }
}

public struct SignInRequestVariable {

  public var userID: String
  public var challenge: ArmoredPGPMessage
  public var mfaToken: MFAToken?

  public init(
    userID: String,
    challenge: ArmoredPGPMessage,
    mfaToken: MFAToken?
  ) {
    self.userID = userID
    self.challenge = challenge
    self.mfaToken = mfaToken
  }

  fileprivate var signInRequestBody: SignInRequestBody {
    SignInRequestBody(
      userID: userID,
      challenge: challenge
    )
  }
}

private struct SignInRequestBody: Encodable {

  fileprivate var userID: String
  fileprivate var challenge: ArmoredPGPMessage

  fileprivate init(
    userID: String,
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

public struct SignInRequestChallenge: Encodable {

  public var version: String
  public var token: String
  public var domain: String
  public var expiration: Int

  public init(
    version: String,
    token: String,
    domain: String,
    expiration: Int
  ) {
    self.version = version
    self.token = token
    self.domain = domain
    self.expiration = expiration
  }

  private enum CodingKeys: String, CodingKey {

    case version = "version"
    case token = "verify_token"
    case domain = "domain"
    case expiration = "verify_token_expiry"
  }
}

public typealias SignInResponse = CommonResponse<SignInResponseBody>

public struct SignInResponseBody: Decodable {

  public var challenge: String
}

public struct Tokens: Codable, Equatable {

  public var version: String
  public var domain: String
  public var verificationToken: String
  public var accessToken: String
  public var refreshToken: String

  private enum CodingKeys: String, CodingKey {

    case version = "version"
    case domain = "domain"
    case verificationToken = "verify_token"
    case accessToken = "access_token"
    case refreshToken = "refresh_token"
  }
}
