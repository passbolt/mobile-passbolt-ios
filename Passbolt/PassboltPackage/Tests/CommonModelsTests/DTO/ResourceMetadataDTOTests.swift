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

@testable import CommonModels

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverForceUnwrap
final class ResourceMetadataDTOTests: TestCase {
  func test_creatingResourceMetadataDTO_fromJSON() throws {
    let json = """
      {
        "name": "test name",
        "description": "test description",
        "username": "test username"
      }
      """

    let data = json.data(using: .utf8)!
    let metadata = try ResourceMetadataDTO(resourceId: .init(), data: data)
    XCTAssertEqual(metadata.name, "test name")
    XCTAssertEqual(metadata.description, "test description")
    XCTAssertEqual(metadata.username, "test username")
  }

  func test_creatingResourceMetadataDTO_fromResourceDTO() throws {
    let name = "test name"
    let description = "test description"
    let username = "test username"

    let resource = createResourceDTO(name: name, description: description, username: username)

    let metadata = try ResourceMetadataDTO(resource: resource)
    XCTAssertEqual(metadata.name, name)
    XCTAssertEqual(metadata.description, description)
    XCTAssertEqual(metadata.username, username)
    XCTAssertEqual(metadata.resourceId, resource.id)
  }

  func test_resourceValidation_nameMustHaveLessThan256Characters() throws {
    let name = String(repeating: "a", count: 256)
    let resource = createResourceDTO(name: name)

    let metadata = try ResourceMetadataDTO(resource: resource)
    verifyIfTriggersValidationError(
      try metadata.validate(with: resource),
      validationRule: ResourceMetadataDTO.ValidationRule.nameTooLong
    )
  }

  func test_resourceValidation_nameMustNotBeEmpty() throws {
    let resource = createResourceDTO(name: "")

    let metadata = try ResourceMetadataDTO(resource: resource)
    verifyIfTriggersValidationError(
      try metadata.validate(with: resource),
      validationRule: ResourceMetadataDTO.ValidationRule.nameEmpty
    )
  }

  func test_resourceValidation_usernameMustHaveLessThan256Characters() throws {
    let username = String(repeating: "a", count: 256)
    let resource = createResourceDTO(name: "test name", username: username)

    let metadata = try ResourceMetadataDTO(resource: resource)
    verifyIfTriggersValidationError(
      try metadata.validate(with: resource),
      validationRule: ResourceMetadataDTO.ValidationRule.usernameTooLong
    )
  }

  func test_resourceValidation_descriptionMustHaveLessThan10kCharacters() throws {
    let description = String(repeating: "a", count: 10_001)
    let resource = createResourceDTO(name: "test name", description: description)

    let metadata = try ResourceMetadataDTO(resource: resource)
    verifyIfTriggersValidationError(
      try metadata.validate(with: resource),
      validationRule: ResourceMetadataDTO.ValidationRule.descriptionTooLong
    )
  }

  func test_resourceValidation_resourceTypeMustMatchMetadata() throws {
    var resource = createResourceDTO(name: "test name")
    let metadata = try ResourceMetadataDTO(resource: resource)
    resource = createResourceDTO(name: "test name")  // regenerate resource to generate new typeID
    verifyIfTriggersValidationError(
      try metadata.validate(with: resource),
      validationRule: ResourceMetadataDTO.ValidationRule.resourceTypeMismatch
    )
  }

  func test_resourceValidation_customFieldsValidation_succeeds() throws {
    let resource = createResourceDTO(name: "test name", description: "test description", username: "test username")
    
    // Create metadata from resource (this generates proper JSON with object_type and resource_type_id)
    var metadata = try ResourceMetadataDTO(resource: resource)
    
    // Modify the internal data to include custom fields
    let json = try JSONDecoder.default.decode(JSON.self, from: metadata.data)
    var modifiedJson = json
    modifiedJson[keyPath: \.custom_fields] = .array([
      .object([
        "id": .string("550e8400-e29b-41d4-a716-446655440000"),
        "type": .string("text"),
        "metadata_key": .string("valid_key"),
        "metadata_value": .string("valid_value")
      ])
    ])
    
    let modifiedData = try JSONEncoder.default.encode(modifiedJson)
    metadata = try ResourceMetadataDTO(resourceId: resource.id, data: modifiedData)
    
    XCTAssertNoThrow(try metadata.validate(with: resource))
  }

  func test_resourceValidation_customFieldsValidation_failsForInvalidFields() throws {
    let resource = createResourceDTO(name: "test name", description: "test description", username: "test username")
    
    // Create metadata from resource
    var metadata = try ResourceMetadataDTO(resource: resource)
    
    // Modify the internal data to include invalid custom fields (missing key)
    let json = try JSONDecoder.default.decode(JSON.self, from: metadata.data)
    var modifiedJson = json
    modifiedJson[keyPath: \.custom_fields] = .array([
      .object([
        "id": .string("550e8400-e29b-41d4-a716-446655440000"),
        "type": .string("text")
        // Missing metadata_key and secret_key - should trigger validation error
      ])
    ])
    
    let modifiedData = try JSONEncoder.default.encode(modifiedJson)
    metadata = try ResourceMetadataDTO(resourceId: resource.id, data: modifiedData)

    verifyIfTriggersValidationError(
      try metadata.validate(with: resource),
      validationRule: ResourceCustomFieldDTO.ValidationRule.missingKey
    )
  }

  func test_resourceValidation_customFieldsValidation_succeedsWithEmptyArray() throws {
    let resource = createResourceDTO(name: "test name", description: "test description", username: "test username")
    
    // Create metadata from resource
    var metadata = try ResourceMetadataDTO(resource: resource)
    
    // Modify the internal data to include empty custom fields array
    let json = try JSONDecoder.default.decode(JSON.self, from: metadata.data)
    var modifiedJson = json
    modifiedJson[keyPath: \.custom_fields] = .array([])
    
    let modifiedData = try JSONEncoder.default.encode(modifiedJson)
    metadata = try ResourceMetadataDTO(resourceId: resource.id, data: modifiedData)

    XCTAssertNoThrow(try metadata.validate(with: resource))
  }

  private func createResourceDTO(name: String, description: String? = nil, username: String? = nil) -> ResourceDTO {
    ResourceDTO(
      id: .init(),
      typeID: .init(),
      parentFolderID: nil,
      favoriteID: nil,
      name: name,
      permission: .read,
      permissions: [],
      uri: nil,
      username: username,
      description: description,
      tags: [],
      modified: .init(),
      expired: nil
    )
  }
}
