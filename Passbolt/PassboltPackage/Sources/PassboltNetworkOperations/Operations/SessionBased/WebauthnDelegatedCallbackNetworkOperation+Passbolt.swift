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

extension WebauthnDelegatedCallbackNetworkOperation {

  @Sendable fileprivate static func requestPreparation(
    _ input: Input
  ) -> Mutation<HTTPRequest> {
    .combined(
      .pathSuffix("/mfa/verify/webauthn/delegated/callback.json"),
      .method(.post),
      .jsonBody(
        from: RequestBody(
          exchangeCode: input.exchangeCode,
          remember: input.remember
        )
      )
    )
  }

  @Sendable fileprivate static func responseDecoder(
    _ input: Input,
    _ response: HTTPResponse
  ) throws -> Output {
    try .init(
      mfaToken: decodedSessionMFAToken(from: response)
    )
  }
}

extension FeaturesRegistry {

  internal mutating func usePassboltWebauthnDelegatedCallbackNetworkOperation() {
    self.use(
      .networkOperationWithSession(
        of: WebauthnDelegatedCallbackNetworkOperation.self,
        requestPreparation: WebauthnDelegatedCallbackNetworkOperation.requestPreparation(_:),
        responseDecoding: WebauthnDelegatedCallbackNetworkOperation.responseDecoder(_:_:)
      )
    )
  }
}

private struct RequestBody: Encodable {

  fileprivate var exchangeCode: String
  fileprivate var remember: Bool

  private enum CodingKeys: String, CodingKey {
    case exchangeCode = "exchange_code"
    case remember = "remember"
  }
}
