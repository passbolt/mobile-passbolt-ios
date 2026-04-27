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

final internal class ResourceFoldersListFetchDatabaseOperationTests: DatabaseOperationsTestCase {

  override internal func registerOperations() {
    register(
      { $0.usePassboltResourceFoldersListFetchDatabaseOperation() },
      for: ResourceFoldersListFetchDatabaseOperation.self
    )
  }

  private func fetchSharedFlag(folderID: ResourceFolder.ID) async throws -> Bool {
    let operation: ResourceFoldersListFetchDatabaseOperation = try testedInstance()
    let results: Array<ResourceFolderListItemDSV> = try await operation(
      .init(
        userID: currentUser.id,
        sorting: .nameAlphabetically,
        folderID: nil
      )
    )
    guard let folder: ResourceFolderListItemDSV = results.first(where: { $0.id == folderID })
    else {
      XCTFail("Folder not found in results")
      return false
    }
    return folder.shared
  }

  // MARK: - Tests

  internal func test_folderWithOnlyCurrentUserPermission_isNotShared() async throws {
    try await setupPrivateFolder()
    let shared: Bool = try await fetchSharedFlag(folderID: testFolderID)
    XCTAssertFalse(shared, "Folder with only current user's permission should not be shared")
  }

  internal func test_folderWithCurrentUserAndOtherUser_isShared() async throws {
    try await setupFolderSharedWithOtherUser()
    let shared: Bool = try await fetchSharedFlag(folderID: testFolderID)
    XCTAssertTrue(shared, "Folder with another user's permission should be shared")
  }

  internal func test_folderWithGroupHavingMultipleMembers_isShared() async throws {
    try await setupFolderWithMultiMemberGroup()
    let shared: Bool = try await fetchSharedFlag(folderID: testFolderID)
    XCTAssertTrue(shared, "Folder with a group having multiple members should be shared")
  }

  internal func test_folderWithGroupHavingSingleMember_isNotShared() async throws {
    try await setupFolderWithSingleMemberGroup()
    let shared: Bool = try await fetchSharedFlag(folderID: testFolderID)
    XCTAssertFalse(shared, "Folder with a group having only one member should not be shared")
  }

  internal func test_folderWithOtherUserAndGroup_isShared() async throws {
    try await setupFolderWithOtherUserAndGroup()
    let shared: Bool = try await fetchSharedFlag(folderID: testFolderID)
    XCTAssertTrue(shared, "Folder with other user and group permissions should be shared")
  }

  internal func test_folderWithSingleMemberGroupOfCurrentUser_isNotShared() async throws {
    try await setupFolderWithSingleMemberGroupOfCurrentUser()
    let shared: Bool = try await fetchSharedFlag(folderID: testFolderID)
    XCTAssertFalse(
      shared,
      "Folder with only current user permission and a single-member group (current user) should not be shared"
    )
  }

  // MARK: - FTS Search Tests

  internal func test_whenSearchingByPrefix_thenMatchingFolderIsReturned() async throws {
    try await storeUsers([currentUser])
    try await storeFolders([
      .init(
        id: .mock_1,
        parentID: nil,
        name: "Engineering",
        permission: .owner,
        permissions: [
          .userToFolder(id: .init(), userID: currentUser.id, folderID: .mock_1, permission: .owner)
        ]
      ),
      .init(
        id: .mock_2,
        parentID: nil,
        name: "Marketing",
        permission: .owner,
        permissions: [
          .userToFolder(id: .init(), userID: currentUser.id, folderID: .mock_2, permission: .owner)
        ]
      ),
    ])

    let operation: ResourceFoldersListFetchDatabaseOperation = try testedInstance()
    let results: Array<ResourceFolderListItemDSV> = try await operation(
      .init(
        userID: currentUser.id,
        sorting: .nameAlphabetically,
        text: "Engin",
        folderID: nil
      )
    )

    XCTAssertEqual(results.count, 1)
    XCTAssertEqual(results[0].name, "Engineering")
  }

