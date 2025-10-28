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

import CoreTest
import DatabaseOperations
import Metadata
import NetworkOperations
import TestExtensions

@testable import PassboltSessionData

// swift-format-ignore: AlwaysUseLowerCamelCase
final class ResourceUpdaterTests: FeaturesTestCase {

  override func commonPrepare() {
    super.commonPrepare()
    register(
      { $0.usePassboltResourceUpdater() },
      for: ResourceUpdater.self
    )
    set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_default
      )
    )
    patch(
      \ResourceTypesStoreDatabaseOperation.execute,
      with: always(())
    )
    patch(
      \ResourcesStoreDatabaseOperation.execute,
      with: always(())
    )
    patch(
      \ResourceTagsRemoveUnusedDatabaseOperation.execute,
      with: always(())
    )
    patch(
      \ResourceRemoveWithStateDatabaseOperation.execute,
      with: always(())
    )
    patch(
      \MetadataKeysService.cleanupDecryptionCache,
      with: always(())
    )
    patch(
      \MetadataKeysService.decrypt,
      with: always(nil)
    )
    patch(
      \ResourceUpdateStateDatabaseOperation.execute,
      with: always(())
    )
    patch(
      \ResourcesFetchModificationDateDatabaseOperation.execute,
      with: always(.init())
    )
    patch(
      \ResourceSetFavoriteDatabaseOperation.execute,
      with: always(())
    )
    patch(
      \ResourceUpdateFolderDatabaseOperation.execute,
      with: always(())
    )
  }

  // MARK: Preparation & update logic
  func test_resourceUpdate_shouldFetchCurrentResourceTypes() async throws {
    let fetchExpectation: XCTestExpectation = .init(description: "Resource types fetch must be called.")
    patch(
      \ResourceTypesFetchNetworkOperation.execute,
      with: { _ in
        fetchExpectation.fulfill()
        return .init()
      }
    )

    patch(
      \ResourcesFetchNetworkOperation.execute,
      with: always(.empty())
    )

    let feature: ResourceUpdater = try self.testedInstance()
    try await feature.updateResources(.serial)
    await fulfillment(of: [fetchExpectation], timeout: 1.0)
  }

  func test_resourcesUpdate_shouldPrepareExistingResourcesForUpdate() async throws {
    patch(
      \ResourceTypesFetchNetworkOperation.execute,
      with: always(.init())
    )
    let updateExpectation: XCTestExpectation = .init(description: "Resource state update must be called.")
    updateExpectation.expectedFulfillmentCount = 2
    patch(
      \ResourceUpdateStateDatabaseOperation.execute,
      with: { input in
        if input.state == .waitingForUpdate {
          updateExpectation.fulfill()
        }
        else if input.state == .none {
          updateExpectation.fulfill()
        }
      }
    )
    patch(
      \ResourcesFetchNetworkOperation.execute,
      with: always(.empty())
    )

    let feature: ResourceUpdater = try self.testedInstance()

    try await feature.updateResources(.serial)

    await fulfillment(of: [updateExpectation], timeout: 1.0)
  }

  func test_resourcesUpdate_shouldFetchFirstChunkOfResourcesToUpdateInSerialMode() async throws {
    patch(
      \ResourceTypesFetchNetworkOperation.execute,
      with: always(.init())
    )

    let fetchExpectation: XCTestExpectation = .init(description: "Resource fetch must be called.")
    patch(
      \ResourcesFetchNetworkOperation.execute,
      with: { _ in
        fetchExpectation.fulfill()
        return .init(
          items: [.mock_1],
          pagination: .init(page: 1, limit: 1, count: 1)
        )
      }
    )
    let feature: ResourceUpdater = try self.testedInstance()

    try await feature.updateResources(.serial)

    await fulfillment(of: [fetchExpectation], timeout: 1.0)
  }

  func test_resourcesUpdate_shouldFetchFirstChunkOfResourcesToUpdateInConcurrentMode() async throws {
    patch(
      \ResourceTypesFetchNetworkOperation.execute,
      with: always(.init())
    )

    let fetchExpectation: XCTestExpectation = .init(description: "Resource fetch must be called.")
    patch(
      \ResourcesFetchNetworkOperation.execute,
      with: { _ in
        fetchExpectation.fulfill()
        return .init(
          items: [.mock_1],
          pagination: .init(page: 1, limit: 1, count: 1)
        )
      }
    )
    let feature: ResourceUpdater = try self.testedInstance()

    try await feature.updateResources(.concurrent)

    await fulfillment(of: [fetchExpectation], timeout: 1.0)
  }

  func test_resourceUpdate_shouldFetchNextChunkIfNotEmptyInSerialMode() async throws {
    patch(
      \ResourceTypesFetchNetworkOperation.execute,
      with: always(.init())
    )
    let fetchExpectation: XCTestExpectation = .init(description: "Resource fetch must be called.")
    fetchExpectation.expectedFulfillmentCount = 3

    patch(
      \ResourcesFetchNetworkOperation.execute,
      with: { _ in
        fetchExpectation.fulfill()
        return .init(
          items: [.mock_1],
          pagination: .init(page: 1, limit: 1, count: 3)
        )
      }
    )

    let feature: ResourceUpdater = try self.testedInstance()

    try await feature.updateResources(.serial)

    await fulfillment(of: [fetchExpectation], timeout: 1.0)
  }

  func test_resourceUpdate_shouldFetchNextChunkIfNotEmptyInConcurrentMode() async throws {
    patch(
      \ResourceTypesFetchNetworkOperation.execute,
      with: always(.init())
    )
    let fetchExpectation: XCTestExpectation = .init(description: "Resource fetch must be called.")
    fetchExpectation.expectedFulfillmentCount = 3

    patch(
      \ResourcesFetchNetworkOperation.execute,
      with: { _ in
        fetchExpectation.fulfill()
        return .init(
          items: [.mock_1],
          pagination: .init(page: 1, limit: 1, count: 3)
        )
      }
    )

    let feature: ResourceUpdater = try self.testedInstance()

    try await feature.updateResources(.concurrent)

    await fulfillment(of: [fetchExpectation], timeout: 1.0)
  }

  // MARK: Resource processing
  func test_resourceUpdate_handlesKnownResourceTypes() async throws {
    patch(
      \ResourcesFetchNetworkOperation.execute,
      with: always(.empty())
    )
    patch(
      \ResourcesStoreDatabaseOperation.execute,
      with: always(Void())
    )

    let expectedTypes: [ResourceTypeDTO] = [
      .mock_totp,
      .mock_default,
    ]
    patch(
      \ResourceTypesFetchNetworkOperation.execute,
      with: always(expectedTypes)
    )

    let expectation: XCTestExpectation = .init(description: "Known resource types should be saved.")
    patch(
      \ResourceTypesStoreDatabaseOperation.execute,
      with: { types async throws in
        XCTAssertEqual(types, expectedTypes, "All known resource types should be saved.")
        expectation.fulfill()
      }
    )

    let feature: ResourceUpdater = try self.testedInstance()

    try await feature.updateResources(.concurrent)

    await fulfillment(of: [expectation], timeout: 1.0)
  }

  func test_resourceUpdate_handlesUnknownResourceTypes() async throws {
    patch(
      \ResourcesFetchNetworkOperation.execute,
      with: always(.empty())
    )
    patch(
      \ResourcesStoreDatabaseOperation.execute,
      with: always(Void())
    )

    let returnedTypes: [ResourceTypeDTO] = [
      .mock_default,
      .placeholder,
    ]
    let expectedTypes: [ResourceTypeDTO] = [.mock_default]

    patch(
      \ResourceTypesFetchNetworkOperation.execute,
      with: always(returnedTypes)
    )

    let expectation: XCTestExpectation = .init(description: "Known resource types should be saved.")
    patch(
      \ResourceTypesStoreDatabaseOperation.execute,
      with: { types async throws in
        XCTAssertEqual(types, expectedTypes, "Only known resource types should be saved.")
        expectation.fulfill()
      }
    )

    let feature: ResourceUpdater = try self.testedInstance()

    try await feature.updateResources(.concurrent)

    await fulfillment(of: [expectation], timeout: 1.0)
  }

  func test_resourceUpdate_ignoresUnknownResourceTypes() async throws {
    let supportedType = ResourceType.mock_default
    patch(
      \ResourceTypesFetchNetworkOperation.execute,
      with: always([supportedType, .placeholder])
    )

    patch(
      \ResourceTypesStoreDatabaseOperation.execute,
      with: always(Void())
    )

    let expectation: XCTestExpectation = .init(description: "Known resource types should be saved.")
    patch(
      \ResourcesFetchNetworkOperation.execute,
      with: always([mockResource(withType: supportedType), mockResource(withType: .placeholder)].asPaginatedResponse)
    )
    patch(
      \ResourcesStoreDatabaseOperation.execute,
      with: { resourceDTOs async throws in
        XCTAssertEqual(resourceDTOs.count, 1, "Only supported resource types should be saved.")
        XCTAssertEqual(resourceDTOs.first?.typeID, supportedType.id)
        expectation.fulfill()
      }
    )

    let feature: ResourceUpdater = try self.testedInstance()

    try await feature.updateResources(.concurrent)

    await fulfillment(of: [expectation], timeout: 1)
  }

  func test_resourceUpdate_ignoresResourcesWithoutName() async throws {
    // Temporary test to ensure name is required - for transition period to v5 resource types
    let supportedType = ResourceType.mock_default
    var resource = mockResource(withType: supportedType)
    resource.name = nil
    let secondResource = mockResource(withType: supportedType)

    patch(
      \ResourceTypesFetchNetworkOperation.execute,
      with: always([supportedType])
    )

    patch(
      \ResourceTypesStoreDatabaseOperation.execute,
      with: always(Void())
    )

    let expectation: XCTestExpectation = .init(description: "Save should be triggered.")
    patch(
      \ResourcesFetchNetworkOperation.execute,
      with: always([resource, secondResource].asPaginatedResponse)
    )
    patch(
      \ResourcesStoreDatabaseOperation.execute,
      with: { resourceDTOs async throws in
        XCTAssertEqual(resourceDTOs.count, 1, "Resources without name should be ignored.")
        expectation.fulfill()
      }
    )

    let feature: ResourceUpdater = try self.testedInstance()

    try await feature.updateResources(.concurrent)

    await fulfillment(of: [expectation], timeout: 1)
  }

  func test_resourceUpdate_ignoresResourcesWithUnknownSharedKey() async throws {
    self.set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_1.with(metadataEnabled: true)
      )
    )
    let verifyIfKeyExists: XCTestExpectation = .init(description: "Key existence should be verified.")
    let resource: ResourceDTO = mockResource(
      withType: .mock_default,
      metadataArmoredMessage: "armored_message",
      metadataKeyId: .init(),
      metadataKeyType: .shared
    )
    patch(
      \ResourceTypesFetchNetworkOperation.execute,
      with: always([.mock_default])
    )
    patch(
      \ResourcesFetchNetworkOperation.execute,
      with: always([resource].asPaginatedResponse)
    )

    patch(
      \MetadataKeysService.hasAccessToSharedKey,
      with: { keyId in
        XCTAssertEqual(keyId, resource.metadataKeyId, "Key ID should be verified.")
        verifyIfKeyExists.fulfill()
        return false
      }
    )
    patch(
      \ResourcesStoreDatabaseOperation.execute,
      with: { _ in
        XCTFail("Resource with unknown shared key should be ignored.")
      }
    )

    let feature: ResourceUpdater = try self.testedInstance()
    try await feature.updateResources(.serial)

    await fulfillment(of: [verifyIfKeyExists], timeout: 1.0)
  }

  // MARK: Metadata decryption

  func test_resourceUpdate_shouldDecodeMetadataIfEnabled() async throws {
    self.set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_1.with(metadataEnabled: true)
      )
    )
    let resource: ResourceDTO = mockResource(
      withType: .mock_default,
      metadataArmoredMessage: "armored_message",
      metadataKeyId: .init(),
      metadataKeyType: .user
    )
    patch(
      \ResourceTypesFetchNetworkOperation.execute,
      with: always([.mock_default])
    )
    patch(
      \ResourcesFetchNetworkOperation.execute,
      with: always([resource].asPaginatedResponse)
    )
    let expectation: XCTestExpectation = .init(description: "Metadata decryption should be called.")
    patch(
      \MetadataKeysService.decrypt,
      with: { _, _, _ in
        expectation.fulfill()
        return metadataDataMock()
      }
    )

    patch(
      \ResourcesStoreDatabaseOperation.execute,
      with: { resources async throws in
        XCTAssertEqual(resources.count, 1, "Resource should be saved after metadata decryption.")
        XCTAssertEqual(resources.first?.id, resource.id, "Saved resource should match the original one.")
        XCTAssertNotNil(resources.first?.metadata)
        expectation.fulfill()
      }
    )

    let feature: ResourceUpdater = try self.testedInstance()
    try await feature.updateResources(.serial)
    await fulfillment(of: [expectation], timeout: 1.0)
  }

  // MARK: Utilizing `modified` field

  func test_resourceUpdate_whenIncomingResourceIsModified_shouldUpdateIt() async throws {
    let referenceDate: Date = .now
    let resourceStored: XCTestExpectation = .init(description: "Resource should be stored.")
    self.set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_1.with(metadataEnabled: true)
      )
    )
    let resource: ResourceDTO = mockResource(
      withType: .mock_default,
      metadataArmoredMessage: "armored_message",
      metadataKeyId: .init(),
      metadataKeyType: .user,
      modified: .now.addingTimeInterval(100)
    )
    patch(
      \ResourcesFetchModificationDateDatabaseOperation.execute,
      with: always([.init(resourceId: resource.id, modificationDate: referenceDate)])
    )
    patch(
      \ResourceTypesFetchNetworkOperation.execute,
      with: always([.mock_default])
    )
    patch(
      \ResourcesFetchNetworkOperation.execute,
      with: always([resource].asPaginatedResponse)
    )
    patch(
      \ResourcesStoreDatabaseOperation.execute,
      with: { resources async throws in
        XCTAssertEqual(resources.count, 1, "Resource should be saved after metadata decryption.")
        XCTAssertEqual(resources.first?.id, resource.id, "Saved resource should match the original one.")
        resourceStored.fulfill()
      }
    )
    let feature: ResourceUpdater = try self.testedInstance()
    try await feature.updateResources(.serial)
    await fulfillment(of: [resourceStored], timeout: 1.0)
  }

  func test_resourceUpdate_whenIncomingResourceIsOlder_shouldNotUpdateIt() async throws {
    let referenceDate: Date = .now
    let resourceStored: XCTestExpectation = .init(description: "Resource should not be stored.")
    resourceStored.isInverted = true
    let resourceStateShouldUpdate: XCTestExpectation = .init(description: "Resource state should be updated.")
    resourceStateShouldUpdate.expectedFulfillmentCount = 3
    let resourcePermissionsStored: XCTestExpectation = .init(description: "Resource permissions should be stored.")

    self.set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_1.with(metadataEnabled: true)
      )
    )
    let resource: ResourceDTO = mockResource(
      withType: .mock_default,
      metadataArmoredMessage: "armored_message",
      metadataKeyId: .init(),
      metadataKeyType: .user,
      modified: .now.addingTimeInterval(-100)
    )
    patch(
      \ResourcesFetchModificationDateDatabaseOperation.execute,
      with: always([.init(resourceId: resource.id, modificationDate: referenceDate)])
    )
    patch(
      \ResourceTypesFetchNetworkOperation.execute,
      with: always([.mock_default])
    )
    patch(
      \ResourcesFetchNetworkOperation.execute,
      with: always([resource].asPaginatedResponse)
    )
    patch(
      \ResourceUpdateStateDatabaseOperation.execute,
      with: { input in
        if input.state == .waitingForUpdate {
          XCTAssertNil(input.filter)  // Initial state update
          resourceStateShouldUpdate.fulfill()
        }
        else {
          XCTAssertNil(input.state)
          if input.filter == nil {
            // State reset after processing
            resourceStateShouldUpdate.fulfill()
          }
          else {
            XCTAssertEqual(input.filter?.first, resource.id)
            resourceStateShouldUpdate.fulfill()
          }
        }
      }
    )
    patch(
      \ResourcesStoreDatabaseOperation.execute,
      with: { resources async throws in
        XCTAssertEqual(resources.count, 0, "Resource should be saved after metadata decryption.")
        resourceStored.fulfill()
      }
    )
    patch(
      \ResourceStorePermissionsDatabaseOperation.execute,
      with: { _ in
        resourcePermissionsStored.fulfill()
      }
    )
    let feature: ResourceUpdater = try self.testedInstance()
    try await feature.updateResources(.serial)
    await fulfillment(of: [resourceStored, resourceStateShouldUpdate, resourcePermissionsStored], timeout: 1.0)
  }
}

