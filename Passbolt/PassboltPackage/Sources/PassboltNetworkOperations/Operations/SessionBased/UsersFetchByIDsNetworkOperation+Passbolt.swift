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

extension UsersFetchByIDsNetworkOperation {

  @Sendable fileprivate static func requestPreparation(
    _ input: Input
  ) -> Mutation<HTTPRequest> {
    // One repeated `filter[has-id][]` query item per requested id.
    let idsFilter: Mutation<HTTPRequest> = input.usersIDs.reduce(into: Mutation<HTTPRequest>.none) {
      partialResult,
      userID in
      partialResult = .combined(
        partialResult,
        .queryItem("filter[has-id][]", value: userID.rawValue.rawValue.uuidString)
      )
    }
    return .combined(
      .pathSuffix("/users.json"),
      // Same response shape as the full users fetch - the profile it carries is what a snapshot entry needs.
      .queryItem("api-version", value: "v2"),
      idsFilter,
      .method(.get)
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

  internal mutating func usePassboltUsersFetchByIDsNetworkOperation() {
    self.use(
      .networkOperationWithSession(
        of: UsersFetchByIDsNetworkOperation.self,
        requestPreparation: UsersFetchByIDsNetworkOperation.requestPreparation(_:),
        responseDecoding: UsersFetchByIDsNetworkOperation.responseDecoder(_:_:)
      )
    )
  }
}
