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

import Metadata
import TestExtensions

@testable import PassboltNetworkOperations

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class ResourceNetworkOperationDispatchTests: FeaturesTestCase {

  override func commonPrepare() {
    super.commonPrepare()
    register(
      { $0.usePassboltResourceNetworkOperationDispatch() },
      for: ResourceNetworkOperationDispatch.self
    )
    set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_default
      )
    )
    patch(
      \MetadataKeysService.determineKeyType,
      with: always(.userKey)
    )
  }

  func test_givenV4ResourceType_whenCallingCreateResource_shouldExecuteV4ResourceNetworkOperation() async throws {
    let expectation = self.expectation(description: "Should call v4 network operation")
    patch(
      \ResourceCreateNetworkOperationV4.execute,
      with: { _ in
        expectation.fulfill()
        return .init(
          resourceID: .mock_1,
          ownerPermissionID: .mock_1
        )
      }
    )

    let sut: ResourceNetworkOperationDispatch = try self.testedInstance()
    _ = try await sut.createResource(
      .init(
        type: .init(id: .mock_1, slug: .password)
      ),
      .init([.mock_1]),
      false
    )

    await fulfillment(of: [expectation], timeout: 1)
  }

  func test_givenV5ResourceType_whenCallingCreateResource_shouldExecuteV5ResourceNetworkOperation() async throws {
    let expectation = self.expectation(description: "Should call v5 network operation")
    patch(
      \ResourceCreateNetworkOperation.execute,
      with: { _ in
        expectation.fulfill()
        return .init(
          resourceID: .mock_1,
          ownerPermissionID: .mock_1
        )
      }
    )
    patch(
      \MetadataKeysService.encrypt,
      with: { input, _ in .init(input) }
    )
    patch(
      \MetadataKeysService.determineKeyType,
      with: always(.userKey)
    )

    let sut: ResourceNetworkOperationDispatch = try self.testedInstance()
    _ = try await sut.createResource(
      .init(
        type: .init(id: .mock_1, slug: .v5Default)
      ),
      .init([.mock_1]),
      false
    )

    await fulfillment(of: [expectation], timeout: 1)
  }

  func test_givenV5ResourceType_whenEncryptionFails_shouldThrowException() async throws {
    patch(
      \MetadataKeysService.encrypt,
      with: { _, _ in nil }
    )

    patch(
      \MetadataKeysService.determineKeyType,
      with: always(.userKey)
    )

    let sut: ResourceNetworkOperationDispatch = try self.testedInstance()
    await verifyIf(
      try await sut.createResource(
        .init(
          type: .init(id: .mock_1, slug: .v5Default)
        ),
        .init([.mock_1]),
        false
      ),
      throws: MetadataEncryptionFailure.self,
      "Should throw MetadataEncryptionFailure"
    )
  }

  func test_givenV4ResourceType_whenCallingEditResource_shouldExecuteV4ResourceNetworkOperation() async throws {
    let expectation = self.expectation(description: "Should call v4 network operation")
    patch(
      \ResourceEditNetworkOperationV4.execute,
      with: { _ in
        expectation.fulfill()
        return .init(
          resourceID: .mock_1
        )
      }
    )

    let sut: ResourceNetworkOperationDispatch = try self.testedInstance()
    _ = try await sut.editResource(
      .init(
        type: .init(id: .mock_1, slug: .password)
      ),
      .mock_1,
      .init([.mock_1])
    )

    await fulfillment(of: [expectation], timeout: 1)
  }

  func test_givenV5ResourceType_whenCallingEditResource_shouldExecuteV5ResourceNetworkOperation() async throws {
    let expectation = self.expectation(description: "Should call v5 network operation")
    patch(
      \ResourceEditNetworkOperation.execute,
      with: { _ in
        expectation.fulfill()
        return .init(
          resourceID: .mock_1
        )
      }
    )
    patch(
      \MetadataKeysService.encrypt,
      with: { input, _ in .init(input) }
    )

    let sut: ResourceNetworkOperationDispatch = try self.testedInstance()
    _ = try await sut.editResource(
      .init(
        type: .init(id: .mock_1, slug: .v5Default),
        metadataKeyId: .init(),
        metadataKeyType: .user
      ),
      .mock_1,
      .init([.mock_1])
    )

    await fulfillment(of: [expectation], timeout: 1)
  }

  func test_givenV5ResourceType_whenEncryptionFailsDuringEdit_shouldThrowException() async throws {
    patch(
      \MetadataKeysService.encrypt,
      with: { _, _ in nil }
    )

    let sut: ResourceNetworkOperationDispatch = try self.testedInstance()
    await verifyIf(
      try await sut.editResource(
        .init(
          type: .init(id: .mock_1, slug: .v5Default),
          metadataKeyId: .init(),
          metadataKeyType: .user
        ),
        .mock_1,
        .init([.mock_1])
      ),
      throws: MetadataEncryptionFailure.self,
      "Should throw MetadataEncryptionFailure"
    )
  }

  func test_givenV5ResourceType_whenCallingCreateWithSharingOption_shouldUseSharedKeyEncryption() async throws {
    let sharedEncryptionExpectation: XCTestExpectation = .init(description: "Should call shared key encryption")
    let createNetworkOperationExpectation: XCTestExpectation = .init(
      description: "Should call create network operation"
    )
    let sharedMetadataKeyID: MetadataKeyDTO.ID = .init()
    patch(
      \MetadataKeysService.encrypt,
      with: { input, key async throws in
        XCTAssert(key == .sharedKey(sharedMetadataKeyID))
        sharedEncryptionExpectation.fulfill()
        return .init(rawValue: input)
      }
    )

    patch(
      \MetadataKeysService.determineKeyType,
      with: { isShared in
        XCTAssertTrue(isShared)
        return .sharedKey(sharedMetadataKeyID)
      }
    )

    patch(
      \ResourceCreateNetworkOperation.execute,
      with: { input in
        createNetworkOperationExpectation.fulfill()
        XCTAssertEqual(input.metadataKeyType, .shared)

        return .init(
          resourceID: .mock_1,
          ownerPermissionID: .mock_1
        )
      }
    )

    let sut: ResourceNetworkOperationDispatch = try self.testedInstance()
    _ = try await sut.createResource(
      .init(
        type: .init(id: .mock_1, slug: .v5Default)
      ),
      .init([.mock_1]),
      true
    )
    await fulfillment(of: [sharedEncryptionExpectation, createNetworkOperationExpectation], timeout: 1)
  }
}
