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

  private var updatesSequence: AnyAsyncSequence<Void>!

  override func featuresActorSetUp() async throws {
    try await super.featuresActorSetUp()
    self.features
      .usePlaceholder(for: NetworkClient.self)
    self.features
      .usePlaceholder(for: AccountDatabase.self)
    self.features.usePlaceholder(for: AccountSessionData.self)
    self.updatesSequence = AsyncVariable(initial: Void())
      .asAnyAsyncSequence()
    self.features.patch(
      \AccountSessionData.updatesSequence,
      with: always(
        self.updatesSequence
      )
    )
  }

  override func featuresActorTearDown() async throws {
    try await super.featuresActorTearDown()
    self.updatesSequence = nil
  }

  func test_filteredFolderContent_producesContentForRequestedFolderIDAndFlatteningMode() async throws {
    await self.features
      .patch(
        \AccountDatabase.fetchResourceFolderListItemDSVs,
        with: .failingWith(MockIssue.error())
      )
    await self.features
      .patch(
        \AccountDatabase.fetchResourceListItemDSVs,
        with: .failingWith(MockIssue.error())
      )
    let filter: ResourceFoldersFilter = .init(
      sorting: .nameAlphabetically,
      folderID: .init(rawValue: "FilterFolderID")
    )

    let feature: ResourceFolders = try await self.testInstance()

    var result: Array<FolderContent> = .init()
    for await folderContent in feature.filteredFolderContent(.init([filter])).prefix(1) {
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

  func test_filteredFolderContent_producesEmptyContent_whenDatabaseFetchingFail() async throws {
    await self.features
      .patch(
        \AccountDatabase.fetchResourceFolderListItemDSVs,
        with: .failingWith(MockIssue.error())
      )
    await self.features
      .patch(
        \AccountDatabase.fetchResourceListItemDSVs,
        with: .failingWith(MockIssue.error())
      )
    let filter: ResourceFoldersFilter = .init(
      sorting: .nameAlphabetically,
      folderID: .init(rawValue: "FilterFolderID")
    )

    let feature: ResourceFolders = try await self.testInstance()

    var result: Array<FolderContent> = .init()
    for await folderContent in feature.filteredFolderContent(.init([filter])).prefix(1) {
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

  func test_filteredFolderContent_producesContent_whenDatabaseFetchingSucceeds() async throws {
    let folders: Array<ResourceFolderListItemDSV> = .random(count: 1)

    let resources: Array<ResourceListItemDSV> = .testResources

    await self.features
      .patch(
        \AccountDatabase.fetchResourceFolderListItemDSVs,
        with: .returning(folders)
      )
    await self.features
      .patch(
        \AccountDatabase.fetchResourceListItemDSVs,
        with: .returning(resources)
      )
    let filter: ResourceFoldersFilter = .init(
      sorting: .nameAlphabetically,
      folderID: .init(rawValue: "FilterFolderID")
    )

    let feature: ResourceFolders = try await self.testInstance()

    var result: Array<FolderContent> = .init()
    for await folderContent in feature.filteredFolderContent(.init([filter])).prefix(1) {
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

  func test_filteredFolderContent_producesContentWithRequestedFolderID_whenDatabaseFetchingSucceeds() async throws {
    let folders: Array<ResourceFolderListItemDSV> = .random(count: 1)

    let resources: Array<ResourceListItemDSV> = .testResources

    await self.features
      .patch(
        \AccountDatabase.fetchResourceFolderListItemDSVs,
        with: .returning(folders)
      )
    await self.features
      .patch(
        \AccountDatabase.fetchResourceListItemDSVs,
        with: .returning(resources)
      )
    let filter: ResourceFoldersFilter = .init(
      sorting: .nameAlphabetically,
      folderID: .init(rawValue: "FilterFolderID")
    )

    let feature: ResourceFolders = try await self.testInstance()

    var result: Array<FolderContent> = .init()
    for await folderContent in feature.filteredFolderContent(.init([filter])).prefix(1) {
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

  func test_filteredFolderContent_producesNewContent_whenFiltersChange() async throws {
    let folders: Array<ResourceFolderListItemDSV> = .random(count: 1)

    let resources: Array<ResourceListItemDSV> = .testResources

    await self.features
      .patch(
        \AccountDatabase.fetchResourceFolderListItemDSVs,
        with: .returning(folders)
      )
    await self.features
      .patch(
        \AccountDatabase.fetchResourceListItemDSVs,
        with: .returning(resources)
      )
    let filters: Array<ResourceFoldersFilter> = [
      .init(
        sorting: .nameAlphabetically,
        folderID: .init(rawValue: "FilterFolderID")
      ),
      .init(
        sorting: .nameAlphabetically,
        folderID: .init(rawValue: "OtherFilterFolderID")
      ),
    ]

    let feature: ResourceFolders = try await self.testInstance()

    var result: Array<FolderContent> = .init()
    for await folderContent in feature.filteredFolderContent(.init(filters)).prefix(2) {
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
