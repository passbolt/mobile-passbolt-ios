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

extension AccountTransferUpdateNetworkOperation {

  @Sendable fileprivate static func requestPreparation(
    _ input: Input
  ) -> Mutation<HTTPRequest> {
    .combined(
      .url(string: input.domain.rawValue),
			.pathSuffix("/mobile/transfers/\(input.transferID)/\(input.authenticationToken).json"),
      .method(.post),
      .when(
        input.requestUserProfile,
        then: .queryItem("contain[user.profile]", value: "1")
      ),
      .jsonBody(
        from: RequestBody(
          currentPage: input.currentPage,
          status: input.status
        )
      )
    )
  }

  @Sendable fileprivate static func responseDecoder(
    _ input: Input,
    _ response: HTTPResponse
  ) throws -> Output {
    try NetworkResponseDecoder<Input, CommonNetworkResponse<Output>>
      .bodyAsJSON()
      .decode(
        input,
        response
      )
      .body
  }
}

extension FeaturesRegistry {

  internal mutating func usePassboltAccountTransferUpdateNetworkOperation() {
    self.use(
      FeatureLoader.networkOperation(
        of: AccountTransferUpdateNetworkOperation.self,
        requestPreparation: AccountTransferUpdateNetworkOperation.requestPreparation(_:),
        responseDecoding: AccountTransferUpdateNetworkOperation.responseDecoder(_:_:)
      )
    )
  }
}

private struct RequestBody: Encodable {

  fileprivate var currentPage: Int
  fileprivate var status: AccountTransferUpdateNetworkOperationVariable.Status

  fileprivate enum CodingKeys: String, CodingKey {

    case currentPage = "current_page"
    case status = "status"
  }
}
