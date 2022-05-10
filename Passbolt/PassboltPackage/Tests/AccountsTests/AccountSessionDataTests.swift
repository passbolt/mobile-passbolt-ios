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
import XCTest

@testable import Accounts

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class AccountSessionDataTests: TestCase {

  override func featuresActorSetUp() async throws {
    try await super.featuresActorSetUp()
    environment.time.timestamp = always(0)
    features.usePlaceholder(for: NetworkClient.self)
    features.usePlaceholder(for: AccountDatabase.self)
    features.usePlaceholder(for: FeatureConfig.self)
    features.patch(
      \FeatureConfig.config,
      with: always(.none)
    )
    features.patch(
      \NetworkClient.userListRequest,
      with: .respondingWith(.init(header: .mock(), body: []))
    )
    features.patch(
      \AccountDatabase.storeUsers,
      with: .returning(Void())
    )

    features.patch(
      \NetworkClient.userGroupsRequest,
      with: .respondingWith(.init(header: .mock(), body: []))
    )
    features.patch(
      \AccountDatabase.storeUserGroups,
      with: .returning(Void())
    )

    features.patch(
      \NetworkClient.foldersRequest,
      with: .respondingWith(.init(header: .mock(), body: []))
    )
    features.patch(
      \AccountDatabase.storeFolders,
      with: .returning(Void())
    )

    features.patch(
      \NetworkClient.resourcesTypesRequest,
      with: .respondingWith(.init(header: .mock(), body: []))
    )
    features.patch(
      \AccountDatabase.storeResourcesTypes,
      with: .returning(Void())
    )

    features.patch(
      \NetworkClient.resourcesRequest,
      with: .respondingWith(.init(header: .mock(), body: []))
    )
    features.patch(
      \AccountDatabase.storeResources,
      with: .returning(Void())
    )
  }

  func test_refreshIfNeeded_storesUsersInDatabase_whenFetchingSucceeds() async throws {
    var fetchVariable: UserListRequestVariable?
    await features.patch(
      \NetworkClient.userListRequest,
      with: .respondingWith(
        .init(header: .mock(), body: []),
        storeVariableIn: &fetchVariable
      )
    )
    var storeVariable: Array<UserDTO>?
    await features.patch(
      \AccountDatabase.storeUsers,
      with: .returning(
        Void(),
        storeInputIn: &storeVariable
      )
    )

    let feature: AccountSessionData = try await testInstance()

    do {
      try await feature
        .refreshIfNeeded()
    }
    catch {
      XCTFail("\(error)")
    }

    XCTAssertNotNil(fetchVariable)
    XCTAssertNotNil(storeVariable)
  }

  func test_refreshIfNeeded_fails_whenFetchUsersFails() async throws {
    await features.patch(
      \NetworkClient.userListRequest,
      with: .failingWith(MockIssue.error())
    )

    let feature: AccountSessionData = try await testInstance()

    var result: Error?
    do {
      try await feature
        .refreshIfNeeded()
    }
    catch {
      result = error
    }

    XCTAssertError(
      result,
      matches: MockIssue.self
    )
  }

  func test_refreshIfNeeded_fails_whenStoreUsersFails() async throws {
    await features.patch(
      \AccountDatabase.storeUsers,
      with: .failingWith(MockIssue.error())
    )

    let feature: AccountSessionData = try await testInstance()

    var result: Error?
    do {
      try await feature
        .refreshIfNeeded()
    }
    catch {
      result = error
    }

    XCTAssertError(
      result,
      matches: MockIssue.self
    )
  }

  func test_refreshIfNeeded_storesUserGroupsInDatabase_whenFetchingSucceeds() async throws {
    var fetchVariable: UserGroupsRequestVariable?
    await features.patch(
      \NetworkClient.userGroupsRequest,
      with: .respondingWith(
        .init(header: .mock(), body: []),
        storeVariableIn: &fetchVariable
      )
    )
    var storeVariable: Array<UserGroupDTO>?
    await features.patch(
      \AccountDatabase.storeUserGroups,
      with: .returning(
        Void(),
        storeInputIn: &storeVariable
      )
    )

    let feature: AccountSessionData = try await testInstance()

    do {
      try await feature
        .refreshIfNeeded()
    }
    catch {
      XCTFail("\(error)")
    }

    XCTAssertNotNil(fetchVariable)
    XCTAssertNotNil(storeVariable)
  }

  func test_refreshIfNeeded_fails_whenFetchUserGroupsFails() async throws {
    await features.patch(
      \NetworkClient.userGroupsRequest,
      with: .failingWith(MockIssue.error())
    )

    let feature: AccountSessionData = try await testInstance()

    var result: Error?
    do {
      try await feature
        .refreshIfNeeded()
    }
    catch {
      result = error
    }

    XCTAssertError(
      result,
      matches: MockIssue.self
    )
  }

  func test_refreshIfNeeded_fails_whenStoreUserGroupsFails() async throws {
    await features.patch(
      \AccountDatabase.storeUserGroups,
      with: .failingWith(MockIssue.error())
    )

    let feature: AccountSessionData = try await testInstance()

    var result: Error?
    do {
      try await feature
        .refreshIfNeeded()
    }
    catch {
      result = error
    }

    XCTAssertError(
      result,
      matches: MockIssue.self
    )
  }

  func test_refreshIfNeeded_storesFoldersInDatabase_whenFetchingSucceeds() async throws {
    await features.patch(
      \FeatureConfig.config,
      with: always(.some(FeatureFlags.Folders.enabled(version: "version")))
    )
    var fetchVariable: FoldersRequestVariable?
    await features.patch(
      \NetworkClient.foldersRequest,
      with: .respondingWith(
        .init(header: .mock(), body: []),
        storeVariableIn: &fetchVariable
      )
    )
    var storeVariable: Array<ResourceFolderDTO>?
    await features.patch(
      \AccountDatabase.storeFolders,
      with: .returning(
        Void(),
        storeInputIn: &storeVariable
      )
    )

    let feature: AccountSessionData = try await testInstance()

    do {
      try await feature
        .refreshIfNeeded()
    }
    catch {
      XCTFail("\(error)")
    }

    XCTAssertNotNil(fetchVariable)
    XCTAssertNotNil(storeVariable)
  }

  func test_refreshIfNeeded_doesNotFetchFolders_whenFoldersDisabled() async throws {
    await features.patch(
      \FeatureConfig.config,
      with: always(.some(FeatureFlags.Folders.disabled))
    )
    var fetchVariable: FoldersRequestVariable?
    await features.patch(
      \NetworkClient.foldersRequest,
      with: .respondingWith(
        .init(header: .mock(), body: []),
        storeVariableIn: &fetchVariable
      )
    )
    var storeVariable: Array<ResourceFolderDTO>?
    await features.patch(
      \AccountDatabase.storeFolders,
      with: .returning(
        Void(),
        storeInputIn: &storeVariable
      )
    )

    let feature: AccountSessionData = try await testInstance()

    do {
      try await feature
        .refreshIfNeeded()
    }
    catch {
      XCTFail("\(error)")
    }

    XCTAssertNil(fetchVariable)
    XCTAssertNil(storeVariable)
  }

  func test_refreshIfNeeded_fails_whenFetchFolderFails() async throws {
    await features.patch(
      \FeatureConfig.config,
      with: always(.some(FeatureFlags.Folders.enabled(version: "version")))
    )
    await features.patch(
      \NetworkClient.foldersRequest,
      with: .failingWith(MockIssue.error())
    )

    let feature: AccountSessionData = try await testInstance()

    var result: Error?
    do {
      try await feature
        .refreshIfNeeded()
    }
    catch {
      result = error
    }

    XCTAssertError(
      result,
      matches: MockIssue.self
    )
  }

  func test_refreshIfNeeded_fails_whenStoreFolderFails() async throws {
    await features.patch(
      \FeatureConfig.config,
      with: always(.some(FeatureFlags.Folders.enabled(version: "version")))
    )
    await features.patch(
      \AccountDatabase.storeFolders,
      with: .failingWith(MockIssue.error())
    )

    let feature: AccountSessionData = try await testInstance()

    var result: Error?
    do {
      try await feature
        .refreshIfNeeded()
    }
    catch {
      result = error
    }

    XCTAssertError(
      result,
      matches: MockIssue.self
    )
  }

  func test_refreshIfNeeded_storesResourceTypesInDatabase_whenFetchingSucceeds() async throws {
    var fetchVariable: ResourcesTypesRequestVariable?
    await features.patch(
      \NetworkClient.resourcesTypesRequest,
      with: .respondingWith(
        .init(header: .mock(), body: []),
        storeVariableIn: &fetchVariable
      )
    )
    var storeVariable: Array<ResourceTypeDTO>?
    await features.patch(
      \AccountDatabase.storeResourcesTypes,
      with: .returning(
        Void(),
        storeInputIn: &storeVariable
      )
    )

    let feature: AccountSessionData = try await testInstance()

    do {
      try await feature
        .refreshIfNeeded()
    }
    catch {
      XCTFail("\(error)")
    }

    XCTAssertNotNil(fetchVariable)
    XCTAssertNotNil(storeVariable)
  }

  func test_refreshIfNeeded_fails_whenFetchResourceTypesFails() async throws {
    await features.patch(
      \NetworkClient.resourcesTypesRequest,
      with: .failingWith(MockIssue.error())
    )

    let feature: AccountSessionData = try await testInstance()

    var result: Error?
    do {
      try await feature
        .refreshIfNeeded()
    }
    catch {
      result = error
    }

    XCTAssertError(
      result,
      matches: MockIssue.self
    )
  }

  func test_refreshIfNeeded_fails_whenStoresResourceTypesFails() async throws {
    await features.patch(
      \AccountDatabase.storeResourcesTypes,
      with: .failingWith(MockIssue.error())
    )

    let feature: AccountSessionData = try await testInstance()

    var result: Error?
    do {
      try await feature
        .refreshIfNeeded()
    }
    catch {
      result = error
    }

    XCTAssertError(
      result,
      matches: MockIssue.self
    )
  }

  func test_refreshIfNeeded_storesResourcesInDatabase_whenFetchingSucceeds() async throws {
    var fetchVariable: ResourcesRequestVariable?
    await features.patch(
      \NetworkClient.resourcesRequest,
      with: .respondingWith(
        .init(header: .mock(), body: []),
        storeVariableIn: &fetchVariable
      )
    )
    var storeVariable: Array<ResourceDTO>?
    await features.patch(
      \AccountDatabase.storeResources,
      with: .returning(
        Void(),
        storeInputIn: &storeVariable
      )
    )

    let feature: AccountSessionData = try await testInstance()

    do {
      try await feature
        .refreshIfNeeded()
    }
    catch {
      XCTFail("\(error)")
    }

    XCTAssertNotNil(fetchVariable)
    XCTAssertNotNil(storeVariable)
  }

  func test_refreshIfNeeded_fails_whenFetchResourcesFails() async throws {
    await features.patch(
      \NetworkClient.resourcesRequest,
      with: .failingWith(MockIssue.error())
    )

    let feature: AccountSessionData = try await testInstance()

    var result: Error?
    do {
      try await feature
        .refreshIfNeeded()
    }
    catch {
      result = error
    }

    XCTAssertError(
      result,
      matches: MockIssue.self
    )
  }

  func test_refreshIfNeeded_fails_whenStoresResourcesFails() async throws {
    await features.patch(
      \AccountDatabase.storeResources,
      with: .failingWith(MockIssue.error())
    )

    let feature: AccountSessionData = try await testInstance()

    var result: Error?
    do {
      try await feature
        .refreshIfNeeded()
    }
    catch {
      result = error
    }

    XCTAssertError(
      result,
      matches: MockIssue.self
    )
  }
}
