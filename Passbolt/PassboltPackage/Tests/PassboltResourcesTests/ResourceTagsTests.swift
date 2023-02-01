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

  override class var testedImplementationScope: any FeaturesScope.Type { SessionScope.self }

  override class func testedImplementationRegister(
    _ registry: inout FeaturesRegistry
  ) {
    registry.usePassboltResourceTags()
  }

  private var updatesSequence: UpdatesSequenceSource!

  override func prepare() throws {
    self.set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_1
      )
    )

    self.updatesSequence = .init()
    patch(
      \SessionData.updatesSequence,
      with: self.updatesSequence.updatesSequence
    )
    use(ResourceTagDetailsFetchDatabaseOperation.placeholder)
  }

  override func cleanup() throws {
    self.updatesSequence = .none
  }

  func test_filteredTagsList_fetchesData_withGivenFilter() async throws {
    let expectedResult: String = "filter"

    var result: String?
    let uncheckedSendableResult: UncheckedSendable<String?> = .init(
      get: { result },
      set: { result = $0 }
    )
    patch(
      \ResourceTagsListFetchDatabaseOperation.execute,
      with: { (input) async throws in
        uncheckedSendableResult.variable = input
        return []
      }
    )

    let feature: ResourceTags = try await self.testedInstance()

    _ = try await feature.filteredTagsList(expectedResult)

    XCTAssertEqual(result, expectedResult)
  }

  func test_filteredTagsList_throws_whenDatabaseFetchFails() async throws {
    patch(
      \ResourceTagsListFetchDatabaseOperation.execute,
      with: alwaysThrow(MockIssue.error())
    )

    let feature: ResourceTags = try await self.testedInstance()

    await XCTAssertError(matches: MockIssue.self) {
      try await feature.filteredTagsList("filter")
    }
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

    patch(
      \ResourceTagsListFetchDatabaseOperation.execute,
      with: always(expectedResult)
    )

    let feature: ResourceTags = try await self.testedInstance()

    let result: Array<ResourceTagListItemDSV> = try await feature.filteredTagsList("filter")

    XCTAssertEqual(result, expectedResult)
  }
}