extension ResourceUpdater.Configuration {

  fileprivate static var serial: Self {
    .init(
      maximumChunkSize: 1,
      maximumConcurrentTasks: 1
    )
  }

  fileprivate static var concurrent: Self {
    .init(
      maximumChunkSize: 1,
      maximumConcurrentTasks: 2
    )
  }
}

// swift-format-ignore: AlwaysUseLowerCamelCase
extension ResourceDTO {

  static var mock_1: Self {
    .init(
      id: .mock_1,
      typeID: .mock_1,
      parentFolderID: .none,
      favoriteID: .none,
      name: "Test Resource",
      permission: .owner,
      permissions: .init(),
      uri: .none,
      username: .none,
      description: .none,
      tags: .init(),
      modified: .now,
      expired: .none
    )
  }
}

private func mockResource(
  withType type: ResourceType,
  metadataArmoredMessage: String? = nil,
  metadataKeyId: MetadataKeyDTO.ID? = nil,
  metadataKeyType: MetadataKeyDTO.MetadataKeyType? = nil,
  modified: Date = .init()
) -> ResourceDTO {
  .init(
    id: .mock_1,
    typeID: type.id,
    parentFolderID: nil,
    favoriteID: nil,
    name: "Mock name",
    permission: .owner,
    permissions: [],
    uri: nil,
    username: nil,
    description: nil,
    tags: [],
    modified: modified,
    expired: nil,
    metadataArmoredMessage: metadataArmoredMessage,
    metadataKeyId: metadataKeyId,
    metadataKeyType: metadataKeyType
  )
}

// swift-format-ignore: NeverUseForceTry
private func metadataDataMock() -> Data {
  var metadataJSON: JSON = ResourceMetadataDTO.initialResourceMetadataJSON(for: Resource.mock_1)
  metadataJSON[keyPath: \.name] = .string(Resource.mock_1.name)
  metadataJSON[keyPath: \.resource_type_id] = .string(ResourceTypeDTO.mock_default.id.rawValue.rawValue.uuidString)
  return try! JSONEncoder().encode(metadataJSON)
}
