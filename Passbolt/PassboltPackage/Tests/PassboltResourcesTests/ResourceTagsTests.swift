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
import FeatureScopes
import Resources
import SessionData
import TestExtensions

@testable import Accounts
@testable import PassboltResources

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class ResourceTagsTests: LoadableFeatureTestCase<ResourceTags>, @unchecked Sendable {

  override class var testedImplementationScope: any FeaturesScope.Type { SessionScope.self }

  override class func testedImplementationRegister(
    _ registry: inout FeaturesRegistry
  ) {
    registry.usePassboltResourceTags()
  }

  private var updatesSequence: Variable<Timestamp>!

  override func prepare() throws {
    self.set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_1
      )
    )

    self.updatesSequence = .init(initial: 0)
    patch(
      \SessionData.lastUpdate,
      with: self.updatesSequence.asAnyUpdatable()
    )
    use(ResourceTagDetailsFetchDatabaseOperation.placeholder)
  }

  override func cleanup() throws {
    self.updatesSequence = .none
  }

  func test_filteredTagsList_fetchesData_withGivenFilter() async throws {
    let expectedText: String = "filter"

    let result: UnsafeSendable<ResourceTagsDatabaseFilter?> = .init()
    patch(
      \ResourceTagsListFetchDatabaseOperation.execute,
      with: { (input) async throws in
        result.value = input
        return []
      }
    )

    let feature: ResourceTags = try self.testedInstance()

    _ = try await feature.filteredTagsList(.init(text: expectedText))

    XCTAssertEqual(result.value??.text, expectedText)
  }

  func test_filteredTagsList_throws_whenDatabaseFetchFails() async throws {
    patch(
      \ResourceTagsListFetchDatabaseOperation.execute,
      with: alwaysThrow(MockIssue.error())
    )

    let feature: ResourceTags = try self.testedInstance()

    await XCTAssertError(matches: MockIssue.self) {
      try await feature.filteredTagsList(.init(text: "filter"))
    }
  }

  func test_filteredTagsList_returnsDataFromDabase() async throws {
    let expectedResult: Array<ResourceTagListItemDSV> = [
      .init(
        id: .mock_1,
        slug: "slug",
        shared: false,
        contentCount: 0
      )
    ]

    patch(
      \ResourceTagsListFetchDatabaseOperation.execute,
      with: always(expectedResult)
    )

    let feature: ResourceTags = try self.testedInstance()

    let result: Array<ResourceTagListItemDSV> = try await feature.filteredTagsList(.init(text: "filter"))

    XCTAssertEqual(result, expectedResult)
  }

  func test_filteredTagsList_respectsPaginationLimit() async throws {
    let result: UnsafeSendable<ResourceTagsDatabaseFilter?> = .init()
    patch(
      \ResourceTagsListFetchDatabaseOperation.execute,
      with: { (input) async throws in
        result.value = input
        return []
      }
    )

    let feature: ResourceTags = try self.testedInstance()

    _ = try await feature.filteredTagsList(.init(text: "filter", limit: 25, offset: 0))

    XCTAssertEqual(result.value??.limit, 25)
    XCTAssertEqual(result.value??.offset, 0)
  }

  func test_filteredTagsList_respectsPaginationOffset() async throws {
    let result: UnsafeSendable<ResourceTagsDatabaseFilter?> = .init()
    patch(
      \ResourceTagsListFetchDatabaseOperation.execute,
      with: { (input) async throws in
        result.value = input
        return []
      }
    )

    let feature: ResourceTags = try self.testedInstance()

    _ = try await feature.filteredTagsList(.init(text: "filter", limit: 50, offset: 100))

    XCTAssertEqual(result.value??.limit, 50)
    XCTAssertEqual(result.value??.offset, 100)
  }

  func test_filteredTagsList_handlesEmptyResultsWithPagination() async throws {
    patch(
      \ResourceTagsListFetchDatabaseOperation.execute,
      with: always([])
    )

    let feature: ResourceTags = try self.testedInstance()

    let result: Array<ResourceTagListItemDSV> = try await feature.filteredTagsList(
      .init(text: "nonexistent", limit: 50, offset: 1000)
    )

    XCTAssertTrue(result.isEmpty)
  }

  func test_filteredTagsList_handlesNilLimit() async throws {
    let result: UnsafeSendable<ResourceTagsDatabaseFilter?> = .init()
    patch(
      \ResourceTagsListFetchDatabaseOperation.execute,
      with: { (input) async throws in
        result.value = input
        return []
      }
    )

    let feature: ResourceTags = try self.testedInstance()

    _ = try await feature.filteredTagsList(.init(text: "filter", limit: nil, offset: 0))

    XCTAssertNil(result.value??.limit)
    XCTAssertEqual(result.value??.offset, 0)
  }
}
