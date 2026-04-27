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

final internal class ResourcesListFetchDatabaseOperationTests: DatabaseOperationsTestCase {

  override internal func registerOperations() {
    register(
      { $0.usePassboltResourcesListFetchDatabaseOperation() },
      for: ResourcesListFetchDatabaseOperation.self
    )
  }

  override internal func commonPrepare() async throws {
    try await super.commonPrepare()

    try await self.storeUsers([currentUser])
    try await self.storeResourceTypes([testResourceType])
  }

  internal func test_whenSearching_for_resources_thenResourcesAreReturned() async throws {
    let resource: ResourceDTO = .create(resourceTypeId: testResourceType.id, name: "Test resource")
    let otherResource: ResourceDTO = .create(resourceTypeId: testResourceType.id, name: "Other resource")
    try await self.storeResources([resource, otherResource])

    let operation: ResourcesListFetchDatabaseOperation = try self.testedInstance()
    var results: Array<ResourceListItemDSV> = try await operation.execute(
      .init(
        sorting: .nameAlphabetically
      )
    )

    XCTAssertEqual(results.count, 2)
    XCTAssertEqual(results[0].id, otherResource.id)
    XCTAssertEqual(results[0].name, otherResource.name)
    XCTAssertEqual(results[1].id, resource.id)
    XCTAssertEqual(results[1].name, resource.name)

    results = try await operation.execute(
      .init(
        sorting: .nameAlphabetically,
        text: "test"
      )
    )

    XCTAssertEqual(results.count, 1)
    XCTAssertEqual(results[0].id, resource.id)
    XCTAssertEqual(results[0].name, resource.name)
  }

  internal func test_whenSearchingCaseInsensitive_withUTF8Characters_thenResourcesAreReturned() async throws {
    let resource: ResourceDTO = .create(resourceTypeId: testResourceType.id, name: "Ügyfélkapu")
    try await self.storeResources([resource])

    let operation: ResourcesListFetchDatabaseOperation = try self.testedInstance()
    let results: Array<ResourceListItemDSV> = try await operation.execute(
      .init(
        sorting: .nameAlphabetically,
        text: "ügyfél"
      )
    )

    XCTAssertEqual(results.count, 1)
    XCTAssertEqual(results[0].id, resource.id)
    XCTAssertEqual(results[0].name, resource.name)
  }

  internal func test_whenSearchingByURI_thenResourceIsFound() async throws {
    let resource: ResourceDTO = .create(resourceTypeId: testResourceType.id, name: "My Website") { resource in
      resource.uri = "https://example.com/login"
    }
    let otherResource: ResourceDTO = .create(resourceTypeId: testResourceType.id, name: "Other Site") { resource in
      resource.uri = "https://other.org"
    }
    try await self.storeResources([resource, otherResource])

    let operation: ResourcesListFetchDatabaseOperation = try self.testedInstance()
    let results: Array<ResourceListItemDSV> = try await operation.execute(
      .init(
        sorting: .nameAlphabetically,
        text: "example"
      )
    )

    XCTAssertEqual(results.count, 1)
    XCTAssertEqual(results[0].id, resource.id)
  }

  internal func test_whenSearchingByUsername_thenResourceIsFound() async throws {
    let resource: ResourceDTO = .create(resourceTypeId: testResourceType.id, name: "Email Account") { resource in
      resource.username = "john.doe@example.com"
    }
    let otherResource: ResourceDTO = .create(resourceTypeId: testResourceType.id, name: "Other Account") { resource in
      resource.username = "admin@other.org"
    }
    try await self.storeResources([resource, otherResource])

    let operation: ResourcesListFetchDatabaseOperation = try self.testedInstance()
    let results: Array<ResourceListItemDSV> = try await operation.execute(
      .init(
        sorting: .nameAlphabetically,
        text: "john.doe"
      )
    )

    XCTAssertEqual(results.count, 1)
    XCTAssertEqual(results[0].id, resource.id)
  }

