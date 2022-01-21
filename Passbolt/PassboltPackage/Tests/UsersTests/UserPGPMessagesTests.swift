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

import CommonDataModels
import Commons
import Crypto
import Features
import NetworkClient
import TestExtensions

@testable import Accounts
@testable import Users

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class UserPGPMessagesTests: TestCase {

  var accountSession: AccountSession!
  var database: AccountDatabase!
  var networkClient: NetworkClient!

  override func setUp() {
    super.setUp()
    accountSession = .placeholder
    database = .placeholder
    networkClient = .placeholder
  }

  override func tearDown() {
    accountSession = nil
    database = nil
    networkClient = nil
    super.tearDown()
  }

  func test_encryptMessageForUser_fails_whenUserProfileRequestFails() {
    features.use(accountSession)
    features.use(database)
    networkClient.userProfileRequest.execute = always(
      Fail(error: .testError())
        .eraseToAnyPublisher()
    )
    features.use(networkClient)

    let feature: UserPGPMessages = testInstance()

    var result: TheErrorLegacy?
    feature
      .encryptMessageForUser("user-id", "message")
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in }
      )
      .store(in: cancellables)

    XCTAssertEqual(result?.identifier, .testError)
  }

  func test_encryptMessageForUser_fails_whenPublicKeyVerificationFails() {
    features.environment.pgp.verifyPublicKeyFingerprint = always(.failure(.testError()))
    accountSession.statePublisher = always(
      Just(
        .authorized(
          .init(
            localID: "local-id",
            domain: "https://passbolt.com",
            userID: "user-id",
            fingerprint: "fingerpring"
          )
        )
      )
      .eraseToAnyPublisher()
    )
    features.use(accountSession)
    features.use(database)
    networkClient.userProfileRequest.execute = always(
      Just(
        .init(
          header: .mock(),
          body: .init(
            id: "user-id",
            profile: .init(
              firstName: "firstName",
              lastName: "lastName",
              avatar: .init(
                url: .init(
                  medium: "avatar-url"
                )
              )
            ),
            gpgKey: .init(
              armoredKey: "armored-public-key"
            )
          )
        )
      )
      .setFailureType(to: TheErrorLegacy.self)
      .eraseToAnyPublisher()
    )
    features.use(networkClient)

    let feature: UserPGPMessages = testInstance()

    var result: TheErrorLegacy?
    feature
      .encryptMessageForUser("user-id", "message")
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in }
      )
      .store(in: cancellables)

    XCTAssertEqual(result?.identifier, .invalidUserPublicKey)
  }

  func test_encryptMessageForUser_fails_whenEncryptAndSignMessageFails() {
    features.environment.pgp.verifyPublicKeyFingerprint = always(.success(true))
    accountSession.statePublisher = always(
      Just(
        .authorized(
          .init(
            localID: "local-id",
            domain: "https://passbolt.com",
            userID: "user.id",
            fingerprint: "fingerpring"
          )
        )
      )
      .eraseToAnyPublisher()
    )
    accountSession.encryptAndSignMessage = always(
      Fail(error: .testError())
        .eraseToAnyPublisher()
    )
    features.use(accountSession)
    features.use(database)
    networkClient.userProfileRequest.execute = always(
      Just(
        .init(
          header: .mock(),
          body: .init(
            id: "user-id",
            profile: .init(
              firstName: "firstName",
              lastName: "lastName",
              avatar: .init(
                url: .init(
                  medium: "avatar-url"
                )
              )
            ),
            gpgKey: .init(
              armoredKey: "armored-public-key"
            )
          )
        )
      )
      .setFailureType(to: TheErrorLegacy.self)
      .eraseToAnyPublisher()
    )
    features.use(networkClient)

    let feature: UserPGPMessages = testInstance()

    var result: TheErrorLegacy?
    feature
      .encryptMessageForUser("user-id", "message")
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in }
      )
      .store(in: cancellables)

    XCTAssertEqual(result?.identifier, .testError)
  }

  func test_encryptMessageForUser_succeeds_whenAllOperationsSucceed() {
    features.environment.pgp.verifyPublicKeyFingerprint = always(.success(true))
    accountSession.statePublisher = always(
      Just(
        .authorized(
          .init(
            localID: "local-id",
            domain: "https://passbolt.com",
            userID: "user.id",
            fingerprint: "fingerpring"
          )
        )
      )
      .eraseToAnyPublisher()
    )
    accountSession.encryptAndSignMessage = always(
      Just("encrypted-armored-message")
        .setFailureType(to: TheErrorLegacy.self)
        .eraseToAnyPublisher()
    )
    features.use(accountSession)
    features.use(database)
    networkClient.userProfileRequest.execute = always(
      Just(
        .init(
          header: .mock(),
          body: .init(
            id: "user-id",
            profile: .init(
              firstName: "firstName",
              lastName: "lastName",
              avatar: .init(
                url: .init(
                  medium: "avatar-url"
                )
              )
            ),
            gpgKey: .init(
              armoredKey: "armored-public-key"
            )
          )
        )
      )
      .setFailureType(to: TheErrorLegacy.self)
      .eraseToAnyPublisher()
    )
    features.use(networkClient)

    let feature: UserPGPMessages = testInstance()

    var result: ArmoredPGPMessage?
    feature
      .encryptMessageForUser("user-id", "message")
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { encrypted in
          result = encrypted
        }
      )
      .store(in: cancellables)

    XCTAssertEqual(result?.rawValue, "encrypted-armored-message")
  }

  func test_encryptMessageForResourceUsers_fails_whenUserListRequestFails() {
    features.use(accountSession)
    features.use(database)
    networkClient.userListRequest.execute = always(
      Fail(error: .testError())
        .eraseToAnyPublisher()
    )
    features.use(networkClient)

    let feature: UserPGPMessages = testInstance()

    var result: TheErrorLegacy?
    feature
      .encryptMessageForResourceUsers("resource-id", "message")
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in }
      )
      .store(in: cancellables)

    XCTAssertEqual(result?.identifier, .testError)
  }

  func test_encryptMessageForResourceUsers_fails_whenPublicKeyVerificationFails() {
    features.environment.pgp.verifyPublicKeyFingerprint = always(.failure(.testError()))
    accountSession.statePublisher = always(
      Just(
        .authorized(
          .init(
            localID: "local-id",
            domain: "https://passbolt.com",
            userID: "user-id",
            fingerprint: "fingerpring"
          )
        )
      )
      .eraseToAnyPublisher()
    )
    accountSession.encryptAndSignMessage = always(
      Fail(error: .testError())
        .eraseToAnyPublisher()
    )
    features.use(accountSession)
    features.use(database)
    networkClient.userListRequest.execute = always(
      Just(
        .init(
          header: .mock(),
          body: [
            .init(
              id: "user-id",
              profile: .init(
                firstName: "firstName",
                lastName: "lastName",
                avatar: .init(
                  url: .init(
                    medium: "avatar-url"
                  )
                )
              ),
              gpgKey: .init(
                armoredKey: "armored-public-key"
              )
            )
          ]
        )
      )
      .setFailureType(to: TheErrorLegacy.self)
      .eraseToAnyPublisher()
    )
    features.use(networkClient)

    let feature: UserPGPMessages = testInstance()

    var result: TheErrorLegacy?
    feature
      .encryptMessageForResourceUsers("resource-id", "message")
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in }
      )
      .store(in: cancellables)

    XCTAssertEqual(result?.identifier, .invalidUserPublicKey)
  }

  func test_encryptMessageForResourceUsers_fails_whenEncryptAndSignMessageFails() {
    features.environment.pgp.verifyPublicKeyFingerprint = always(.success(true))
    accountSession.statePublisher = always(
      Just(
        .authorized(
          .init(
            localID: "local-id",
            domain: "https://passbolt.com",
            userID: "user-id",
            fingerprint: "fingerpring"
          )
        )
      )
      .eraseToAnyPublisher()
    )
    accountSession.encryptAndSignMessage = always(
      Fail(error: .testError())
        .eraseToAnyPublisher()
    )
    features.use(accountSession)
    features.use(database)
    networkClient.userListRequest.execute = always(
      Just(
        .init(
          header: .mock(),
          body: [
            .init(
              id: "user-id",
              profile: .init(
                firstName: "firstName",
                lastName: "lastName",
                avatar: .init(
                  url: .init(
                    medium: "avatar-url"
                  )
                )
              ),
              gpgKey: .init(
                armoredKey: "armored-public-key"
              )
            )
          ]
        )
      )
      .setFailureType(to: TheErrorLegacy.self)
      .eraseToAnyPublisher()
    )
    features.use(networkClient)

    let feature: UserPGPMessages = testInstance()

    var result: TheErrorLegacy?
    feature
      .encryptMessageForResourceUsers("resource-id", "message")
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in }
      )
      .store(in: cancellables)

    XCTAssertEqual(result?.identifier, .testError)
  }

  func test_encryptMessageForResourceUsers_succeeds_whenAllOperationsSucceed() {
    features.environment.pgp.verifyPublicKeyFingerprint = always(.success(true))
    accountSession.statePublisher = always(
      Just(
        .authorized(
          .init(
            localID: "local-id",
            domain: "https://passbolt.com",
            userID: "user.id",
            fingerprint: "fingerpring"
          )
        )
      )
      .eraseToAnyPublisher()
    )
    accountSession.encryptAndSignMessage = always(
      Just("encrypted-armored-message")
        .setFailureType(to: TheErrorLegacy.self)
        .eraseToAnyPublisher()
    )
    features.use(accountSession)
    features.use(database)
    networkClient.userListRequest.execute = always(
      Just(
        .init(
          header: .mock(),
          body: [
            .init(
              id: "user-id",
              profile: .init(
                firstName: "firstName",
                lastName: "lastName",
                avatar: .init(
                  url: .init(
                    medium: "avatar-url"
                  )
                )
              ),
              gpgKey: .init(
                armoredKey: "armored-public-key"
              )
            ),
            .init(
              id: "another-user-id",
              profile: .init(
                firstName: "firstName",
                lastName: "lastName",
                avatar: .init(
                  url: .init(
                    medium: "avatar-url"
                  )
                )
              ),
              gpgKey: .init(
                armoredKey: "armored-public-key"
              )
            ),
          ]
        )
      )
      .setFailureType(to: TheErrorLegacy.self)
      .eraseToAnyPublisher()
    )
    features.use(networkClient)

    let feature: UserPGPMessages = testInstance()

    var result: Array<(User.ID, ArmoredPGPMessage)>?
    feature
      .encryptMessageForResourceUsers("resource-id", "message")
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { encrypted in
          result = encrypted
        }
      )
      .store(in: cancellables)

    XCTAssertTrue(result?.contains(where: { $0 == "user-id" && $1 == "encrypted-armored-message" }) ?? false)
    XCTAssertTrue(result?.contains(where: { $0 == "another-user-id" && $1 == "encrypted-armored-message" }) ?? false)
  }
}
