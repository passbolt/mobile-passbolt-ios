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

final class ResourceEditPreparationTests: FeaturesTestCase {

  override func commonPrepare() {
    super.commonPrepare()
    register(
      { $0.usePassboltResourceEditPreparation() },
      for: ResourceEditPreparation.self
    )
    set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_default
      )
    )
  }

  func test_availableTypes_throws_whenLoadingTypesFails() async throws {
    patch(
      \ResourceTypesFetchDatabaseOperation.execute,
      with: alwaysThrow(MockIssue.error())
    )
    let tested: ResourceEditPreparation = try self.testedInstance()
    await verifyIf(
      try await tested.availableTypes(),
      throws: MockIssue.self
    )
  }

  func test_availableTypes_returnsStoredTypes_whenLoadingSucceeds() async throws {
    patch(
      \ResourceTypesFetchDatabaseOperation.execute,
      with: always([.mock_1])
    )
    let tested: ResourceEditPreparation = try self.testedInstance()
    await verifyIf(
      try await tested.availableTypes(),
      isEqual: [.mock_1]
    )
  }

  func test_prepareNew_throws_whenRequestedResourceTypeIsNotAvailable() async throws {
    patch(
      \ResourceTypesFetchDatabaseOperation.execute,
      with: always([.mock_1])
    )
    let tested: ResourceEditPreparation = try self.testedInstance()
    await verifyIf(
      try await tested.prepareNew("unavailable", .none, .none),
      throws: InvalidResourceType.self
    )
  }

  func test_prepareNew_throws_whenRequestedFolderPathLoadingFails() async throws {
    patch(
      \ResourceTypesFetchDatabaseOperation.execute,
      with: always([.mock_1])
    )
    patch(
      \ResourceFolderPathFetchDatabaseOperation.execute,
      with: alwaysThrow(MockIssue.error())
    )
    let tested: ResourceEditPreparation = try self.testedInstance()
    await verifyIf(
      try await tested.prepareNew(.mock_1, .mock_1, .none),
      throws: MockIssue.self
    )
  }

  func test_prepareNew_returnsEditingContext_withRequestedParameters() async throws {
    patch(
      \ResourceTypesFetchDatabaseOperation.execute,
      with: always([.mock_default])
    )
    patch(
      \ResourceFolderPathFetchDatabaseOperation.execute,
      with: always([.mock_1])
    )
    let tested: ResourceEditPreparation = try self.testedInstance()
    await verifyIf(
      try await tested.prepareNew(.default, .mock_1, .mock_passbolt),
      isEqual: .init(
        editedResource: .init(
          id: .none,
          path: [.mock_1],
          favoriteID: .none,
          type: .mock_default,
          permission: .owner,
          tags: [],
          permissions: [],
          modified: .none,
          meta: [
            "name": nil,
            "uri": .string(URLString.mock_passbolt.rawValue),
            "username": nil,
          ],
          secret: [
            "password": nil,
            "description": nil,
          ]
        ),
        availableTypes: [.mock_default]
      )
    )
  }

  func test_prepareExisting_throws_whenRequestedResourceScretFetchngFails() async throws {
    patch(
      \ResourceController.fetchSecretIfNeeded,
      with: alwaysThrow(MockIssue.error())
    )
    let tested: ResourceEditPreparation = try self.testedInstance()
    await verifyIf(
      try await tested.prepareExisting(.mock_1),
      throws: MockIssue.self
    )
  }

  func test_prepareExisting_throws_whenRequestedResourceLoadingFails() async throws {
    patch(
      \ResourceController.fetchSecretIfNeeded,
      with: always(nil)
    )
    patch(
      \ResourceController.state,
      with: Constant(MockIssue.error()).asAnyUpdatable()
    )
    let tested: ResourceEditPreparation = try self.testedInstance()
    await verifyIf(
      try await tested.prepareExisting(.mock_1),
      throws: MockIssue.self
    )
  }

  func test_prepareExisting_throws_whenLoadingAvailableTypesFails() async throws {
    patch(
      \ResourceController.fetchSecretIfNeeded,
      with: always(nil)
    )
    patch(
      \ResourceController.state,
      with: Constant(.mock_1).asAnyUpdatable()
    )
    patch(
      \ResourceTypesFetchDatabaseOperation.execute,
      with: alwaysThrow(MockIssue.error())
    )
    let tested: ResourceEditPreparation = try self.testedInstance()
    await verifyIf(
      try await tested.prepareExisting(.mock_1),
      throws: MockIssue.self
    )
  }

  func test_prepareExisting_returnsEditingContext_withRequestedResource() async throws {
    patch(
      \ResourceController.fetchSecretIfNeeded,
      with: always(nil)
    )
    patch(
      \ResourceController.state,
      with: Constant(.mock_1).asAnyUpdatable()
    )
    patch(
      \ResourceTypesFetchDatabaseOperation.execute,
      with: always([.mock_default])
    )
    let tested: ResourceEditPreparation = try self.testedInstance()
    await verifyIf(
      try await tested.prepareExisting(.mock_1),
      isEqual: .init(
        editedResource: .mock_1,
        availableTypes: [.mock_default]
      )
    )
  }
}
