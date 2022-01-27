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

public typealias RefreshSessionRequest =
  NetworkRequest<EmptyNetworkSessionVariable, RefreshSessionRequestVariable, RefreshSessionResponse>

extension RefreshSessionRequest {

  internal static func live(
    using networking: Networking,
    with sessionVariablePublisher: AnyPublisher<EmptyNetworkSessionVariable, Error>
  ) -> Self {
    Self(
      template: .init { sessionVariable, requestVariable in
        .combined(
          .url(string: requestVariable.domain.rawValue),
          .pathSuffix("/auth/jwt/refresh.json"),
          .method(.post),
          .jsonBody(
            from: RefreshSessionRequestBody(
              userID: requestVariable.userID,
              refreshToken: requestVariable.refreshToken
            )
          ),
          .whenSome(
            requestVariable.mfaToken,
            then: { mfaToken in
              .header("Cookie", value: "passbolt_mfa=\(mfaToken)")
            }
          )
        )
      },
      responseDecoder: .sessionRefreshResponse(),
      using: networking,
      with: sessionVariablePublisher
    )
  }
}

public struct RefreshSessionRequestVariable {

  public var domain: URLString
  public var userID: String
  public var refreshToken: String
  public var mfaToken: String?

  public init(
    domain: URLString,
    userID: String,
    refreshToken: String,
    mfaToken: String?
  ) {
    self.domain = domain
    self.userID = userID
    self.refreshToken = refreshToken
    self.mfaToken = mfaToken
  }
}

private struct RefreshSessionRequestBody: Encodable {

  fileprivate var userID: String
  fileprivate var refreshToken: String

  private enum CodingKeys: String, CodingKey {
    case userID = "user_id"
    case refreshToken = "refresh_token"
  }
}

public struct RefreshSessionResponse {

  public var accessToken: String
  public var refreshToken: String

  public init(
    accessToken: String,
    refreshToken: String
  ) {
    self.accessToken = accessToken
    self.refreshToken = refreshToken
  }
}

public struct RefreshSessionResponseBody: Decodable {

  public var accessToken: String

  private enum CodingKeys: String, CodingKey {
    case accessToken = "access_token"
  }

  public init(
    accessToken: String
  ) {
    self.accessToken = accessToken
  }
}

extension NetworkResponseDecoding
where
  Response == RefreshSessionResponse,
  SessionVariable == EmptyNetworkSessionVariable,
  RequestVariable == RefreshSessionRequestVariable
{

  fileprivate static func sessionRefreshResponse() -> Self {
    Self { sessionVariable, requestVariable, httpRequest, httpResponse -> Result<RefreshSessionResponse, Error> in

      guard
        let cookieHeaderValue: String = httpResponse.headers["Set-Cookie"],
        let refreshTokenBounds: Range<String.Index> = cookieHeaderValue.range(of: "refresh_token=")
      else {
        return .failure(
          NetworkResponseInvalid
            .error(
              "Session refresh response does not contain refresh token",
              response: httpResponse
            )
        )
      }
      let refreshToken: String = .init(
        cookieHeaderValue[refreshTokenBounds.upperBound...]
          .prefix(
            while: { !$0.isWhitespace && $0 != "," && $0 != ";" }
          )
      )

      return NetworkResponseDecoding<SessionVariable, RequestVariable, CommonResponse<RefreshSessionResponseBody>>
        .bodyAsJSON()
        .decode(sessionVariable, requestVariable, httpRequest, httpResponse)
        .map { body -> RefreshSessionResponse in
          RefreshSessionResponse(
            accessToken: body.body.accessToken,
            refreshToken: refreshToken
          )
        }
    }
  }
}
