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

import struct Foundation.URL

public typealias AppVersionsAvailableRequest = NetworkRequest<
  EmptyNetworkSessionVariable, AppVersionsAvailableRequestVariable, AppVersionsAvailableRequestResponse
>

extension AppVersionsAvailableRequest {

  internal static func live(
    using networking: Networking,
    with sessionVariable: @AccountSessionActor @escaping () async throws -> EmptyNetworkSessionVariable
  ) -> Self {
    Self(
      template: .init { sessionVariable, requestVariable in
        .combined(
          .url(string: "https://itunes.apple.com/lookup"),
          .method(.get),
          .queryItem("bundleId", value: "com.passbolt.mobile"),
          .queryItem("limit", value: "1")
        )
      },
      responseDecoder: .bodyAsJSON(),
      using: networking,
      with: sessionVariable
    )
  }
}

public typealias AppVersionsAvailableRequestVariable = Void

public struct AppVersionsAvailableRequestResponse: Decodable {

  public var results: Array<Result>

  public init(
    results: Array<Result>
  ) {
    self.results = results
  }
}

extension AppVersionsAvailableRequestResponse {

  public struct Result: Decodable {

    public var version: String

    public init(
      version: String
    ) {
      self.version = version
    }
  }
}
