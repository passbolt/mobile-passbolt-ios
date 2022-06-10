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

import Accounts
import CommonModels
import Crypto
import Features
import NetworkClient

public struct UsersPGPMessages {

  // Encrypt a message for each user in the list
  // by fetching users public keys from a local database.
  public var encryptMessageForUsers:
    @StorageAccessActor (
      _ recipients: Array<User.ID>,
      _ message: String
    ) async throws -> Array<EncryptedMessage>

  // Encrypt a message for each user with permission
  // to the requested resource by fetching users public keys
  // and resource permissions from a local database.
  public var encryptMessageForResourceUsers:
    @StorageAccessActor (
      _ resourceID: Resource.ID,
      _ message: String
    ) async throws -> Array<EncryptedMessage>
}

extension UsersPGPMessages: LegacyFeature {

  public static func load(
    in environment: AppEnvironment,
    using features: FeatureFactory,
    cancellables: Cancellables
  ) async throws -> Self {
    let accountSession: AccountSession = try await features.instance()
    let usersPublicKeysDatabaseFetch: UsersPublicKeysDatabaseFetch = try await features.instance()
    let resourceUsersIDDatabaseFetch: ResourceUsersIDDatabaseFetch = try await features.instance()

    @StorageAccessActor func encryptMessageForUsers(
      _ users: Array<User.ID>,
      message: String
    ) async throws -> Array<EncryptedMessage> {
      guard !users.isEmpty
      else { throw UsersListEmpty.error() }

      let usersKeys: Array<UserPublicKeyDSV> = try await usersPublicKeysDatabaseFetch(users)

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
        returning: Array<EncryptedMessage>.self
      ) { (group: inout ThrowingTaskGroup<EncryptedMessage, Error>) in
        for userKey: UserPublicKeyDSV in usersKeys {
          group.addTask {
            return try await EncryptedMessage(
              recipient: userKey.userID,
              message:
                accountSession
                .encryptAndSignMessage(message, userKey.publicKey)
            )
          }
        }

        var encryptedMessages: Array<EncryptedMessage> = .init()
        encryptedMessages.reserveCapacity(usersKeys.count)

        for try await encryptedMessage: EncryptedMessage in group {
          encryptedMessages.append(encryptedMessage)
        }

        return encryptedMessages
      }
    }

    @StorageAccessActor func encryptMessageForResourceUsers(
      _ resourceID: Resource.ID,
      message: String
    ) async throws -> Array<EncryptedMessage> {
      let resourceUsers: Array<User.ID> =
        try await resourceUsersIDDatabaseFetch(resourceID)
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

extension UsersPGPMessages {

  public var featureUnload: @FeaturesActor () async throws -> Void { {} }
}

#if DEBUG

extension UsersPGPMessages {

  public static var placeholder: Self {
    Self(
      encryptMessageForUsers: unimplemented("You have to provide mocks for used methods"),
      encryptMessageForResourceUsers: unimplemented("You have to provide mocks for used methods")
    )
  }
}
#endif
