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
import NetworkOperations

// MARK: Implementation

extension SessionRefreshNetworkOperation {

  @Sendable fileprivate static func requestPreparation(
    _ input: Input
  ) -> Mutation<HTTPRequest> {
    .combined(
      .url(string: input.domain.rawValue),
      .pathSuffix("/auth/jwt/refresh.json"),
      .method(.post),
      .jsonBody(
        from: RequestBody(
          userID: input.userID,
          refreshToken: input.refreshToken
        )
      ),
      .whenSome(
        input.mfaToken,
        then: { mfaToken in
          .header("Cookie", value: "passbolt_mfa=\(mfaToken)")
        }
      )
    )
  }

  @Sendable fileprivate static func responseDecoder(
    _ input: Input,
    _ response: HTTPResponse
  ) throws -> Output {
    let decodedBody: ResponseBody =
      try NetworkResponseDecoder<Input, CommonNetworkResponse<ResponseBody>>
      .bodyAsJSON()
      .decode(
        input,
        response
      )
      .body

    guard
      let cookieHeaderValue: String = response.headers["Set-Cookie"],
      let refreshTokenBounds: Range<String.Index> = cookieHeaderValue.range(of: "refresh_token=")
    else {
      throw
        NetworkResponseInvalid
        .error(
          "Session refresh response does not contain refresh token",
          response: response
        )
    }
    let refreshToken: String = .init(
      cookieHeaderValue[refreshTokenBounds.upperBound...]
        .prefix(
          while: { !$0.isWhitespace && $0 != "," && $0 != ";" }
        )
    )
    let accessToken: SessionAccessToken =
      try SessionAccessToken
      .from(
        rawValue: decodedBody.accessToken
      )
      .get()

    return Output(
      accessToken: accessToken,
      refreshToken: .init(rawValue: refreshToken)
    )
  }
}

extension FeatureFactory {

  internal func usePassboltSessionRefreshNetworkOperation() {
    self.use(
      .networkOperation(
        of: SessionRefreshNetworkOperation.self,
        requestPreparation: SessionRefreshNetworkOperation.requestPreparation(_:),
        responseDecoding: SessionRefreshNetworkOperation.responseDecoder(_:_:)
      )
    )
  }
}

private struct RequestBody: Encodable {

  fileprivate var userID: Account.UserID
  fileprivate var refreshToken: SessionRefreshToken

  private enum CodingKeys: String, CodingKey {
    case userID = "user_id"
    case refreshToken = "refresh_token"
  }
}

private struct ResponseBody: Decodable {

  public var accessToken: String

  private enum CodingKeys: String, CodingKey {
    case accessToken = "access_token"
  }
}
