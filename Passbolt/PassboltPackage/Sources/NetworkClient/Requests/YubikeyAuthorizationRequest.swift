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

public typealias YubikeyAuthorizationRequest =
  NetworkRequest<AuthorizedSessionVariable, YubikeyAuthorizationRequestVariable, YubikeyAuthorizationResponse>

extension YubikeyAuthorizationRequest {

  internal static func live(
    using networking: Networking,
    with sessionVariablePublisher: AnyPublisher<AuthorizedSessionVariable, TheError>
  ) -> Self {
    Self(
      template: .init { sessionVariable, requestVariable in
        .combined(
          .url(string: sessionVariable.domain),
          .path("/mfa/verify/yubikey.json"),
          .method(.post),
          .header("Authorization", value: "Bearer \(sessionVariable.authorizationToken)"),
          .jsonBody(from: requestVariable)
        )
      },
      responseDecoder: .mfaCookie,
      using: networking,
      with: sessionVariablePublisher
    )
  }
}

public struct YubikeyAuthorizationRequestVariable: Encodable {

  public var otp: String

  private enum CodingKeys: String, CodingKey {
    case otp = "hotp" // it is actually otp but backend expects hotp field
  }

  public init(
    otp: String
  ) {
    self.otp = otp
  }
}

public struct YubikeyAuthorizationResponse {

  public var mfaToken: MFAToken

  public init(
    mfaToken: MFAToken
  ) {
    self.mfaToken = mfaToken
  }
}

extension NetworkResponseDecoding where Response == YubikeyAuthorizationResponse {

  fileprivate static var mfaCookie: Self {
    Self { httpResponse in
      if
        let cookieHeaderValue: String = httpResponse.headers["Set-cookie"],
        let mfaCookieBounds: Range<String.Index> = cookieHeaderValue.range(of: "passbolt_mfa=")
      {
        return .success(
          .init(
            mfaToken: .init(
              rawValue: String(
                cookieHeaderValue[mfaCookieBounds.upperBound...]
                  .prefix(
                    while: { !$0.isWhitespace && $0 != "," && $0 != ";" }
                  )
              )
            )
          )
        )
      } else {
        return .failure(
          .networkResponseDecodingFailed(
            underlyingError: nil,
            rawNetworkResponse: httpResponse
          )
        )
      }
    }
  }
}


