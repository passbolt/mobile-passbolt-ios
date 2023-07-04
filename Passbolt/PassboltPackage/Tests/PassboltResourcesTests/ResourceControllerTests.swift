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
import FeatureScopes
import SessionData
import TestExtensions
import XCTest

@testable import PassboltResources
@testable import Resources

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
@available(iOS 16.0.0, *)
final class ResourceControllerTests: FeaturesTestCase {

  override func commonPrepare() {
    super.commonPrepare()
    register(
      { $0.usePassboltResourceController() },
      for: ResourceController.self
    )
    set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_1
      )
    )
    set(
      ResourceDetailsScope.self,
      context: .mock_1
    )
    patch(
      \SessionData.lastUpdate,
      with: Constant<Timestamp, Never>(value: 0)
    )
  }

  func test_state_providesDatabaseValue_initially() async throws {
    let expectedResult: Resource = .mock_1
    patch(
      \ResourceDetailsFetchDatabaseOperation.execute,
      with: always(expectedResult)
    )

    let feature: ResourceController = try self.testedInstance()

    // execute scheduled automatic updates
    await self.asyncExecutionControl.executeNext()
    await XCTAssertValue(
      equal: expectedResult
    ) {
      try await feature.state.current
    }
  }

  func test_state_isBroken_whenDatabaseFails() async throws {
    patch(
      \ResourceDetailsFetchDatabaseOperation.execute,
      with: alwaysThrow(MockIssue.error())
    )

    let feature: ResourceController = try self.testedInstance()

    // execute scheduled automatic updates
    await self.asyncExecutionControl.executeNext()
    await XCTAssertError(
      matches: MockIssue.self
    ) {
      try await feature.state.current
    }
  }

  func test_state_isBroken_whenInitialResourceIsNotValid() async throws {
    var resource: Resource = .mock_1
    // ensure invalid resource, it should have some meta or secret rquired
    resource.meta = nil
    resource.secret = nil
    patch(
      \ResourceDetailsFetchDatabaseOperation.execute,
      with: always(resource)
    )

    let feature: ResourceController = try self.testedInstance()

    // execute scheduled automatic updates
    await self.asyncExecutionControl.executeNext()
    await XCTAssertError(
      matches: InvalidResourceField.self
    ) {
      try await feature.state.current
    }
  }

  func test_state_updates_whenSessionDataUpdates() async throws {
    let updatesSource: UpdatesSource = .init()
    patch(
      \SessionData.updates,
      with: updatesSource.updates
    )
    let expectedResult_0: Resource = {
      var resource: Resource = .mock_1
      resource.meta.name = "expectedResult_0"
      return resource
    }()
    let expectedResult_1: Resource = {
      var resource: Resource = .mock_1
      resource.meta.name = "expectedResult_1"
      return resource
    }()
    let expectedResult_2: Resource = {
      var resource: Resource = .mock_1
      resource.meta.name = "expectedResult_2"
      return resource
    }()
    patch(
      \ResourceDetailsFetchDatabaseOperation.execute,
      with: { _ in
        let executionCount: Int = self.dynamicVariables.getIfPresent(\.executionCount, of: Int.self) ?? 0
        self.dynamicVariables.set(\.executionCount, to: executionCount + 1)
        switch executionCount {
        case 0:
          return expectedResult_0

        case 1:
          return expectedResult_1

        case 2:
          return expectedResult_2

        case _:
          // ends updates
          XCTFail("Updates should be ended")
          throw CancellationError()
        }
      }
    )

    let feature: ResourceController = try self.testedInstance()

    await XCTAssertValue(
      equal: expectedResult_0
    ) {
      try await feature.state.current
    }

    updatesSource.sendUpdate()
    await XCTAssertValue(
      equal: expectedResult_1
    ) {
      try await feature.state.current
    }

    updatesSource.sendUpdate()
    await XCTAssertValue(
      equal: expectedResult_2
    ) {
      try await feature.state.current
    }

    XCTAssertEqual(self.dynamicVariables.getIfPresent(\.executionCount, of: Int.self), 3)
  }

  func test_state_breaks_whenSessionDataUpdatesFail() async throws {
    let updatesSource: UpdatesSource = .init()
    patch(
      \SessionData.updates,
      with: updatesSource.updates
    )
    let expectedResult: Resource = .mock_1
    patch(
      \ResourceDetailsFetchDatabaseOperation.execute,
      with: { _ in
        let executionCount: Int = self.dynamicVariables.getIfPresent(\.executionCount, of: Int.self) ?? 0
        self.dynamicVariables.set(\.executionCount, to: executionCount + 1)
        switch executionCount {
        case 0:
          return expectedResult

        case _:
          // fail updates
          throw MockIssue.error()
        }
      }
    )

    let feature: ResourceController = try self.testedInstance()

    await XCTAssertValue(
      equal: expectedResult
    ) {
      try await feature.state.current
    }

    updatesSource.sendUpdate()
    await XCTAssertError(
      matches: MockIssue.self
    ) {
      try await feature.state.current
    }

    XCTAssertEqual(self.dynamicVariables.getIfPresent(\.executionCount, of: Int.self), 2)
  }

  func test_fetchSecretIfNeeded_failsWhenFetchingSecretFromNetworkFails() async throws {
    var resource: Resource = .mock_1
    resource.secret = nil  // ensure no initial secret
    patch(
      \ResourceDetailsFetchDatabaseOperation.execute,
      with: always(resource)
    )
    patch(
      \ResourceSecretFetchNetworkOperation.execute,
      with: alwaysThrow(MockIssue.error())
    )

    let feature: ResourceController = try self.testedInstance()

    // execute scheduled automatic updates
    await self.asyncExecutionControl.executeNext()
    await XCTAssertError(
      matches: MockIssue.self
    ) {
      try await feature.fetchSecretIfNeeded(force: true)
    }
  }

  func test_fetchSecretIfNeeded_failsWhenDecryptingSecretFails() async throws {
    var resource: Resource = .mock_1
    resource.secret = nil  // ensure no initial secret
    patch(
      \ResourceDetailsFetchDatabaseOperation.execute,
      with: always(resource)
    )
    patch(
      \ResourceSecretFetchNetworkOperation.execute,
      with: always(.init(data: "encrypted_secret"))
    )
    patch(
      \SessionCryptography.decryptMessage,
      with: alwaysThrow(MockIssue.error())
    )

    let feature: ResourceController = try self.testedInstance()

    // execute scheduled automatic updates
    await self.asyncExecutionControl.executeNext()
    await XCTAssertError(
      matches: MockIssue.self
    ) {
      try await feature.fetchSecretIfNeeded(force: true)
    }
  }

  func test_fetchSecretIfNeeded_failsWhenSecretValidationFails() async throws {
    var resource: Resource = .mock_1
    resource.secret = nil  // ensure no initial secret
    patch(
      \ResourceDetailsFetchDatabaseOperation.execute,
      with: always(resource)
    )
    patch(
      \ResourceSecretFetchNetworkOperation.execute,
      with: always(.init(data: "encrypted_secret"))
    )
    patch(
      \SessionCryptography.decryptMessage,
      with: always("{\"secret\":\"invalid\"}")
    )

    let feature: ResourceController = try self.testedInstance()

    // execute scheduled automatic updates
    await self.asyncExecutionControl.executeNext()
    await XCTAssertError(
      matches: InvalidResourceField.self
    ) {
      try await feature.fetchSecretIfNeeded()
    }
  }

  func test_fetchSecretIfNeeded_fetchesSecretFromNetworkInitially() async throws {
    var resource: Resource = .mock_1
    resource.secret = nil  // ensure no initial secret
    patch(
      \ResourceDetailsFetchDatabaseOperation.execute,
      with: always(resource)
    )
    patch(
      \ResourceSecretFetchNetworkOperation.execute,
      with: always(.init(data: "encrypted_secret"))
    )
    patch(
      \SessionCryptography.decryptMessage,
      with: always("{\"password\":\"decrypted\"}")
    )

    let feature: ResourceController = try self.testedInstance()

    // execute scheduled automatic updates
    await self.asyncExecutionControl.executeNext()
    await XCTAssertValue(
      equal: ["password": "decrypted"]
    ) {
      try await feature.fetchSecretIfNeeded()
    }
  }

  func test_fetchSecretIfNeeded_doesNotFetchSecretFromNetworkWhenAvailable() async throws {
    var resource: Resource = .mock_1
    resource.secret = ["password": "initial"]  // ensure any initial secret
    patch(
      \ResourceDetailsFetchDatabaseOperation.execute,
      with: always(resource)
    )

    let feature: ResourceController = try self.testedInstance()

    // execute scheduled automatic updates
    await self.asyncExecutionControl.executeNext()
    await XCTAssertValue(
      equal: ["password": "initial"]
    ) {
      try await feature.fetchSecretIfNeeded(force: false)
    }
  }

  func test_fetchSecretIfNeeded_fetchesSecretFromNetworkWhenAvailableButForced() async throws {
    var resource: Resource = .mock_1
    resource.secret = ["password": "initial"]  // ensure any initial secret
    patch(
      \ResourceDetailsFetchDatabaseOperation.execute,
      with: always(resource)
    )
    patch(
      \ResourceSecretFetchNetworkOperation.execute,
      with: { _ in
        let iteration: Int = self.dynamicVariables.getIfPresent(\.executedCount, of: Int.self) ?? 0
        self.dynamicVariables.set(\.executedCount, to: iteration + 1)
        return .init(data: "encrypted_secret")
      }
    )
    patch(
      \SessionCryptography.decryptMessage,
      with: always("{\"password\":\"decrypted\"}")
    )

    let feature: ResourceController = try self.testedInstance()

    // execute scheduled automatic updates
    await self.asyncExecutionControl.executeNext()
    await XCTAssertValue(
      equal: ["password": "decrypted"]
    ) {
      try await feature.fetchSecretIfNeeded(force: true)
    }
    XCTAssertEqual(self.dynamicVariables.getIfPresent(\.executedCount, of: Int.self), 1)
  }

  func test_toggleFavorite_throws_whenNetworkRequestThrows_whenAddingFavorite() async throws {
    var resource: Resource = .mock_1
    resource.favoriteID = .none
    patch(
      \ResourceDetailsFetchDatabaseOperation.execute,
      with: always(resource)
    )
    patch(
      \ResourceFavoriteAddNetworkOperation.execute,
      with: alwaysThrow(MockIssue.error())
    )

    let feature: ResourceController = try self.testedInstance()

    // execute scheduled automatic updates
    await self.asyncExecutionControl.executeNext()
    await XCTAssertError(
      matches: MockIssue.self
    ) {
      try await feature.toggleFavorite()
    }
  }

  func test_toggleFavorite_throws_whenNetworkRequestThrows_whenRemovingFavorite() async throws {
    var resource: Resource = .mock_1
    resource.favoriteID = .mock_1
    patch(
      \ResourceDetailsFetchDatabaseOperation.execute,
      with: always(resource)
    )
    patch(
      \ResourceFavoriteDeleteNetworkOperation.execute,
      with: alwaysThrow(MockIssue.error())
    )

    let feature: ResourceController = try self.testedInstance()

    // execute scheduled automatic updates
    await self.asyncExecutionControl.executeNext()
    await XCTAssertError(
      matches: MockIssue.self
    ) {
      try await feature.toggleFavorite()
    }
  }

  func test_toggleFavorite_addsFavorite_whenAddingFavoriteSucceeds() async throws {
    var resource: Resource = .mock_1
    resource.favoriteID = .none
    patch(
      \ResourceDetailsFetchDatabaseOperation.execute,
      with: always(resource)
    )
    patch(
      \ResourceSetFavoriteDatabaseOperation.execute,
      with: always(Void())
    )
    patch(
      \ResourceFavoriteAddNetworkOperation.execute,
      with: always(.init(favoriteID: .mock_1))
    )

    let feature: ResourceController = try self.testedInstance()

    // execute scheduled automatic updates
    await self.asyncExecutionControl.executeNext()
    await XCTAssertNoError {
      try await feature.toggleFavorite()
    }
    await XCTAssertValue(
      equal: .mock_1
    ) {
      try await feature.state.current.favoriteID
    }
  }

  func test_toggleFavorite_removesFavorite_whenDeletingFavoriteSucceeds() async throws {
    var resource: Resource = .mock_1
    resource.favoriteID = .mock_1
    patch(
      \ResourceDetailsFetchDatabaseOperation.execute,
      with: always(resource)
    )
    patch(
      \ResourceSetFavoriteDatabaseOperation.execute,
      with: always(Void())
    )
    patch(
      \ResourceFavoriteDeleteNetworkOperation.execute,
      with: always(Void())
    )

    let feature: ResourceController = try self.testedInstance()

    // execute scheduled automatic updates
    await self.asyncExecutionControl.executeNext()
    await XCTAssertNoError {
      try await feature.toggleFavorite()
    }
    await XCTAssertValue(
      equal: .none
    ) {
      try await feature.state.current.favoriteID
    }
  }

  func test_delete_fails_whenDeleteFails() async throws {
    var resource: Resource = .mock_1
    resource.favoriteID = .mock_1
    patch(
      \ResourceDetailsFetchDatabaseOperation.execute,
      with: always(resource)
    )
    patch(
      \ResourceDeleteNetworkOperation.execute,
      with: alwaysThrow(MockIssue.error())
    )
    patch(
      \SessionData.refreshIfNeeded,
      with: always(Void())
    )

    let feature: ResourceController = try self.testedInstance()

    // execute scheduled automatic updates
    await self.asyncExecutionControl.executeNext()
    await XCTAssertError(
      matches: MockIssue.self
    ) {
      try await feature.delete()
    }
  }

  func test_delete_succeeds_whenDeleteSucceeds() async throws {
    var resource: Resource = .mock_1
    resource.favoriteID = .mock_1
    patch(
      \ResourceDetailsFetchDatabaseOperation.execute,
      with: always(resource)
    )
    patch(
      \ResourceDeleteNetworkOperation.execute,
      with: always(Void())
    )
    patch(
      \SessionData.refreshIfNeeded,
      with: always(Void())
    )

    let feature: ResourceController = try self.testedInstance()

    // execute scheduled automatic updates
    await self.asyncExecutionControl.executeNext()
    await XCTAssertNoError {
      try await feature.delete()
    }
  }
}
