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

extension YubiKeyAuthorizationNetworkOperation {

  @Sendable fileprivate static func requestPreparation(
    _ input: Input
  ) -> Mutation<HTTPRequest> {
    .combined(
      .pathSuffix("/mfa/verify/yubikey.json"),
      .method(.post),
      .jsonBody(
        from: RequestBody(
          otp: input.otp,
          remember: input.remember
        )
      )
    )
  }

  @Sendable fileprivate static func responseDecoder(
    _ input: Input,
    _ response: HTTPResponse
  ) throws -> Output {
    if let cookieHeaderValue: String = response.headers["Set-Cookie"],
      let mfaCookieBounds: Range<String.Index> = cookieHeaderValue.range(of: "passbolt_mfa=")
    {
      return .init(
        mfaToken: .init(
          rawValue: String(
            cookieHeaderValue[mfaCookieBounds.upperBound...]
              .prefix(
                while: { !$0.isWhitespace && $0 != "," && $0 != ";" }
              )
          )
        )
      )
    }
    else {
      throw
        NetworkResponseDecodingFailure
        .error(
          "Failed to decode cookies from MFA response",
          response: response
        )
    }
  }
}

extension FeaturesRegistry {

  internal mutating func usePassboltYubiKeyAuthorizationNetworkOperation() {
    self.use(
      .networkOperationWithSession(
        of: YubiKeyAuthorizationNetworkOperation.self,
        requestPreparation: YubiKeyAuthorizationNetworkOperation.requestPreparation(_:),
        responseDecoding: YubiKeyAuthorizationNetworkOperation.responseDecoder(_:_:)
      )
    )
  }
}

private struct RequestBody: Encodable {

  private var otp: String
  private var remember: Bool

  private enum CodingKeys: String, CodingKey {
    case otp = "hotp"  // it is actually otp but backend expects hotp field
    case remember = "remember"
  }

  fileprivate init(
    otp: String,
    remember: Bool
  ) {
    self.otp = otp
    self.remember = remember
  }
}
