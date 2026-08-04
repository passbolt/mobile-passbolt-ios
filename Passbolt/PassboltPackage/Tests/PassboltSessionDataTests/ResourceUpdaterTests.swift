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

import Commons
import CoreTest
import DatabaseOperations
import Metadata
import NetworkOperations
import TestExtensions

@testable import PassboltSessionData

// swift-format-ignore: AlwaysUseLowerCamelCase
final class ResourceUpdaterTests: FeaturesTestCase {

  override func commonPrepare() async throws {
    try await super.commonPrepare()
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
  }

  // MARK: Progress reporting
  func test_resourcesUpdate_reportsProgress_reachingFull() async throws {
    patch(
      \ResourceTypesFetchNetworkOperation.execute,
      with: always(.init())
    )
    patch(
      \ResourcesFetchNetworkOperation.execute,
      with: always(.empty())
    )

    let feature: ResourceUpdater = try self.testedInstance()
    let reported: CriticalState<Array<Double>> = .init(.init())
    try await feature.updateResources(.serial) { (fraction: Double) in
      reported.access { (values: inout Array<Double>) in
        values.append(fraction)
      }
    }

    let values: Array<Double> = reported.get()
    XCTAssertFalse(values.isEmpty, "onProgress should be reported at least once")
    // swift-format-ignore: NeverForceUnwrap
    XCTAssertEqual(values.last!, 1.0, accuracy: 0.0001, "Progress should reach 1.0 on completion")
    XCTAssertTrue(values.allSatisfy { (0.0 ... 1.0).contains($0) }, "Progress must stay within 0...1")
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
    try await feature.updateResources(.serial) { _ in }
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

    try await feature.updateResources(.serial) { _ in }

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

    try await feature.updateResources(.serial) { _ in }

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

    try await feature.updateResources(.concurrent) { _ in }

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

    try await feature.updateResources(.serial) { _ in }

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

    try await feature.updateResources(.concurrent) { _ in }

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

    try await feature.updateResources(.concurrent) { _ in }

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

    try await feature.updateResources(.concurrent) { _ in }

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
      with: { input async throws in
        XCTAssertEqual(input.changed.count, 1, "Only supported resource types should be saved.")
        XCTAssertEqual(input.changed.first?.typeID, supportedType.id)
        expectation.fulfill()
      }
    )

    let feature: ResourceUpdater = try self.testedInstance()

    try await feature.updateResources(.concurrent) { _ in }

