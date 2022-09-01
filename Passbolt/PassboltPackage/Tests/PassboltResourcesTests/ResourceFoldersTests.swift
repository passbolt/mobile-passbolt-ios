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
import SessionData
import TestExtensions

@testable import PassboltResources

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class ResourceFoldersTests: LoadableFeatureTestCase<ResourceFolders> {

  override class var testedImplementationRegister: (FeatureFactory) -> @MainActor () -> Void {
    FeatureFactory.usePassboltResourceFolders
  }

  private var updatesSequenceSource: UpdatesSequenceSource!

  override func prepare() throws {
    updatesSequenceSource = .init()
    patch(
      \SessionData.updatesSequence,
      with: updatesSequenceSource.updatesSequence
    )
    use(ResourceFolderDetailsFetchDatabaseOperation.placeholder)
  }

  func test_filteredFolderContent_producesContentForRequestedFolderIDAndFlatteningMode() async throws {
    patch(
      \ResourceFoldersListFetchDatabaseOperation.execute,
      with: alwaysThrow(MockIssue.error())
    )
    patch(
      \ResourcesListFetchDatabaseOperation.execute,
      with: alwaysThrow(MockIssue.error())
    )

    let filter: ResourceFoldersFilter = .init(
      sorting: .nameAlphabetically,
      text: "",
      folderID: .init(rawValue: "FilterFolderID"),
      flattenContent: false,
      permissions: .init()
    )

    let feature: ResourceFolders = try await self.testedInstance()

    await XCTAssertError(matches: MockIssue.self) {
      try await feature.filteredFolderContent(filter)
    }
  }

  func test_filteredFolderContent_throws_whenDatabaseFetchingFail() async throws {
    patch(
      \ResourceFoldersListFetchDatabaseOperation.execute,
      with: alwaysThrow(MockIssue.error())
    )
    patch(
      \ResourcesListFetchDatabaseOperation.execute,
      with: alwaysThrow(MockIssue.error())
    )

    let filter: ResourceFoldersFilter = .init(
      sorting: .nameAlphabetically,
      text: "",
      folderID: .init(rawValue: "FilterFolderID"),
      flattenContent: false,
      permissions: .init()
    )

    let feature: ResourceFolders = try await self.testedInstance()

    await XCTAssertError(matches: MockIssue.self) {
      try await feature.filteredFolderContent(filter)
    }
  }

  func test_filteredFolderContent_producesContent_whenDatabaseFetchingSucceeds() async throws {
    let folders: Array<ResourceFolderListItemDSV> = .random(count: 1)

    let resources: Array<ResourceListItemDSV> = .testResources

    patch(
      \ResourceFoldersListFetchDatabaseOperation.execute,
      with: always(folders)
    )
    patch(
      \ResourcesListFetchDatabaseOperation.execute,
      with: always(resources)
    )

    let filter: ResourceFoldersFilter = .init(
      sorting: .nameAlphabetically,
      text: "",
      folderID: .init(rawValue: "FilterFolderID"),
      flattenContent: false,
      permissions: .init()
    )

    let feature: ResourceFolders = try await self.testedInstance()

    let result: ResourceFolderContent = try await feature.filteredFolderContent(filter)

    XCTAssertEqual(
      result,
      .init(
        folderID: filter.folderID,
        flattened: filter.flattenContent,
        subfolders: folders,
        resources: resources
      )
    )
  }

  func test_filteredFolderContent_producesContentWithRequestedFolderID_whenDatabaseFetchingSucceeds() async throws {
    let folders: Array<ResourceFolderListItemDSV> = .random(count: 1)

    let resources: Array<ResourceListItemDSV> = .testResources

    patch(
      \ResourceFoldersListFetchDatabaseOperation.execute,
      with: always(folders)
    )
    patch(
      \ResourcesListFetchDatabaseOperation.execute,
      with: always(resources)
    )

    let filter: ResourceFoldersFilter = .init(
      sorting: .nameAlphabetically,
      text: "",
      folderID: .init(rawValue: "FilterFolderID"),
      flattenContent: false,
      permissions: .init()
    )

    let feature: ResourceFolders = try await self.testedInstance()

    let result: ResourceFolderContent = try await feature.filteredFolderContent(filter)

    XCTAssertEqual(
      result,
      .init(
        folderID: filter.folderID,
        flattened: filter.flattenContent,
        subfolders: folders,
        resources: resources
      )
    )
  }

  func test_filteredFolderContent_producesNewContent_whenFiltersChange() async throws {
    let folders: Array<ResourceFolderListItemDSV> = .random(count: 1)

    let resources: Array<ResourceListItemDSV> = .testResources

    patch(
      \ResourceFoldersListFetchDatabaseOperation.execute,
      with: always(folders)
    )
    patch(
      \ResourcesListFetchDatabaseOperation.execute,
      with: always(resources)
    )

    let filters: Array<ResourceFoldersFilter> = [
      .init(
        sorting: .nameAlphabetically,
        text: "",
        folderID: .init(rawValue: "FilterFolderID"),
        flattenContent: false,
        permissions: .init()
      ),
      .init(
        sorting: .nameAlphabetically,
        text: "",
        folderID: .init(rawValue: "OtherFilterFolderID"),
        flattenContent: false,
        permissions: .init()
      ),
    ]

    let feature: ResourceFolders = try await self.testedInstance()

    var result: Array<ResourceFolderContent> = .init()
    try await result.append(feature.filteredFolderContent(filters[0]))
    try await result.append(feature.filteredFolderContent(filters[1]))

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
