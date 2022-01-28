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

public struct UserPGPMessages {

  // Encrypt PGP message for given user by fetching that user public key from the server.
  // Automatically verifies public key for current user based on the local storage.
  public var encryptMessageForUser: (User.ID, String) -> AnyPublisher<ArmoredPGPMessage, TheErrorLegacy>
  // Encrypt PGP message for each user with permission to the resource with given id
  // by fetching users public keys associated with resource from the server.
  // Automatically verifies public key for current user based on the local storage.
  public var encryptMessageForResourceUsers:
    (Resource.ID, String) -> AnyPublisher<Array<(User.ID, ArmoredPGPMessage)>, TheErrorLegacy>
}

extension UserPGPMessages: Feature {

  public static func load(
    in environment: Environment,
    using features: FeatureFactory,
    cancellables: Cancellables
  ) -> Self {
    let pgp: PGP = environment.pgp
    let accountSession: AccountSession = features.instance()
    let networkClient: NetworkClient = features.instance()

    func verifiedPublicKey(
      _ userID: User.ID,
      publicKey: ArmoredPGPPublicKey
    ) -> AnyPublisher<ArmoredPGPPublicKey, TheErrorLegacy> {
      #warning("Currently we can verify only own public key, we might add other users keys verification in the future.")
      return
        accountSession
        .statePublisher()
        .first()
        .map { accountSessionState -> AnyPublisher<ArmoredPGPPublicKey, TheErrorLegacy> in
          switch accountSessionState {
          case let .authorized(account), let .authorizedMFARequired(account, _), let .authorizationRequired(account):
            if account.userID.rawValue == userID.rawValue {
              if (try? pgp.verifyPublicKeyFingerprint(publicKey, account.fingerprint).get()) ?? false {
                return Just(publicKey)
                  .setFailureType(to: TheErrorLegacy.self)
                  .eraseToAnyPublisher()
              }
              else {
                return Fail(error: .invalidUserPublicKey())
                  .eraseToAnyPublisher()
              }
            }
            else {
              return Just(publicKey)
                .setFailureType(to: TheErrorLegacy.self)
                .eraseToAnyPublisher()
            }

          case .none:
            return Fail(
              error:
                SessionMissing
                .error("No session provided for verifying public key")
                .asLegacy
            )
            .eraseToAnyPublisher()
          }
        }
        .switchToLatest()
        .eraseToAnyPublisher()
    }

    func encryptMessageForUser(
      _ userID: User.ID,
      message: String
    ) -> AnyPublisher<ArmoredPGPMessage, TheErrorLegacy> {
      networkClient
        .userProfileRequest
        .make(using: .init(userID: userID.rawValue))
        .map(\.body)
        .mapErrorsToLegacy()
        .map { user -> AnyPublisher<ArmoredPGPMessage, TheErrorLegacy> in
          verifiedPublicKey(user.id, publicKey: user.gpgKey.armoredKey)
            .map { armoredPublicKey -> AnyPublisher<ArmoredPGPMessage, TheErrorLegacy> in
              accountSession
                .encryptAndSignMessage(message, armoredPublicKey)
            }
            .switchToLatest()
            .eraseToAnyPublisher()
        }
        .switchToLatest()
        .eraseToAnyPublisher()
    }

    func encryptMessageForResourceUsers(
      _ resourceID: Resource.ID,
      message: String
    ) -> AnyPublisher<Array<(User.ID, ArmoredPGPMessage)>, TheErrorLegacy> {
      networkClient
        .userListRequest
        .make(using: .init(resourceIDFilter: resourceID.rawValue))
        .map(\.body)
        .mapErrorsToLegacy()
        .map { users -> AnyPublisher<Array<(User.ID, ArmoredPGPMessage)>, TheErrorLegacy> in
          Publishers.MergeMany(
            users
              .map { user -> AnyPublisher<(User.ID, ArmoredPGPMessage), TheErrorLegacy> in
                verifiedPublicKey(user.id, publicKey: user.gpgKey.armoredKey)
                  .map { armoredPublicKey -> AnyPublisher<ArmoredPGPMessage, TheErrorLegacy> in
                    accountSession
                      .encryptAndSignMessage(message, armoredPublicKey)
                  }
                  .switchToLatest()
                  .map { encryptedMessage in
                    (user.id, encryptedMessage)
                  }
                  .eraseToAnyPublisher()
              }
          )
          .collect()
          .eraseToAnyPublisher()
        }
        .switchToLatest()
        .eraseToAnyPublisher()
    }

    return Self(
      encryptMessageForUser: encryptMessageForUser(_:message:),
      encryptMessageForResourceUsers: encryptMessageForResourceUsers(_:message:)
    )
  }
}

#if DEBUG

extension UserPGPMessages {

  public static var placeholder: Self {
    Self(
      encryptMessageForUser: unimplemented("You have to provide mocks for used methods"),
      encryptMessageForResourceUsers: unimplemented("You have to provide mocks for used methods")
    )
  }
}
#endif