  internal func test_whenSearchingByTag_thenResourceIsFound() async throws {
    let resource: ResourceDTO = .create(resourceTypeId: testResourceType.id, name: "Tagged Resource") { resource in
      resource.tags = [
        .init(id: .mock_1, slug: .init(rawValue: "production"), shared: false)
      ]
    }
    let otherResource: ResourceDTO = .create(resourceTypeId: testResourceType.id, name: "Untagged Resource")
    try await self.storeResources([resource, otherResource])

    let operation: ResourcesListFetchDatabaseOperation = try self.testedInstance()
    let results: Array<ResourceListItemDSV> = try await operation.execute(
      .init(
        sorting: .nameAlphabetically,
        text: "production"
      )
    )

    XCTAssertEqual(results.count, 1)
    XCTAssertEqual(results[0].id, resource.id)
  }

  internal func test_whenSearchingByCustomFieldKey_thenResourceIsFound() async throws {
    let customFieldID: UUID = .init()
    let jsonString: String = """
      {
        "object_type": "PASSBOLT_RESOURCE_METADATA",
        "name": "Custom Field Resource",
        "uris": [],
        "custom_fields": [
          {
            "id": "\(customFieldID.uuidString)",
            "type": "text",
            "metadata_key": "api-token",
            "metadata_value": "secret123"
          }
        ]
      }
      """
    let jsonData: Data = jsonString.data(using: .utf8)!
    let resourceID: Resource.ID = .init()

    var resource: ResourceDTO = .init(
      id: resourceID,
      typeID: testResourceType.id,
      parentFolderID: .none,
      favoriteID: .none,
      name: "Custom Field Resource",
      permission: .owner,
      permissions: .init(),
      uri: .none,
      username: .none,
      description: .none,
      tags: .init(),
      modified: .now,
      expired: .none
    )
    resource.metadata = try ResourceMetadataDTO(resourceId: resourceID, data: jsonData)

    let otherResource: ResourceDTO = .create(resourceTypeId: testResourceType.id, name: "Other Resource")
    try await self.storeResources([resource, otherResource])

    let operation: ResourcesListFetchDatabaseOperation = try self.testedInstance()
    let results: Array<ResourceListItemDSV> = try await operation.execute(
      .init(
        sorting: .nameAlphabetically,
        text: "api-token"
      )
    )

    XCTAssertEqual(results.count, 1)
    XCTAssertEqual(results[0].id, resource.id)
  }

  internal func test_whenSearchingDiacriticsInsensitive_thenResourceIsFound() async throws {
    let resource: ResourceDTO = .create(resourceTypeId: testResourceType.id, name: "Café Express")
    try await self.storeResources([resource])

    let operation: ResourcesListFetchDatabaseOperation = try self.testedInstance()
    let results: Array<ResourceListItemDSV> = try await operation.execute(
      .init(
        sorting: .nameAlphabetically,
        text: "cafe"
      )
    )

    XCTAssertEqual(results.count, 1)
    XCTAssertEqual(results[0].id, resource.id)
  }

  internal func test_whenSearchingSubstring_thenResourceIsFound() async throws {
    let resource: ResourceDTO = .create(resourceTypeId: testResourceType.id, name: "MyPassword123")
    try await self.storeResources([resource])

    let operation: ResourcesListFetchDatabaseOperation = try self.testedInstance()
    let results: Array<ResourceListItemDSV> = try await operation.execute(
      .init(
        sorting: .nameAlphabetically,
        text: "assword"
      )
    )

    XCTAssertEqual(results.count, 1)
    XCTAssertEqual(results[0].id, resource.id)
  }

  internal func test_whenSearchingWithNoMatch_thenEmptyResultsReturned() async throws {
    let resource: ResourceDTO = .create(resourceTypeId: testResourceType.id, name: "Alpha Resource")
    try await self.storeResources([resource])

    let operation: ResourcesListFetchDatabaseOperation = try self.testedInstance()
    let results: Array<ResourceListItemDSV> = try await operation.execute(
      .init(
        sorting: .nameAlphabetically,
        text: "beta"
      )
    )

    XCTAssertEqual(results.count, 0)
  }

  internal func test_whenSearchingWithSpecialCharacters_thenDoesNotCrash() async throws {
    let resource: ResourceDTO = .create(resourceTypeId: testResourceType.id, name: "Test Resource")
    try await self.storeResources([resource])

    let operation: ResourcesListFetchDatabaseOperation = try self.testedInstance()
    let results: Array<ResourceListItemDSV> = try await operation.execute(
      .init(
        sorting: .nameAlphabetically,
        text: "\"test\" OR NOT"
      )
    )

    // Should not crash — the sanitized query may or may not match, but must not throw
    XCTAssertEqual(results.count, 0)
  }
}
