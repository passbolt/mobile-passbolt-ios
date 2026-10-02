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

@testable import PassboltNetworkOperations

// swift-format-ignore: AlwaysUseLowerCamelCase
final class WebauthnDelegatedCallbackNetworkOperationRequestEncodingTests: FeaturesTestCase {

  override func commonPrepare() async throws {
    try await super.commonPrepare()
    register(
      { $0.usePassboltWebauthnDelegatedCallbackNetworkOperation() },
      for: WebauthnDelegatedCallbackNetworkOperation.self
    )
    patch(
      \SessionNetworkRequestExecutor.execute,
      with: { (mutation: Mutation<HTTPRequest>) in
        let request: HTTPRequest = mutation.instantiate()
        // decoding with the server key names pins the request body to the server contract
        let body: ExpectedRequestBody = try JSONDecoder.default
          .decode(ExpectedRequestBody.self, from: request.body)
        self.mockExecuted(with: body)
        return HTTPResponse(
          url: request.urlComponents.url ?? URL(fileURLWithPath: "/"),
          statusCode: 200,
          headers: ["Set-Cookie": "passbolt_mfa=mfa-token; path=/"],
          body: .empty
        )
      }
    )
  }

  func test_execute_sendsDelegatedTokenSecretAndRemember_withServerKeys() async {
    await withInstance(
      of: WebauthnDelegatedCallbackNetworkOperation.self,
      mockExecutedWith: ExpectedRequestBody(
        delegatedToken: "delegated-token",
        delegatedSecret: "delegated-secret",
        remember: true
      )
    ) { (operation: WebauthnDelegatedCallbackNetworkOperation) in
      _ = try await operation.execute(
        .init(
          delegatedToken: "delegated-token",
          delegatedSecret: "delegated-secret",
          remember: true
        )
      )
    }
  }
}

private struct ExpectedRequestBody: Decodable, Equatable {

  fileprivate var delegatedToken: String
  fileprivate var delegatedSecret: String
  fileprivate var remember: Bool

  private enum CodingKeys: String, CodingKey {
    case delegatedToken = "mfa_delegated_token"
    case delegatedSecret = "mfa_delegated_secret"
    case remember = "remember"
  }
}
