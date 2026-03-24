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

// MARK: - Interface

internal typealias PwnedPasswordCheckNetworkOperation =
  NetworkOperation<PwnedPasswordCheckNetworkOperationDescription>

internal enum PwnedPasswordCheckNetworkOperationDescription: NetworkOperationDescription {

  internal typealias Input = String
  internal typealias Output = String
}

// MARK: - Implementation

extension PwnedPasswordCheckNetworkOperation {

  @Sendable fileprivate static func requestPreparation(
    _ input: Input
  ) -> Mutation<HTTPRequest> {
    .combined(
      .url(string: "https://api.pwnedpasswords.com/range/\(input)"),
      .method(.get)
    )
  }

  @Sendable fileprivate static func responseDecoder(
    _ input: Input,
    _ response: HTTPResponse
  ) throws -> Output {
    guard let body: String = .init(data: response.body, encoding: .utf8)
    else {
      throw PwnedPasswordChecker.CheckError.error()
    }
    return body
  }
}

// MARK: - Registration

extension FeaturesRegistry {

  internal mutating func usePwnedPasswordCheckNetworkOperation() {
    self.use(
      .disposable(
        PwnedPasswordCheckNetworkOperation.self,
        load: { (features: Features) -> PwnedPasswordCheckNetworkOperation in

          let requestExecutor: NetworkRequestExecutor = try features.instance()

          @Sendable nonisolated func execute(
            _ input: PwnedPasswordCheckNetworkOperationDescription.Input
          ) async throws -> PwnedPasswordCheckNetworkOperationDescription.Output {
            try await PwnedPasswordCheckNetworkOperation.responseDecoder(
              input,
              requestExecutor
                .execute(
                  PwnedPasswordCheckNetworkOperation.requestPreparation(input)
                    .instantiate()
                )
            )
          }

          return .init(
            execute: execute(_:)
          )
        }
      )
    )
  }
}
