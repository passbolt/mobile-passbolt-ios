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

extension FeatureLoader {

  internal static func networkOperation<Description>(
    of: NetworkOperation<Description>.Type,
    requestPreparation: @escaping @Sendable (Description.Input) -> Mutation<HTTPRequest>,
    responseDecoding: @escaping @Sendable (Description.Input, HTTPResponse) throws -> Description.Output
  ) -> Self
  where Description: NetworkOperationDescription {
    .disposable(
      NetworkOperation<Description>.self,
      load: { (features: Features) -> NetworkOperation<Description> in

        let requestExecutor: NetworkRequestExecutor = try features.instance()

        @Sendable nonisolated func execute(
          _ input: Description.Input
        ) async throws -> Description.Output {
          try await responseDecoding(
            input,
            requestExecutor
              .execute(
                requestPreparation(input)
                  .instantiate()
              )
          )
        }

        return .init(
          execute: execute(_:)
        )
      }
    )
  }

  internal static func networkOperationWithSession<Description>(
    of: NetworkOperation<Description>.Type,
    requestPreparation: @escaping @Sendable (Description.Input) -> Mutation<HTTPRequest>,
    responseDecoding: @escaping @Sendable (Description.Input, HTTPResponse) throws -> Description.Output
  ) -> Self
  where Description: NetworkOperationDescription {
    .disposable(
      NetworkOperation<Description>.self,
      load: { (features: Features) -> NetworkOperation<Description> in

        let sessionRequestExecutor: SessionNetworkRequestExecutor = try features.instance()

        @Sendable nonisolated func execute(
          _ input: Description.Input
        ) async throws -> Description.Output {
          try await responseDecoding(
            input,
            sessionRequestExecutor
              .execute(requestPreparation(input))
          )
        }

        return .init(
          execute: execute(_:)
        )
      }
    )
  }
}
