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

final internal class ResourceFolderDetailsFetchDatabaseOperationTests: DatabaseOperationsTestCase {

  override internal func registerOperations() {
    register(
      { $0.usePassboltResourceFolderDetailsFetchDatabaseOperation() },
      for: ResourceFolderDetailsFetchDatabaseOperation.self
    )
  }

  private func fetchFolderDetails(
    folderID: ResourceFolder.ID
  ) async throws -> ResourceFolder {
    let operation: ResourceFolderDetailsFetchDatabaseOperation = try testedInstance()
    return try await operation((folderID: folderID, userID: currentUser.id))
  }

  // MARK: - Shared flag tests

  internal func test_privateFolderDetails_sharedIsFalse() async throws {
    try await setupPrivateFolder()
    let folder: ResourceFolder = try await fetchFolderDetails(folderID: testFolderID)
    XCTAssertFalse(folder.shared, "Folder with only current user's permission should not be shared")
  }

  internal func test_sharedFolderDetails_sharedIsTrue() async throws {
    try await setupFolderSharedWithOtherUser()
    let folder: ResourceFolder = try await fetchFolderDetails(folderID: testFolderID)
    XCTAssertTrue(folder.shared, "Folder with another user's permission should be shared")
  }

  internal func test_folderWithMultiMemberGroup_sharedIsTrue() async throws {
    try await setupFolderWithMultiMemberGroup()
    let folder: ResourceFolder = try await fetchFolderDetails(folderID: testFolderID)
    XCTAssertTrue(folder.shared, "Folder with a group having multiple members should be shared")
  }

  internal func test_folderWithSingleMemberGroup_sharedIsFalse() async throws {
    try await setupFolderWithSingleMemberGroup()
    let folder: ResourceFolder = try await fetchFolderDetails(folderID: testFolderID)
    XCTAssertFalse(folder.shared, "Folder with a group having only one member should not be shared")
  }

  internal func test_folderWithOtherUserAndGroup_sharedIsTrue() async throws {
    try await setupFolderWithOtherUserAndGroup()
    let folder: ResourceFolder = try await fetchFolderDetails(folderID: testFolderID)
    XCTAssertTrue(folder.shared, "Folder with other user and group permissions should be shared")
  }

  internal func test_folderWithSingleMemberGroupOfCurrentUser_sharedIsFalse() async throws {
    try await setupFolderWithSingleMemberGroupOfCurrentUser()
    let folder: ResourceFolder = try await fetchFolderDetails(folderID: testFolderID)
    XCTAssertFalse(
      folder.shared,
      "Folder with only current user permission and a single-member group (current user) should not be shared"
    )
  }

  // MARK: - Path shared flag tests

  internal func test_nestedFolder_pathItemsHaveCorrectSharedFlags() async throws {
    try await setupNestedFolderWithSharedParent()

    let child: ResourceFolder = try await fetchFolderDetails(folderID: testChildFolderID)

    XCTAssertFalse(child.shared, "Child folder with only current user should not be shared")
    XCTAssertEqual(child.path.count, 1, "Child should have one path item (the parent)")

    guard let parentPathItem: ResourceFolderPathItem = child.path.first else {
      return XCTFail("Expected parent in path")
    }
    XCTAssertEqual(parentPathItem.id, testParentFolderID)
    XCTAssertTrue(parentPathItem.shared, "Parent path item should be shared")
  }
}
