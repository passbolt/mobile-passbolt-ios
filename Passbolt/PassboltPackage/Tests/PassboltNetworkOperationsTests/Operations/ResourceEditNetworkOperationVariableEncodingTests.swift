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

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverForceUnwrap
final class ResourceEditNetworkOperationVariableEncodingTests: TestCase {

  // MARK: - V5 (ResourceEditNetworkOperationVariable)

  func test_encode_excludesResourceID() throws {
    let variable: ResourceEditNetworkOperationVariable = .init(
      resourceID: .init(),
      resourceTypeID: .init(),
      parentFolderID: .init(),
      metadata: .init(rawValue: "test-pgp-message"),
      metadataKeyID: .init(),
      metadataKeyType: .shared,
      secrets: [
        (userID: .init(), data: .init(rawValue: "test-secret"))
      ]
    )

    let data: Data = try JSONEncoder.default.encode(variable)
    let json: Dictionary<String, Any> = try XCTUnwrap(
      JSONSerialization.jsonObject(with: data) as? Dictionary<String, Any>
    )

    XCTAssertNil(json["resourceID"])
    XCTAssertNil(json["resource_id"])
  }

  func test_encode_includesAllExpectedKeys() throws {
    let variable: ResourceEditNetworkOperationVariable = .init(
      resourceID: .init(),
      resourceTypeID: .init(),
      parentFolderID: .init(),
      metadata: .init(rawValue: "test-pgp-message"),
      metadataKeyID: .init(),
      metadataKeyType: .shared,
      secrets: [
        (userID: .init(), data: .init(rawValue: "test-secret"))
      ]
    )

    let data: Data = try JSONEncoder.default.encode(variable)
    let json: Dictionary<String, Any> = try XCTUnwrap(
      JSONSerialization.jsonObject(with: data) as? Dictionary<String, Any>
    )

    let expectedKeys: Set<String> = [
      "folder_parent_id",
      "resource_type_id",
      "metadata",
      "metadata_key_id",
      "metadata_key_type",
      "secrets",
      "expired",
    ]

    XCTAssertEqual(Set(json.keys), expectedKeys)
  }

  func test_encode_withNilOptionals_includesNullForMetadataKeyIDAndExpired() throws {
    let variable: ResourceEditNetworkOperationVariable = .init(
      resourceID: .init(),
      resourceTypeID: .init(),
      parentFolderID: .none,
      metadata: .init(rawValue: "test-pgp-message"),
      metadataKeyID: .none,
      metadataKeyType: .shared,
      secrets: [
        (userID: .init(), data: .init(rawValue: "test-secret"))
      ],
      expired: .none
    )

    let data: Data = try JSONEncoder.default.encode(variable)
    let json: Dictionary<String, Any> = try XCTUnwrap(
      JSONSerialization.jsonObject(with: data) as? Dictionary<String, Any>
    )

    // parentFolderID uses encodeIfPresent — omitted when nil
    XCTAssertNil(json["folder_parent_id"])

    // metadataKeyID uses encode — present as null when nil
    XCTAssertTrue(json.keys.contains("metadata_key_id"))
    XCTAssertTrue(json["metadata_key_id"] is NSNull)

    // expired uses encode — present as null when nil
    XCTAssertTrue(json.keys.contains("expired"))
    XCTAssertTrue(json["expired"] is NSNull)
  }

  // MARK: - V4 (ResourceEditNetworkOperationV4Variable)

  func test_encodeV4_excludesResourceID() throws {
    let variable: ResourceEditNetworkOperationV4Variable = .init(
      resourceID: .init(),
      resourceTypeID: .init(),
      parentFolderID: .init(),
      name: "test-name",
      username: "test-username",
      url: .init(rawValue: "https://example.com"),
      description: "test-description",
      secrets: [
        (userID: .init(), data: .init(rawValue: "test-secret"))
      ]
    )

    let data: Data = try JSONEncoder.default.encode(variable)
    let json: Dictionary<String, Any> = try XCTUnwrap(
      JSONSerialization.jsonObject(with: data) as? Dictionary<String, Any>
    )

    XCTAssertNil(json["resourceID"])
    XCTAssertNil(json["resource_id"])
  }

  func test_encodeV4_includesAllExpectedKeysWhenFieldsPresent() throws {
    let variable: ResourceEditNetworkOperationV4Variable = .init(
      resourceID: .init(),
      resourceTypeID: .init(),
      parentFolderID: .init(),
      name: "test-name",
      username: "test-username",
      url: .init(rawValue: "https://example.com"),
      description: "test-description",
      secrets: [
        (userID: .init(), data: .init(rawValue: "test-secret"))
      ]
    )

    let data: Data = try JSONEncoder.default.encode(variable)
    let json: Dictionary<String, Any> = try XCTUnwrap(
      JSONSerialization.jsonObject(with: data) as? Dictionary<String, Any>
    )

    let expectedKeys: Set<String> = [
      "name",
      "folder_parent_id",
      "description",
      "username",
      "uri",
      "resource_type_id",
      "secrets",
      "expired",
    ]

    XCTAssertEqual(Set(json.keys), expectedKeys)
  }

  func test_encodeV4_withNilOptionals_omitsOptionalFieldsButIncludesExpired() throws {
    let variable: ResourceEditNetworkOperationV4Variable = .init(
      resourceID: .init(),
      resourceTypeID: .init(),
      parentFolderID: .none,
      name: "test-name",
      username: .none,
      url: .none,
      description: .none,
      secrets: [
        (userID: .init(), data: .init(rawValue: "test-secret"))
      ],
      expired: .none
    )

    let data: Data = try JSONEncoder.default.encode(variable)
    let json: Dictionary<String, Any> = try XCTUnwrap(
      JSONSerialization.jsonObject(with: data) as? Dictionary<String, Any>
    )

    // These use encodeIfPresent — omitted when nil
    XCTAssertNil(json["folder_parent_id"])
    XCTAssertNil(json["description"])
    XCTAssertNil(json["username"])
    XCTAssertNil(json["uri"])

    // expired uses encode — present as null when nil
    XCTAssertTrue(json.keys.contains("expired"))
    XCTAssertTrue(json["expired"] is NSNull)

    // Non-optional fields still present
    XCTAssertNotNil(json["name"])
    XCTAssertNotNil(json["resource_type_id"])
    XCTAssertNotNil(json["secrets"])
  }
}
