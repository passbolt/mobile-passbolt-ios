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

extension AppVersionsFetchNetworkOperation {

  @MainActor fileprivate static func load(
    features: FeatureFactory
  ) async throws -> Self {
    unowned let features: FeatureFactory = features

    let requestExecutor: NetworkRequestExecutor = try await features.instance()

    @Sendable nonisolated func prepareRequest(
      _ input: Input
    ) -> HTTPRequest {
      Mutation<HTTPRequest>
        .combined(
          .url(string: "https://itunes.apple.com/lookup"),
          .method(.get),
          .queryItem("bundleId", value: "com.passbolt.mobile"),
          .queryItem("limit", value: "1")
        )
        .instantiate()
    }

    let responseDecoder: NetworkResponseDecoder<Input, Output> = .bodyAsJSON()
    @Sendable nonisolated func decodeResponse(
      _ input: Input,
      _ response: HTTPResponse
    ) throws -> Output {
      try responseDecoder
        .decode(
          input,
          response
        )
    }

    @Sendable nonisolated func execute(
      _ input: Input
    ) async throws -> Output {
      try await decodeResponse(
        input,
        requestExecutor
          .execute(prepareRequest(input))
      )
    }

    return Self(
      execute: execute(_:)
    )
  }
}

extension FeatureFactory {

  internal func usePassboltAppVersionsFetchNetworkOperation() {
    self.use(
      .disposable(
        AppVersionsFetchNetworkOperation.self,
        load: AppVersionsFetchNetworkOperation.load(features:)
      )
    )
  }
}
