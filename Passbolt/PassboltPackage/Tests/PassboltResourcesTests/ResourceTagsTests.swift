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

import SessionData
import TestExtensions

@testable import Accounts
@testable import PassboltResources

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class ResourceTagsTests: LoadableFeatureTestCase<ResourceTags> {

  override class var testedImplementationRegister: (FeatureFactory) -> @MainActor () -> Void {
    FeatureFactory.usePassboltResourceTags
  }

  private var updatesSequence: UpdatesSequenceSource!

  override func prepare() throws {
    self.updatesSequence = .init()
    patch(
      \SessionData.updatesSequence,
      with: self.updatesSequence.updatesSequence
    )
  }

  override func cleanup() throws {
    self.updatesSequence = .none
  }

  func test_filteredTagsList_fetchesData_withGivenFilter() async throws {
    let expectedResult: String = "filter"
    let filtersSequence: AsyncVariable<String> = .init(initial: expectedResult)

    var result: String?
    let uncheckedSendableResult: UncheckedSendable<String?> = .init(
      get: { result },
      set: { result = $0 }
    )
    patch(
      \ResourceTagsListFetchDatabaseOperation.execute,
      with: {
        uncheckedSendableResult.variable = $0
        return []
      }
    )

    let feature: ResourceTags = try await self.testedInstance()

    _ = await feature.filteredTagsList(filtersSequence.asAnyAsyncSequence())
      .first()

    XCTAssertEqual(result, expectedResult)
  }

  func test_filteredTagsList_returnsEmptyList_whenDatabaseFetchFails() async throws {
    let filtersSequence: AsyncVariable<String> = .init(initial: "filter")

    patch(
      \ResourceTagsListFetchDatabaseOperation.execute,
      with: alwaysThrow(MockIssue.error())
    )

    let feature: ResourceTags = try await self.testedInstance()

    let result: Array<ResourceTagListItemDSV>? = await feature.filteredTagsList(filtersSequence.asAnyAsyncSequence())
      .first()

    XCTAssertEqual(result, [])
  }

  func test_filteredTagsList_returnsDataFromDabase() async throws {
    let expectedResult: Array<ResourceTagListItemDSV> = [
      .init(
        id: "resourceID",
        slug: "slug",
        shared: false,
        contentCount: 0
      )
    ]
    let filtersSequence: AsyncVariable<String> = .init(initial: "filter")

    patch(
      \ResourceTagsListFetchDatabaseOperation.execute,
      with: always(expectedResult)
    )

    let feature: ResourceTags = try await self.testedInstance()

    let result: Array<ResourceTagListItemDSV>? = await feature.filteredTagsList(filtersSequence.asAnyAsyncSequence())
      .first()

    XCTAssertEqual(result, expectedResult)
  }

  func test_filteredTagsList_returnsUpdates_whenFilterChanges() async throws {
    var expectedResult: Array<ResourceTagListItemDSV> = []
    let filtersSequence: AsyncVariable<String> = .init(initial: "filter")

    let nextResult: () -> Array<ResourceTagListItemDSV> = {
      defer {
        if expectedResult.isEmpty {
          expectedResult.append(.random())
        }
        else { /* NOP */
        }
      }
      return expectedResult
    }

    patch(
      \ResourceTagsListFetchDatabaseOperation.execute,
      with: always(nextResult())
    )

    let feature: ResourceTags = try await self.testedInstance()

    let filteredTagsSequenceIterator = feature.filteredTagsList(filtersSequence.asAnyAsyncSequence())
      .makeAsyncIterator()
    // ignoring first, expecting update
    _ = await filteredTagsSequenceIterator.next()

    filtersSequence.send("updated")

    let result: Array<ResourceTagListItemDSV>? = await filteredTagsSequenceIterator.next()

    XCTAssertEqual(result, expectedResult)
  }
}