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
import Foundation
import XCTest

@testable import PassboltDatabaseOperations

final internal class ResourceTagsListFetchDatabaseOperationTests: DatabaseOperationsTestCase {

  override internal func registerOperations() {
    register(
      { $0.usePassboltResourceTagsListFetchDatabaseOperation() },
      for: ResourceTagsListFetchDatabaseOperation.self
    )
  }

  override internal func commonPrepare() async throws {
    try await super.commonPrepare()

    try await self.storeUsers([currentUser])
    try await self.storeResourceTypes([testResourceType])
  }

  internal func test_whenSearchingWithEmptyText_thenAllTagsAreReturned() async throws {
    let resource: ResourceDTO = .create(resourceTypeId: testResourceType.id, name: "Tagged Resource") { resource in
      resource.tags = [
        .init(id: .mock_1, slug: .init(rawValue: "production"), shared: false),
        .init(id: .mock_2, slug: .init(rawValue: "staging"), shared: true),
      ]
    }
    try await self.storeResources([resource])

    let operation: ResourceTagsListFetchDatabaseOperation = try self.testedInstance()
    let results: Array<ResourceTagListItemDSV> = try await operation.execute(.init(text: ""))

    XCTAssertEqual(results.count, 2)
  }

  internal func test_whenSearchingByPrefix_thenMatchingTagIsReturned() async throws {
    let resource: ResourceDTO = .create(resourceTypeId: testResourceType.id, name: "Tagged Resource") { resource in
      resource.tags = [
        .init(id: .mock_1, slug: .init(rawValue: "production"), shared: false),
        .init(id: .mock_2, slug: .init(rawValue: "staging"), shared: true),
      ]
    }
    try await self.storeResources([resource])

    let operation: ResourceTagsListFetchDatabaseOperation = try self.testedInstance()
    let results: Array<ResourceTagListItemDSV> = try await operation.execute(.init(text: "prod"))

    XCTAssertEqual(results.count, 1)
    XCTAssertEqual(results[0].slug.rawValue, "production")
  }

  internal func test_whenSearchingSubstring_thenMatchingTagIsReturned() async throws {
    let resource: ResourceDTO = .create(resourceTypeId: testResourceType.id, name: "Tagged Resource") { resource in
      resource.tags = [
        .init(id: .mock_1, slug: .init(rawValue: "production"), shared: false),
        .init(id: .mock_2, slug: .init(rawValue: "staging"), shared: true),
      ]
    }
    try await self.storeResources([resource])

    let operation: ResourceTagsListFetchDatabaseOperation = try self.testedInstance()
    let results: Array<ResourceTagListItemDSV> = try await operation.execute(.init(text: "oduction"))

    XCTAssertEqual(results.count, 1)
    XCTAssertEqual(results[0].slug.rawValue, "production")
  }

  internal func test_whenSearchingCaseInsensitive_thenMatchingTagIsReturned() async throws {
    let resource: ResourceDTO = .create(resourceTypeId: testResourceType.id, name: "Tagged Resource") { resource in
      resource.tags = [
        .init(id: .mock_1, slug: .init(rawValue: "Production"), shared: false)
      ]
    }
    try await self.storeResources([resource])

    let operation: ResourceTagsListFetchDatabaseOperation = try self.testedInstance()
    let results: Array<ResourceTagListItemDSV> = try await operation.execute(.init(text: "production"))

    XCTAssertEqual(results.count, 1)
    XCTAssertEqual(results[0].slug.rawValue, "Production")
  }

  internal func test_whenSearchingDiacriticsInsensitive_thenMatchingTagIsReturned() async throws {
    let resource: ResourceDTO = .create(resourceTypeId: testResourceType.id, name: "Tagged Resource") { resource in
      resource.tags = [
        .init(id: .mock_1, slug: .init(rawValue: "café"), shared: false)
      ]
    }
    try await self.storeResources([resource])

    let operation: ResourceTagsListFetchDatabaseOperation = try self.testedInstance()
    let results: Array<ResourceTagListItemDSV> = try await operation.execute(.init(text: "cafe"))

    XCTAssertEqual(results.count, 1)
    XCTAssertEqual(results[0].slug.rawValue, "café")
  }

  internal func test_whenSearchingWithNoMatch_thenEmptyResultsReturned() async throws {
    let resource: ResourceDTO = .create(resourceTypeId: testResourceType.id, name: "Tagged Resource") { resource in
      resource.tags = [
        .init(id: .mock_1, slug: .init(rawValue: "production"), shared: false)
      ]
    }
    try await self.storeResources([resource])

    let operation: ResourceTagsListFetchDatabaseOperation = try self.testedInstance()
    let results: Array<ResourceTagListItemDSV> = try await operation.execute(.init(text: "nonexistent"))

    XCTAssertEqual(results.count, 0)
  }

  internal func test_whenSearchingWithSpecialCharacters_thenDoesNotCrash() async throws {
    let resource: ResourceDTO = .create(resourceTypeId: testResourceType.id, name: "Tagged Resource") { resource in
      resource.tags = [
        .init(id: .mock_1, slug: .init(rawValue: "production"), shared: false)
      ]
    }
    try await self.storeResources([resource])

    let operation: ResourceTagsListFetchDatabaseOperation = try self.testedInstance()
    let results: Array<ResourceTagListItemDSV> = try await operation.execute(.init(text: "\"test\" OR NOT"))

    XCTAssertEqual(results.count, 0)
  }
}
