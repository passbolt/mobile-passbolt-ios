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

import DatabaseOperations
import FeatureScopes
import NetworkOperations
import Users

import class Foundation.JSONDecoder

extension ResourceUpdatePreparation {
  @MainActor fileprivate static func load(
    using features: Features
  ) throws -> Self {
    let usersPGPMessages: UsersPGPMessages = try features.instance()
    let resourceSecretFetchNetworkOperation: ResourceSecretFetchNetworkOperation = try features.instance()
    let sessionCryptography: SessionCryptography = try features.instance()

    @Sendable func encryptSecrets(
      for userIDs: OrderedSet<User.ID>,
      resourceSecret: String
    ) async throws -> OrderedSet<EncryptedMessage> {
      let encryptedSecrets: OrderedSet<EncryptedMessage> =
        try await usersPGPMessages
        .encryptMessageForUsers(userIDs, resourceSecret)

      guard encryptedSecrets.count == userIDs.count
      else {
        throw
          InvalidResourceSecret
          .error(message: "Failed to encrypt secret for all required users!")
      }
      return encryptedSecrets
    }

    @Sendable nonisolated func fetchSecretJSON(
      resourceID: Resource.ID,
      unstructured: Bool
    ) async throws -> JSON {
      let encryptedSecret: ArmoredPGPMessage =
        try await ArmoredPGPMessage(
          rawValue: resourceSecretFetchNetworkOperation(
            .init(
              resourceID: resourceID
            )
          )
          .data
        )

      let decryptedSecret: String =
        try await sessionCryptography
        // Skipping public key for signature verification.
        .decryptMessage(encryptedSecret, nil)

      // unstructured resource secret is just encrypted content
      // it is either for legacy password or unknown resource types
      if unstructured {
        return .string(decryptedSecret)
      }
      else {
        return try JSONDecoder.default
          .decode(
            JSON.self,
            from:
              decryptedSecret
              .data(using: .utf8)
              ?? .init()
          )
      }
    }

    return .init(
      prepareSecret: encryptSecrets,
      fetchSecret: fetchSecretJSON
    )
  }
}

extension FeaturesRegistry {

  internal mutating func usePassboltResourceUpdatePreparation() {
    self.use(
      .disposable(
        ResourceUpdatePreparation.self,
        load: ResourceUpdatePreparation.load(using:)
      ),
      in: SessionScope.self
    )
  }
}
