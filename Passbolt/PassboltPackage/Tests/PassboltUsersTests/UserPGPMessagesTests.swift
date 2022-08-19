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
import Features
import NetworkOperations
import TestExtensions

@testable import PassboltUsers

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class UsersPGPMessagesTests: LoadableFeatureTestCase<UsersPGPMessages> {

  override class var testedImplementationRegister: (FeatureFactory) -> @MainActor () -> Void {
    FeatureFactory.usePassboltUserPGPMessages
  }

  override func prepare() throws {
    use(Session.placeholder)
    use(SessionCryptography.placeholder)
    use(UsersPublicKeysFetchDatabaseOperation.placeholder)
    use(ResourceUsersIDFetchDatabaseOperation.placeholder)
  }

  func test_encryptMessageForUser_fails_whenUserListIsEmpty() async throws {
    patch(
      \ResourceUsersIDFetchDatabaseOperation.execute,
      with: always([])
    )

    let feature: UsersPGPMessages = try await self.testedInstance()

    await XCTAssertError(
      matches: UsersListEmpty.self
    ) {
      try await feature
        .encryptMessageForUsers([], "message")
    }
  }

  func test_encryptMessageForUser_fails_whenUserPublicKeysFetchFails() async throws {
    patch(
      \ResourceUsersIDFetchDatabaseOperation.execute,
      with: always([.random()])
    )
    patch(
      \UsersPublicKeysFetchDatabaseOperation.execute,
      with: alwaysThrow(MockIssue.error())
    )

    let feature: UsersPGPMessages = try await self.testedInstance()

    await XCTAssertError(
      matches: MockIssue.self
    ) {
      try await feature
        .encryptMessageForUsers([.random()], "message")
    }
  }

  func test_encryptMessageForUser_fails_whenUserPublicKeysFetchDoesNotContainAllUsers() async throws {
    patch(
      \ResourceUsersIDFetchDatabaseOperation.execute,
      with: always([.random()])
    )
    patch(
      \UsersPublicKeysFetchDatabaseOperation.execute,
      with: always([])
    )

    let feature: UsersPGPMessages = try await self.testedInstance()

    await XCTAssertError(
      matches: UserPublicKeyMissing.self
    ) {
      try await feature
        .encryptMessageForUsers([.random()], "message")
    }
  }

  func test_encryptMessageForUser_fails_whenEncryptAndSignMessageFails() async throws {
    let userID: User.ID = .random()
    patch(
      \ResourceUsersIDFetchDatabaseOperation.execute,
      with: always([userID])
    )
    patch(
      \UsersPublicKeysFetchDatabaseOperation.execute,
      with: always([.init(userID: userID, publicKey: "KEY")])
    )
    patch(
      \SessionCryptography.encryptAndSignMessage,
      with: alwaysThrow(
        MockIssue.error()
      )
    )

    let feature: UsersPGPMessages = try await self.testedInstance()

    await XCTAssertError(
      matches: MockIssue.self
    ) {
      try await feature
        .encryptMessageForUsers([.random()], "message")
    }
  }

  func test_encryptMessageForUser_succeeds_whenAllOperationsSucceed() async throws {
    let userID: User.ID = .random()
    patch(
      \ResourceUsersIDFetchDatabaseOperation.execute,
      with: always([userID])
    )
    patch(
      \UsersPublicKeysFetchDatabaseOperation.execute,
      with: always([.init(userID: userID, publicKey: "KEY")])
    )
    patch(
      \SessionCryptography.encryptAndSignMessage,
      with: always(
        "encrypted-message"
      )
    )

    let feature: UsersPGPMessages = try await self.testedInstance()

    await XCTAssertValue(
      equal: [
        .init(
          recipient: userID,
          message: "encrypted-message"
        )
      ]
    ) {
      try await feature
        .encryptMessageForUsers([userID], "message")
    }
  }

  func test_encryptMessageForResourceUsers_fails_whenResourceUsersFetchFails() async throws {
    patch(
      \ResourceUsersIDFetchDatabaseOperation.execute,
      with: alwaysThrow(MockIssue.error())
    )

    let feature: UsersPGPMessages = try await self.testedInstance()

    await XCTAssertError(
      matches: MockIssue.self
    ) {
      try await feature
        .encryptMessageForResourceUsers(.random(), "message")
    }
  }

  func test_encryptMessageForResourceUsers_fails_whenUserKeysFetchFails() async throws {
    patch(
      \ResourceUsersIDFetchDatabaseOperation.execute,
      with: always([.random()])
    )
    patch(
      \UsersPublicKeysFetchDatabaseOperation.execute,
      with: alwaysThrow(MockIssue.error())
    )

    let feature: UsersPGPMessages = try await self.testedInstance()

    await XCTAssertError(
      matches: MockIssue.self
    ) {
      try await feature
        .encryptMessageForResourceUsers(.random(), "message")
    }
  }

  func test_encryptMessageForResourceUsers_fails_whenEncryptAndSignMessageFails() async throws {
    let userID: User.ID = .random()
    patch(
      \ResourceUsersIDFetchDatabaseOperation.execute,
      with: always([userID])
    )
    patch(
      \UsersPublicKeysFetchDatabaseOperation.execute,
      with: always([.init(userID: userID, publicKey: "KEY")])
    )
    patch(
      \SessionCryptography.encryptAndSignMessage,
      with: alwaysThrow(
        MockIssue.error()
      )
    )

    let feature: UsersPGPMessages = try await self.testedInstance()

    await XCTAssertError(
      matches: MockIssue.self
    ) {
      try await feature
        .encryptMessageForResourceUsers(.random(), "message")
    }
  }

  func test_encryptMessageForResourceUsers_succeeds_whenAllOperationsSucceed() async throws {
    let userID: User.ID = .random()
    patch(
      \ResourceUsersIDFetchDatabaseOperation.execute,
      with: always([userID])
    )
    patch(
      \UsersPublicKeysFetchDatabaseOperation.execute,
      with: always([.init(userID: userID, publicKey: "KEY")])
    )
    patch(
      \SessionCryptography.encryptAndSignMessage,
      with: always(
        "encrypted-message"
      )
    )

    let feature: UsersPGPMessages = try await self.testedInstance()

    await XCTAssertValue(
      equal: [
        .init(
          recipient: userID,
          message: "encrypted-message"
        )
      ]
    ) {
      try await feature
        .encryptMessageForResourceUsers(.random(), "message")
    }
  }
}
