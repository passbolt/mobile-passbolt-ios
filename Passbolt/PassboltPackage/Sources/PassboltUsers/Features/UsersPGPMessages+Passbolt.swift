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
import Session
import Users

extension UsersPGPMessages {

  public static func load(
    features: FeatureFactory,
    cancellables: Cancellables
  ) async throws -> Self {
    let sessionCryptography: SessionCryptography = try await features.instance()
    let usersPublicKeysFetchDatabaseOperation: UsersPublicKeysFetchDatabaseOperation = try await features.instance()
    let resourceUsersIDFetchDatabaseOperation: ResourceUsersIDFetchDatabaseOperation = try await features.instance()

    @Sendable nonisolated func encryptMessageForUsers(
      _ users: OrderedSet<User.ID>,
      message: String
    ) async throws -> OrderedSet<EncryptedMessage> {
      guard !users.isEmpty
      else { throw UsersListEmpty.error() }

      let usersKeys: OrderedSet<UserPublicKeyDSV> = try await .init(usersPublicKeysFetchDatabaseOperation(Array(users)))

      guard users.count == usersKeys.count
      else {
        throw
          UserPublicKeyMissing
          .error()
          .recording(users, for: "expected")
          .recording(usersKeys.map(\.userID), for: "received")
      }

      return try await withThrowingTaskGroup(
        of: EncryptedMessage.self,
        returning: OrderedSet<EncryptedMessage>.self
      ) { (group: inout ThrowingTaskGroup<EncryptedMessage, Error>) in
        for userKey: UserPublicKeyDSV in usersKeys {
          group.addTask {
            return try await EncryptedMessage(
              recipient: userKey.userID,
              message:
                sessionCryptography
                .encryptAndSignMessage(message, userKey.publicKey)
            )
          }
        }

        var encryptedMessages: OrderedSet<EncryptedMessage> = .init()
        encryptedMessages.reserveCapacity(usersKeys.count)

        for try await encryptedMessage: EncryptedMessage in group {
          encryptedMessages.append(encryptedMessage)
        }

        return encryptedMessages
      }
    }

    @Sendable nonisolated func encryptMessageForResourceUsers(
      _ resourceID: Resource.ID,
      message: String
    ) async throws -> OrderedSet<EncryptedMessage> {
      let resourceUsers: OrderedSet<User.ID> =
        try await .init(resourceUsersIDFetchDatabaseOperation(resourceID))
      return try await encryptMessageForUsers(
        resourceUsers,
        message: message
      )
    }

    return Self(
      encryptMessageForUsers: encryptMessageForUsers(_:message:),
      encryptMessageForResourceUsers: encryptMessageForResourceUsers(_:message:)
    )
  }
}

extension FeatureFactory {

  @MainActor internal func usePassboltUserPGPMessages() {
    self.use(
      .lazyLoaded(
        UsersPGPMessages.self,
        load: UsersPGPMessages.load(features:cancellables:)
      )
    )
  }
}