  internal func test_whenSearchingSubstring_thenMatchingFolderIsReturned() async throws {
    try await storeUsers([currentUser])
    try await storeFolders([
      .init(
        id: .mock_1,
        parentID: nil,
        name: "Engineering",
        permission: .owner,
        permissions: [
          .userToFolder(id: .init(), userID: currentUser.id, folderID: .mock_1, permission: .owner)
        ]
      ),
      .init(
        id: .mock_2,
        parentID: nil,
        name: "Marketing",
        permission: .owner,
        permissions: [
          .userToFolder(id: .init(), userID: currentUser.id, folderID: .mock_2, permission: .owner)
        ]
      ),
    ])

    let operation: ResourceFoldersListFetchDatabaseOperation = try testedInstance()
    let results: Array<ResourceFolderListItemDSV> = try await operation(
      .init(
        userID: currentUser.id,
        sorting: .nameAlphabetically,
        text: "neering",
        folderID: nil
      )
    )

    XCTAssertEqual(results.count, 1)
    XCTAssertEqual(results[0].name, "Engineering")
  }

  internal func test_whenSearchingCaseInsensitive_thenMatchingFolderIsReturned() async throws {
    try await storeUsers([currentUser])
    try await storeFolders([
      .init(
        id: .mock_1,
        parentID: nil,
        name: "Engineering",
        permission: .owner,
        permissions: [
          .userToFolder(id: .init(), userID: currentUser.id, folderID: .mock_1, permission: .owner)
        ]
      )
    ])

    let operation: ResourceFoldersListFetchDatabaseOperation = try testedInstance()
    let results: Array<ResourceFolderListItemDSV> = try await operation(
      .init(
        userID: currentUser.id,
        sorting: .nameAlphabetically,
        text: "engineering",
        folderID: nil
      )
    )

    XCTAssertEqual(results.count, 1)
    XCTAssertEqual(results[0].name, "Engineering")
  }

  internal func test_whenSearchingDiacriticsInsensitive_thenMatchingFolderIsReturned() async throws {
    try await storeUsers([currentUser])
    try await storeFolders([
      .init(
        id: .mock_1,
        parentID: nil,
        name: "Résumés",
        permission: .owner,
        permissions: [
          .userToFolder(id: .init(), userID: currentUser.id, folderID: .mock_1, permission: .owner)
        ]
      )
    ])

    let operation: ResourceFoldersListFetchDatabaseOperation = try testedInstance()
    let results: Array<ResourceFolderListItemDSV> = try await operation(
      .init(
        userID: currentUser.id,
        sorting: .nameAlphabetically,
        text: "Resumes",
        folderID: nil
      )
    )

    XCTAssertEqual(results.count, 1)
    XCTAssertEqual(results[0].name, "Résumés")
  }

  internal func test_whenSearchingWithNoMatch_thenEmptyResultsReturned() async throws {
    try await storeUsers([currentUser])
    try await storeFolders([
      .init(
        id: .mock_1,
        parentID: nil,
        name: "Engineering",
        permission: .owner,
        permissions: [
          .userToFolder(id: .init(), userID: currentUser.id, folderID: .mock_1, permission: .owner)
        ]
      )
    ])

    let operation: ResourceFoldersListFetchDatabaseOperation = try testedInstance()
    let results: Array<ResourceFolderListItemDSV> = try await operation(
      .init(
        userID: currentUser.id,
        sorting: .nameAlphabetically,
        text: "nonexistent",
        folderID: nil
      )
    )

    XCTAssertEqual(results.count, 0)
  }

  internal func test_whenSearchingWithSpecialCharacters_thenDoesNotCrash() async throws {
    try await storeUsers([currentUser])
    try await storeFolders([
      .init(
        id: .mock_1,
        parentID: nil,
        name: "Engineering",
        permission: .owner,
        permissions: [
          .userToFolder(id: .init(), userID: currentUser.id, folderID: .mock_1, permission: .owner)
        ]
      )
    ])

    let operation: ResourceFoldersListFetchDatabaseOperation = try testedInstance()
    let results: Array<ResourceFolderListItemDSV> = try await operation(
      .init(
        userID: currentUser.id,
        sorting: .nameAlphabetically,
        text: "\"test\" OR NOT",
        folderID: nil
      )
    )

    XCTAssertEqual(results.count, 0)
  }
}
