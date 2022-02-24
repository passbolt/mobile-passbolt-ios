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
@testable import Resources

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class FoldersTests: TestCase {

  override func setUp() {
    super.setUp()
    self.features
      .usePlaceholder(for: NetworkClient.self)
    self.features
      .usePlaceholder(for: AccountDatabase.self)
  }

  func test_refreshIfNeeded_fails_whenNetworkRequestFails() async {
    self.features
      .patch(
        \NetworkClient.foldersRequest,
        with: .failingWith(MockIssue.error())
      )

    let feature: Folders = self.testInstance()

    do {
      try await feature.refreshIfNeeded()
      XCTFail("Expected error throw")
    }
    catch {
      // expected result
    }
  }

  func test_refreshIfNeeded_fails_whenStoringInDatabaseFails() async {
    self.features
      .patch(
        \NetworkClient.foldersRequest,
        with: .respondingWith(
          .init(
            header: .mock(),
            body: .init()
          )
        )
      )
    self.features
      .patch(
        \AccountDatabase.storeFolders,
        with: .failingWith(MockIssue.error())
      )

    let feature: Folders = self.testInstance()

    do {
      try await feature.refreshIfNeeded()
      XCTFail("Expected error throw")
    }
    catch {
      // expected result
    }
  }

  func test_refreshIfNeeded_succeeds_whenAllOperationsSucceed() async {
    self.features
      .patch(
        \NetworkClient.foldersRequest,
        with: .respondingWith(
          .init(
            header: .mock(),
            body: .init()
          )
        )
      )
    self.features
      .patch(
        \AccountDatabase.storeFolders,
        with: .returning(Void())
      )

    let feature: Folders = self.testInstance()

    do {
      try await feature.refreshIfNeeded()
    }
    catch {
      XCTFail("Unexpected error throw")
    }
  }

  func test_filteredFolderContent_producesNoValue_withoutFilters() async {
    let feature: Folders = self.testInstance()

    var result: Array<FolderContent> = .init()
    for await folderContent in feature.filteredFolderContent(.init([])) {
      result.append(folderContent)
    }

    XCTAssertEqual(result, [])
  }

  func test_filteredFolderContent_producesContentForRequestedFolderIDAndFlatteningMode() async {
    self.features
      .patch(
        \AccountDatabase.fetchListViewFoldersOperation,
        with: .failingWith(MockIssue.error())
      )
    self.features
      .patch(
        \AccountDatabase.fetchListViewFolderResourcesOperation,
        with: .failingWith(MockIssue.error())
      )
    let filter: FoldersFilter = .init(
      sorting: .nameAlphabetically,
      folderID: .init(rawValue: "FilterFolderID")
    )

    let feature: Folders = self.testInstance()

    var result: Array<FolderContent> = .init()
    for await folderContent in feature.filteredFolderContent(.init([filter])) {
      result.append(folderContent)
    }

    XCTAssertEqual(
      result,
      [
        .init(
          folderID: filter.folderID,
          flattened: filter.flattenContent,
          subfolders: [],
          resources: []
        )
      ]
    )
  }

  func test_filteredFolderContent_producesEmptyContent_whenDatabaseFetchingFail() async {
    self.features
      .patch(
        \AccountDatabase.fetchListViewFoldersOperation,
        with: .failingWith(MockIssue.error())
      )
    self.features
      .patch(
        \AccountDatabase.fetchListViewFolderResourcesOperation,
        with: .failingWith(MockIssue.error())
      )
    let filter: FoldersFilter = .init(
      sorting: .nameAlphabetically,
      folderID: .init(rawValue: "FilterFolderID")
    )

    let feature: Folders = self.testInstance()

    var result: Array<FolderContent> = .init()
    for await folderContent in feature.filteredFolderContent(.init([filter])) {
      result.append(folderContent)
    }

    XCTAssertEqual(
      result,
      [
        .init(
          folderID: filter.folderID,
          flattened: filter.flattenContent,
          subfolders: [],
          resources: []
        )
      ]
    )
  }

  func test_filteredFolderContent_producesContent_whenDatabaseFetchingSucceeds() async {
    let folders: Array<ListViewFolder> = [
      .init(
        id: .init(rawValue: "folderID"),
        name: "Folder",
        permission: .owner,
        parentFolderID: nil
      )
    ]

    let resources: Array<ListViewFolderResource> = [
      .init(
        id: .init(rawValue: "resourceID"),
        name: "Folder Resource",
        username: "Username",
        parentFolderID: nil
      )
    ]

    self.features
      .patch(
        \AccountDatabase.fetchListViewFoldersOperation,
        with: .returning(folders)
      )
    self.features
      .patch(
        \AccountDatabase.fetchListViewFolderResourcesOperation,
        with: .returning(resources)
      )
    let filter: FoldersFilter = .init(
      sorting: .nameAlphabetically,
      folderID: .init(rawValue: "FilterFolderID")
    )

    let feature: Folders = self.testInstance()

    var result: Array<FolderContent> = .init()
    for await folderContent in feature.filteredFolderContent(.init([filter])) {
      result.append(folderContent)
    }

    XCTAssertEqual(
      result,
      [
        .init(
          folderID: filter.folderID,
          flattened: filter.flattenContent,
          subfolders: folders,
          resources: resources
        )
      ]
    )
  }

  func test_filteredFolderContent_producesContentWithRequestedFolderID_whenDatabaseFetchingSucceeds() async {
    let folders: Array<ListViewFolder> = [
      .init(
        id: .init(rawValue: "folderID"),
        name: "Folder",
        permission: .owner,
        parentFolderID: nil
      )
    ]

    let resources: Array<ListViewFolderResource> = [
      .init(
        id: .init(rawValue: "resourceID"),
        name: "Folder Resource",
        username: "Username",
        parentFolderID: nil
      )
    ]

    self.features
      .patch(
        \AccountDatabase.fetchListViewFoldersOperation,
        with: .returning(folders)
      )
    self.features
      .patch(
        \AccountDatabase.fetchListViewFolderResourcesOperation,
        with: .returning(resources)
      )
    let filter: FoldersFilter = .init(
      sorting: .nameAlphabetically,
      folderID: .init(rawValue: "FilterFolderID")
    )

    let feature: Folders = self.testInstance()

    var result: Array<FolderContent> = .init()
    for await folderContent in feature.filteredFolderContent(.init([filter])) {
      result.append(folderContent)
    }

    XCTAssertEqual(
      result,
      [
        .init(
          folderID: filter.folderID,
          flattened: filter.flattenContent,
          subfolders: folders,
          resources: resources
        )
      ]
    )
  }

  func test_filteredFolderContent_producesNewContent_whenFiltersChange() async {
    let folders: Array<ListViewFolder> = [
      .init(
        id: .init(rawValue: "folderID"),
        name: "Folder",
        permission: .owner,
        parentFolderID: nil
      )
    ]

    let resources: Array<ListViewFolderResource> = [
      .init(
        id: .init(rawValue: "resourceID"),
        name: "Folder Resource",
        username: "Username",
        parentFolderID: nil
      )
    ]

    self.features
      .patch(
        \AccountDatabase.fetchListViewFoldersOperation,
        with: .returning(folders)
      )
    self.features
      .patch(
        \AccountDatabase.fetchListViewFolderResourcesOperation,
        with: .returning(resources)
      )
    let filters: Array<FoldersFilter> = [
      .init(
        sorting: .nameAlphabetically,
        folderID: .init(rawValue: "FilterFolderID")
      ),
      .init(
        sorting: .nameAlphabetically,
        folderID: .init(rawValue: "OtherFilterFolderID")
      ),
    ]

    let feature: Folders = self.testInstance()

    var result: Array<FolderContent> = .init()
    for await folderContent in feature.filteredFolderContent(.init(filters)) {
      result.append(folderContent)
    }

    XCTAssertEqual(
      result,
      [
        .init(
          folderID: filters[0].folderID,
          flattened: filters[0].flattenContent,
          subfolders: folders,
          resources: resources
        ),
        .init(
          folderID: filters[1].folderID,
          flattened: filters[1].flattenContent,
          subfolders: folders,
          resources: resources
        ),
      ]
    )
  }
}
