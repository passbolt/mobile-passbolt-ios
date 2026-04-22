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
import DatabaseOperations
import XCTest

@testable import PassboltDatabaseOperations

final internal class ResourceFolderPathFetchDatabaseOperationTests: DatabaseOperationsTestCase {

  override internal func registerOperations() {
    register(
      { $0.usePassboltResourceFolderPathFetchDatabaseOperation() },
      for: ResourceFolderPathFetchDatabaseOperation.self
    )
  }

  private func fetchPath(
    folderID: ResourceFolder.ID
  ) async throws -> OrderedSet<ResourceFolderPathItem> {
    let operation: ResourceFolderPathFetchDatabaseOperation = try testedInstance()
    return try await operation((folderID: folderID, userID: currentUser.id))
  }

  // MARK: - Shared flag tests on path items

  internal func test_pathOfPrivateFolder_sharedIsFalse() async throws {
    try await setupPrivateFolder()
    let path: OrderedSet<ResourceFolderPathItem> = try await fetchPath(folderID: testFolderID)

    guard let item: ResourceFolderPathItem = path.first(where: { $0.id == testFolderID }) else {
      return XCTFail("Folder not found in path")
    }
    XCTAssertFalse(item.shared, "Private folder path item should not be shared")
  }

  internal func test_pathOfSharedFolder_sharedIsTrue() async throws {
    try await setupFolderSharedWithOtherUser()
    let path: OrderedSet<ResourceFolderPathItem> = try await fetchPath(folderID: testFolderID)

    guard let item: ResourceFolderPathItem = path.first(where: { $0.id == testFolderID }) else {
      return XCTFail("Folder not found in path")
    }
    XCTAssertTrue(item.shared, "Shared folder path item should be shared")
  }

  internal func test_pathOfFolderWithMultiMemberGroup_sharedIsTrue() async throws {
    try await setupFolderWithMultiMemberGroup()
    let path: OrderedSet<ResourceFolderPathItem> = try await fetchPath(folderID: testFolderID)

    guard let item: ResourceFolderPathItem = path.first(where: { $0.id == testFolderID }) else {
      return XCTFail("Folder not found in path")
    }
    XCTAssertTrue(item.shared, "Folder with multi-member group path item should be shared")
  }

  internal func test_pathOfFolderWithSingleMemberGroup_sharedIsFalse() async throws {
    try await setupFolderWithSingleMemberGroup()
    let path: OrderedSet<ResourceFolderPathItem> = try await fetchPath(folderID: testFolderID)

    guard let item: ResourceFolderPathItem = path.first(where: { $0.id == testFolderID }) else {
      return XCTFail("Folder not found in path")
    }
    XCTAssertFalse(item.shared, "Folder with single-member group path item should not be shared")
  }

  internal func test_pathOfFolderWithSingleMemberGroupOfCurrentUser_sharedIsFalse() async throws {
    try await setupFolderWithSingleMemberGroupOfCurrentUser()
    let path: OrderedSet<ResourceFolderPathItem> = try await fetchPath(folderID: testFolderID)

    guard let item: ResourceFolderPathItem = path.first(where: { $0.id == testFolderID }) else {
      return XCTFail("Folder not found in path")
    }
    XCTAssertFalse(item.shared, "Folder with single-member group of current user path item should not be shared")
  }

  // MARK: - Nested path tests

  internal func test_nestedPath_itemsHaveCorrectSharedFlags() async throws {
    try await setupNestedFolderWithSharedParent()
    let path: OrderedSet<ResourceFolderPathItem> = try await fetchPath(folderID: testChildFolderID)

    XCTAssertEqual(path.count, 2, "Path should contain parent and child")

    guard let parentItem: ResourceFolderPathItem = path.first(where: { $0.id == testParentFolderID }) else {
      return XCTFail("Parent not found in path")
    }
    XCTAssertTrue(parentItem.shared, "Parent path item should be shared")

    guard let childItem: ResourceFolderPathItem = path.first(where: { $0.id == testChildFolderID }) else {
      return XCTFail("Child not found in path")
    }
    XCTAssertFalse(childItem.shared, "Child path item should not be shared")
  }
}