    await fulfillment(of: [expectation], timeout: 1)
  }

  func test_resourceUpdate_ignoresResourcesWithoutName() async throws {
    // Temporary test to ensure name is required - for transition period to v5 resource types
    let supportedType = ResourceType.mock_default
    let resource: CriticalState<ResourceDTO> = .init(mockResource(withType: supportedType))
    resource.set(\.name, nil)
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
      with: always([resource.get(), secondResource].asPaginatedResponse)
    )
    patch(
      \ResourcesStoreDatabaseOperation.execute,
      with: { input async throws in
        XCTAssertEqual(input.changed.count, 1, "Resources without name should be ignored.")
        expectation.fulfill()
      }
    )

    let feature: ResourceUpdater = try self.testedInstance()

    try await feature.updateResources(.concurrent) { _ in }

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
    try await feature.updateResources(.serial) { _ in }

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
      with: { input async throws in
        XCTAssertEqual(input.changed.count, 1, "Resource should be saved after metadata decryption.")
        XCTAssertEqual(input.changed.first?.id, resource.id, "Saved resource should match the original one.")
        XCTAssertNotNil(input.changed.first?.metadata)
        expectation.fulfill()
      }
    )

    let feature: ResourceUpdater = try self.testedInstance()
    try await feature.updateResources(.serial) { _ in }
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
      with: { input async throws in
        XCTAssertEqual(input.changed.count, 1, "Resource should be saved after metadata decryption.")
        XCTAssertEqual(input.changed.first?.id, resource.id, "Saved resource should match the original one.")
        resourceStored.fulfill()
      }
    )
    let feature: ResourceUpdater = try self.testedInstance()
    try await feature.updateResources(.serial) { _ in }
    await fulfillment(of: [resourceStored], timeout: 1.0)
  }

  // MARK: Single resource update

  func test_updateResource_storesValidatedResource() async throws {
    patch(
      \ResourceTypesFetchDatabaseOperation.execute,
      with: always([.mock_default])
    )
    let storeExpectation: XCTestExpectation = .init(description: "Resource should be stored.")
    patch(
      \ResourcesStoreDatabaseOperation.execute,
      with: { input async throws in
        XCTAssertEqual(input.changed.count, 1, "Exactly one resource should be stored.")
        XCTAssertEqual(input.changed.first?.id, .mock_1)
        storeExpectation.fulfill()
      }
    )
    let fetchShouldNotBeCalled: XCTestExpectation = .init(description: "Paginated fetch should not be called.")
    fetchShouldNotBeCalled.isInverted = true
    patch(
      \ResourcesFetchNetworkOperation.execute,
      with: { _ in
        fetchShouldNotBeCalled.fulfill()
        return .empty()
      }
    )

    let feature: ResourceUpdater = try self.testedInstance()
    try await feature.updateResource(mockResource(withType: .mock_default))

    await fulfillment(of: [storeExpectation, fetchShouldNotBeCalled], timeout: 1.0)
  }

  func test_updateResource_throwsWhenResourceTypeUnsupported() async throws {
    patch(
      \ResourceTypesFetchDatabaseOperation.execute,
      with: always([])
    )

    let feature: ResourceUpdater = try self.testedInstance()
    do {
      try await feature.updateResource(mockResource(withType: .placeholder))
      XCTFail("Expected updateResource to throw for unsupported resource type.")
    }
    catch {
      // expected
    }
  }

  func test_updateResource_throwsWhenSharedKeyMissing() async throws {
    self.set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_1.with(metadataEnabled: true)
      )
    )
    patch(
      \ResourceTypesFetchDatabaseOperation.execute,
      with: always([.mock_default])
    )
    patch(
      \MetadataKeysService.hasAccessToSharedKey,
      with: always(false)
    )
    patch(
      \ResourcesStoreDatabaseOperation.execute,
      with: { _ in
        XCTFail("Resource with unknown shared key should not be stored.")
      }
    )

    let resource: ResourceDTO = mockResource(
      withType: .mock_default,
      metadataArmoredMessage: "armored_message",
      metadataKeyId: .init(),
      metadataKeyType: .shared
    )

    let feature: ResourceUpdater = try self.testedInstance()
    do {
      try await feature.updateResource(resource)
      XCTFail("Expected updateResource to throw when shared key is unavailable.")
    }
    catch {
      // expected
    }
  }

  func test_resourceUpdate_whenIncomingResourceIsOlder_shouldReconcileInsteadOfDecrypting() async throws {
    let referenceDate: Date = .now
    // The unchanged resource must be reconciled through the store's `unchanged` set (access / folder /
    // favorite can change without bumping `modified`) — never decrypted into the `changed` set.
    let resourceReconciled: XCTestExpectation = .init(description: "Unchanged resource should be reconciled.")
    // Only the refresh-level state updates remain: initial `waitingForUpdate` and the final reset. The
    // per-resource state clear is now applied inside the store, not via a separate operation.
    let resourceStateShouldUpdate: XCTestExpectation = .init(description: "Resource state should be updated.")
    resourceStateShouldUpdate.expectedFulfillmentCount = 2

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
        // Both remaining calls operate on the whole table (no per-resource filter).
        XCTAssertNil(input.filter, "Per-resource state clear is now handled inside the store.")
        resourceStateShouldUpdate.fulfill()
      }
    )
    patch(
      \ResourcesStoreDatabaseOperation.execute,
      with: { input async throws in
        XCTAssertEqual(input.changed.count, 0, "Unchanged resource must not be decrypted / re-stored.")
        XCTAssertEqual(input.unchanged.count, 1, "Unchanged resource must be reconciled.")
        XCTAssertEqual(input.unchanged.first?.id, resource.id)
        resourceReconciled.fulfill()
      }
    )
    let feature: ResourceUpdater = try self.testedInstance()
    try await feature.updateResources(.serial) { _ in }
    await fulfillment(of: [resourceReconciled, resourceStateShouldUpdate], timeout: 1.0)
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
