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
import Crypto
import Features
import NetworkClient
import TestExtensions

@testable import Accounts
@testable import Users

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class UsersPGPMessagesTests: TestCase {

  var mockAccount: Account!

  override func featuresActorSetUp() async throws {
    try await super.featuresActorSetUp()
    self.mockAccount = .validAccount
    self.features.usePlaceholder(
      for: AccountSession.self
    )
    self.features.usePlaceholder(
      for: UsersPublicKeysDatabaseFetch.self
    )
    self.features.usePlaceholder(
      for: ResourceUsersIDDatabaseFetch.self
    )
  }

  override func featuresActorTearDown() async throws {
    self.mockAccount = .none
    try await super.featuresActorTearDown()
  }

  func test_encryptMessageForUser_fails_whenUserListIsEmpty() async throws {
    let feature: UsersPGPMessages = try await self.testInstance()

    await XCTAssertError(
      matches: UsersListEmpty.self
    ) {
      try await feature
        .encryptMessageForUsers([], "message")
    }
  }

  func test_encryptMessageForUser_fails_whenUserPublicKeysFetchFails() async throws {
    await self.features.patch(
      \UsersPublicKeysDatabaseFetch.execute,
      with: alwaysThrow(
        MockIssue.error()
      )
    )

    let feature: UsersPGPMessages = try await self.testInstance()

    await XCTAssertError(
      matches: MockIssue.self
    ) {
      try await feature
        .encryptMessageForUsers([.random()], "message")
    }
  }

  func test_encryptMessageForUser_fails_whenUserPublicKeysFetchDoesNotContainAllUsers() async throws {
    await self.features.patch(
      \UsersPublicKeysDatabaseFetch.execute,
       with: always(
        []
       )
    )

    let feature: UsersPGPMessages = try await self.testInstance()

    await XCTAssertError(
      matches: UserPublicKeyMissing.self
    ) {
      try await feature
        .encryptMessageForUsers([.random()], "message")
    }
  }

  func test_encryptMessageForUser_fails_whenEncryptAndSignMessageFails() async throws {
    await self.features.patch(
      \AccountSession.currentState,
      with: always(
        .authorized(self.mockAccount)
      )
    )
    await self.features.patch(
      \AccountSession.encryptAndSignMessage,
      with: alwaysThrow(
        MockIssue.error()
      )
    )
    await self.features.patch(
      \UsersPublicKeysDatabaseFetch.execute,
      with: always(
        [.random()]
      )
    )

    let feature: UsersPGPMessages = try await self.testInstance()

    await XCTAssertError(
      matches: MockIssue.self
    ) {
      try await feature
        .encryptMessageForUsers([.random()], "message")
    }
  }

  func test_encryptMessageForUser_succeeds_whenAllOperationsSucceed() async throws {
    await self.features.patch(
      \AccountSession.currentState,
      with: always(
        .authorized(self.mockAccount)
      )
    )
    await self.features.patch(
      \AccountSession.encryptAndSignMessage,
      with: always(
        "encrypted-message"
      )
    )
    let usersKeys: Array<UserPublicKeyDSV> = [.random()]
    await self.features.patch(
      \UsersPublicKeysDatabaseFetch.execute,
      with: always(
        usersKeys
      )
    )

    let feature: UsersPGPMessages = try await self.testInstance()

    await XCTAssertValue(
      equal: usersKeys.map {
        .init(
          recipient: $0.userID,
          message: "encrypted-message"
        )
      }
    ) {
      try await feature
        .encryptMessageForUsers([.random()], "message")
    }
  }

  func test_encryptMessageForResourceUsers_fails_whenResourceUsersFetchFails() async throws {
    await self.features.patch(
      \AccountSession.currentState,
       with: always(
        .authorized(self.mockAccount)
       )
    )
    await self.features.patch(
      \ResourceUsersIDDatabaseFetch.execute,
       with: alwaysThrow(
        MockIssue.error()
       )
    )

    let feature: UsersPGPMessages = try await self.testInstance()

    await XCTAssertError(
      matches: MockIssue.self
    ) {
      try await feature
        .encryptMessageForResourceUsers(.random(), "message")
    }
  }

  func test_encryptMessageForResourceUsers_fails_whenUserListFetchFails() async throws {
    await self.features.patch(
      \AccountSession.currentState,
      with: always(
        .authorized(self.mockAccount)
      )
    )
    await self.features.patch(
      \ResourceUsersIDDatabaseFetch.execute,
      with: always(
        [.random()]
      )
    )
    await self.features.patch(
      \UsersPublicKeysDatabaseFetch.execute,
       with: alwaysThrow(
        MockIssue.error()
       )
    )

    let feature: UsersPGPMessages = try await self.testInstance()

    await XCTAssertError(
      matches: MockIssue.self
    ) {
      try await feature
        .encryptMessageForResourceUsers(.random(), "message")
    }
  }

  func test_encryptMessageForResourceUsers_fails_whenEncryptAndSignMessageFails() async throws {
    await self.features.patch(
      \AccountSession.currentState,
      with: always(
        .authorized(self.mockAccount)
      )
    )
    await self.features.patch(
      \AccountSession.encryptAndSignMessage,
      with: alwaysThrow(
        MockIssue.error()
      )
    )
    await self.features.patch(
      \ResourceUsersIDDatabaseFetch.execute,
      with: always(
        [.random()]
      )
    )
    await self.features.patch(
      \UsersPublicKeysDatabaseFetch.execute,
       with: always(
        [.random()]
       )
    )

    let feature: UsersPGPMessages = try await self.testInstance()

    await XCTAssertError(
      matches: MockIssue.self
    ) {
      try await feature
        .encryptMessageForResourceUsers(.random(), "message")
    }
  }

  func test_encryptMessageForResourceUsers_succeeds_whenAllOperationsSucceed() async throws {
    await self.features.patch(
      \AccountSession.currentState,
      with: always(
        .authorized(self.mockAccount)
      )
    )
    await self.features.patch(
      \AccountSession.encryptAndSignMessage,
      with: always(
        "encrypted-message"
      )
    )
    await self.features.patch(
      \ResourceUsersIDDatabaseFetch.execute,
      with: always(
        [.random()]
      )
    )
    let usersKeys: Array<UserPublicKeyDSV> = [.random()]
    await self.features.patch(
      \UsersPublicKeysDatabaseFetch.execute,
       with: always(
        usersKeys
       )
    )

    let feature: UsersPGPMessages = try await self.testInstance()

    await XCTAssertValue(
      equal: usersKeys.map {
        .init(
          recipient: $0.userID,
          message: "encrypted-message"
        )
      }
    ) {
      try await feature
        .encryptMessageForResourceUsers(.random(), "message")
    }
  }
}
