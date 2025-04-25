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

import TestExtensions

@testable import PassboltResources

// swift-format-ignore: AlwaysUseLowerCamelCase
final class ResourceUpdatePreparationTests: FeaturesTestCase {

  override func commonPrepare() {
    super.commonPrepare()
    register(
      { $0.usePassboltResourceUpdatePreparation() },
      for: ResourceUpdatePreparation.self
    )
    set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_default
      )
    )

    patch(
      \SessionCryptography.decryptMessage,
      with: { message, _ in .init(message) }  // pass-through
    )
  }

  func test_givenResourceIdAndSecret_whenPreparingUpdate_shouldReturnEncryptedSecretsForAllUsers() async throws {
    patch(
      \UsersPGPMessages.encryptMessageForResourceUsers,
      with: always([.mock_1, .mock_2])
    )
    patch(
      \ResourceUsersIDFetchDatabaseOperation.execute,
      with: always([.mock_1, .mock_2])
    )
    let sut: ResourceUpdatePreparation = try self.testedInstance()

    await verifyIf(
      try await sut.prepareSecret(.mock_1, "secret").map { $0.recipient },
      isEqual: [.mock_1, .mock_2],
      "Should encrypt secret for all users"
    )
  }

  func test_givenResourceIdAndSecret_whenPreparingUpdate_shouldThrowIfUsersCountIsDifferentThanExpectd() async throws {
    patch(
      \UsersPGPMessages.encryptMessageForResourceUsers,
      with: always([.mock_1])
    )
    patch(
      \ResourceUsersIDFetchDatabaseOperation.execute,
      with: always([.mock_1, .mock_2])
    )
    let sut: ResourceUpdatePreparation = try self.testedInstance()

    await verifyIf(
      try await sut.prepareSecret(.mock_1, "secret"),
      throws: InvalidResourceSecret.self,
      "Should throw if users count is different than expected"
    )
  }

  func test_givenResourceWithUnstructuredSecret_whenPreparingUpdate_shouldFetchSecret() async throws {
    patch(
      \ResourceSecretFetchNetworkOperation.execute,
      with: always(.init(data: "secret"))
    )
    let sut: ResourceUpdatePreparation = try self.testedInstance()
    await verifyIf(
      try await sut.fetchSecret(.mock_1, true),
      isEqual: JSON.string("secret"),
      "Should fetch secret from network"
    )
  }

  func test_givenResourceWithStructuredSecret_whenPreparingUpdate_shouldFetchSecret() async throws {
    patch(
      \ResourceSecretFetchNetworkOperation.execute,
      with: always(.init(data: "{\"secret\":\"value\"}"))
    )

    let sut: ResourceUpdatePreparation = try self.testedInstance()
    await verifyIf(
      try await sut.fetchSecret(.mock_1, false),
      isEqual: JSON.object(["secret": .string("value")]),
      "Should fetch secret from network"
    )
  }
}
