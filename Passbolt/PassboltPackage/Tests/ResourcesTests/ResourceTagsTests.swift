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

@testable import Accounts
@testable import Resources

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class ResourceTagsTests: TestCase {

  override func featuresActorSetUp() async throws {
    try await super.featuresActorSetUp()
    self.features.usePlaceholder(for: AccountDatabase.self)
  }

  func test_filteredTagsList_fetchesData_withGivenFilter() async throws {
    let expectedResult: String = "filter"
    let filtersSequence: AsyncVariable<String> = .init(initial: expectedResult)

    var result: String?
    await self.features
      .patch(
        \AccountDatabase.fetchResourceTagList,
        with: .returning([], storeInputIn: &result)
      )

    let feature: ResourceTags = try await self.testInstance()

    _ = await feature.filteredTagsList(filtersSequence.asAnyAsyncSequence())
      .first()

    XCTAssertEqual(result, expectedResult)
  }

  func test_filteredTagsList_returnsEmptyList_whenDatabaseFetchFails() async throws {
    let filtersSequence: AsyncVariable<String> = .init(initial: "filter")

    await self.features
      .patch(
        \AccountDatabase.fetchResourceTagList,
        with: .failingWith(MockIssue.error())
      )

    let feature: ResourceTags = try await self.testInstance()

    let result: Array<ListViewResourceTag>? = await feature.filteredTagsList(filtersSequence.asAnyAsyncSequence())
      .first()

    XCTAssertEqual(result, [])
  }

  func test_filteredTagsList_returnsDataFromDabase() async throws {
    let expectedResult: Array<ListViewResourceTag> = [
      .init(
        id: "resourceID",
        slug: "slug",
        shared: false,
        contentCount: 0
      )
    ]
    let filtersSequence: AsyncVariable<String> = .init(initial: "filter")

    await self.features
      .patch(
        \AccountDatabase.fetchResourceTagList,
        with: .returning(expectedResult)
      )

    let feature: ResourceTags = try await self.testInstance()

    let result: Array<ListViewResourceTag>? = await feature.filteredTagsList(filtersSequence.asAnyAsyncSequence())
      .first()

    XCTAssertEqual(result, expectedResult)
  }

  func test_filteredTagsList_returnsUpdates_whenFilterChanges() async throws {
    var expectedResult: Array<ListViewResourceTag> = []
    let filtersSequence: AsyncVariable<String> = .init(initial: "filter")

    let nextResult: () -> Array<ListViewResourceTag> = {
      defer {
        if expectedResult.isEmpty {
          expectedResult.append(
            .init(
              id: "resourceID",
              slug: "slug",
              shared: false,
              contentCount: 0
            )
          )
        }
        else { /* NOP */
        }
      }
      return expectedResult
    }

    await self.features
      .patch(
        \AccountDatabase.fetchResourceTagList,
        with: .returning(nextResult())
      )

    let feature: ResourceTags = try await self.testInstance()

    let filteredTagsSequenceIterator = feature.filteredTagsList(filtersSequence.asAnyAsyncSequence())
      .makeAsyncIterator()
    // ignoring first, expecting update
    _ = await filteredTagsSequenceIterator.next()

    try await filtersSequence.send("updated")

    let result: Array<ListViewResourceTag>? = await filteredTagsSequenceIterator.next()

    XCTAssertEqual(result, expectedResult)
  }
}
