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
final class ResourceCustomFieldDTOTests: TestCase {

  func test_creatingResourceCustomFieldDTO_fromJSON() throws {
    let json = """
      {
        "id": "550e8400-e29b-41d4-a716-446655440000",
        "type": "text",
        "metadata_key": "test_key",
        "metadata_value": "test_value"
      }
      """

    let data = json.data(using: .utf8)!
    let jsonObject = try JSONDecoder.default.decode(JSON.self, from: data)
    let customField = ResourceCustomFieldDTO(json: jsonObject)

    XCTAssertNotNil(customField)
    XCTAssertEqual(customField?.type, .text)
    XCTAssertEqual(customField?.metadataKey, "test_key")
    XCTAssertEqual(customField?.metadataValue, "test_value")
    XCTAssertNil(customField?.secretKey)
    XCTAssertNil(customField?.secretValue)
    XCTAssertEqual(customField?.key, "test_key")
    XCTAssertEqual(customField?.value, "test_value")
  }

  func test_creatingResourceCustomFieldDTO_fromJSONWithSecretFields() throws {
    let json = """
      {
        "id": "550e8400-e29b-41d4-a716-446655440000",
        "type": "text",
        "secret_key": "secret_key",
        "secret_value": "secret_value"
      }
      """

    let data = json.data(using: .utf8)!
    let jsonObject = try JSONDecoder.default.decode(JSON.self, from: data)
    let customField = ResourceCustomFieldDTO(json: jsonObject)

    XCTAssertNotNil(customField)
    XCTAssertEqual(customField?.type, .text)
    XCTAssertEqual(customField?.secretKey, "secret_key")
    XCTAssertEqual(customField?.secretValue, "secret_value")
    XCTAssertNil(customField?.metadataKey)
    XCTAssertNil(customField?.metadataValue)
    XCTAssertEqual(customField?.key, "secret_key")
    XCTAssertEqual(customField?.value, "secret_value")
  }

  func test_creatingResourceCustomFieldDTO_fromInvalidJSON() throws {
    let json = """
      {
        "type": "text",
        "metadata_key": "test_key"
      }
      """

    let data = json.data(using: .utf8)!
    let jsonObject = try JSONDecoder.default.decode(JSON.self, from: data)
    let customField = ResourceCustomFieldDTO(json: jsonObject)

    XCTAssertNil(customField)
  }

  func test_validation_succeeds_withValidMetadataFields() throws {
    let customField = createCustomFieldDTO(metadataKey: "test_key", metadataValue: "test_value")

    XCTAssertNoThrow(try customField.validate())
  }

  func test_validation_succeeds_withValidSecretFields() throws {
    let customField = createCustomFieldDTO(secretKey: "test_key", secretValue: "test_value")

    XCTAssertNoThrow(try customField.validate())
  }

  func test_validation_fails_whenBothKeysProvided() throws {
    let customField = createCustomFieldDTO(metadataKey: "metadata_key", secretKey: "secret_key")

    verifyIfTriggersValidationError(
      try customField.validate(),
      validationRule: ResourceCustomFieldDTO.ValidationRule.invalidKey
    )
  }

  func test_validation_fails_whenNoKeyProvided() throws {
    let customField = createCustomFieldDTO()

    verifyIfTriggersValidationError(
      try customField.validate(),
      validationRule: ResourceCustomFieldDTO.ValidationRule.missingKey
    )
  }

  func test_validation_fails_whenKeyTooLong() throws {
    let longKey = String(repeating: "a", count: 256)
    let customField = createCustomFieldDTO(metadataKey: longKey)

    verifyIfTriggersValidationError(
      try customField.validate(),
      validationRule: ResourceCustomFieldDTO.ValidationRule.keyTooLong
    )
  }

  func test_validation_fails_whenValueTooLong() throws {
    let longValue = String(repeating: "a", count: 20_001)
    let customField = createCustomFieldDTO(metadataKey: "test_key", metadataValue: longValue)

    verifyIfTriggersValidationError(
      try customField.validate(),
      validationRule: ResourceCustomFieldDTO.ValidationRule.valueTooLong
    )
  }

  func test_combined_succeeds_withCompatibleFields() throws {
    let metadataField = createCustomFieldDTO(metadataKey: "test_key", metadataValue: "test_value")
    let secretField = createCustomFieldDTO(id: metadataField.id, secretKey: "test_key", secretValue: "secret_value")

    let combined = metadataField.combined(with: secretField)

    XCTAssertNotNil(combined)
    XCTAssertEqual(combined?.id, metadataField.id)
    XCTAssertEqual(combined?.type, .text)
    XCTAssertEqual(combined?.metadataKey, "test_key")
    XCTAssertEqual(combined?.metadataValue, "test_value")
    XCTAssertEqual(combined?.secretKey, "test_key")
    XCTAssertEqual(combined?.secretValue, "secret_value")
  }

  func test_combined_fails_withDifferentIDs() throws {
    let field1 = createCustomFieldDTO(metadataKey: "test_key")
    let field2 = createCustomFieldDTO(secretKey: "test_key")

    let combined = field1.combined(with: field2)

    XCTAssertNil(combined)
  }

  func test_combined_fails_withConflictingMetadataKeys() throws {
    let field1 = createCustomFieldDTO(metadataKey: "key1")
    let field2 = createCustomFieldDTO(id: field1.id, metadataKey: "key2")

    let combined = field1.combined(with: field2)

    XCTAssertNil(combined)
  }

  func test_combined_fails_withConflictingSecretKeys() throws {
    let field1 = createCustomFieldDTO(secretKey: "key1")
    let field2 = createCustomFieldDTO(id: field1.id, secretKey: "key2")

    let combined = field1.combined(with: field2)

    XCTAssertNil(combined)
  }

  func test_arrayExtension_combined_withEmptyArrays() throws {
    let array1: Array<ResourceCustomFieldDTO> = []
    let array2: Array<ResourceCustomFieldDTO> = []

    let combined = array1.combined(with: array2)

    XCTAssertTrue(combined.isEmpty)
  }

  func test_arrayExtension_combined_withNonOverlappingArrays() throws {
    let field1 = createCustomFieldDTO(metadataKey: "key1", metadataValue: "value1")
    let field2 = createCustomFieldDTO(metadataKey: "key2", metadataValue: "value2")

    let array1 = [field1]
    let array2 = [field2]

    let combined = array1.combined(with: array2)

    XCTAssertEqual(combined.count, 2)
    XCTAssertTrue(combined.contains { $0.id == field1.id })
    XCTAssertTrue(combined.contains { $0.id == field2.id })
  }

  func test_arrayExtension_combined_withOverlappingArrays() throws {
    let id = ResourceCustomFieldDTO.ID.init(rawValue: UUID())
    let metadataField = createCustomFieldDTO(id: id, metadataKey: "test_key", metadataValue: "test_value")
    let secretField = createCustomFieldDTO(id: id, secretKey: "test_key", secretValue: "secret_value")

    let array1 = [metadataField]
    let array2 = [secretField]

    let combined = array1.combined(with: array2)

    XCTAssertEqual(combined.count, 1)
    let combinedField = combined.first!
    XCTAssertEqual(combinedField.id, id)
    XCTAssertEqual(combinedField.metadataKey, "test_key")
    XCTAssertEqual(combinedField.metadataValue, "test_value")
    XCTAssertEqual(combinedField.secretKey, "test_key")
    XCTAssertEqual(combinedField.secretValue, "secret_value")
  }

  func test_arrayExtension_combined_withMixedArrays() throws {
    let id1 = ResourceCustomFieldDTO.ID.init(rawValue: UUID())
    let id2 = ResourceCustomFieldDTO.ID.init(rawValue: UUID())

    let field1Metadata = createCustomFieldDTO(id: id1, metadataKey: "key1", metadataValue: "value1")
    let field2 = createCustomFieldDTO(id: id2, metadataKey: "key2", metadataValue: "value2")
    let field1Secret = createCustomFieldDTO(id: id1, secretKey: "key1", secretValue: "secret1")
    let field3 = createCustomFieldDTO(metadataKey: "key3", metadataValue: "value3")

    let array1 = [field1Metadata, field2]
    let array2 = [field1Secret, field3]

    let combined = array1.combined(with: array2)

    XCTAssertEqual(combined.count, 3)

    let combinedField1 = combined.first { $0.id == id1 }!
    XCTAssertEqual(combinedField1.metadataKey, "key1")
    XCTAssertEqual(combinedField1.metadataValue, "value1")
    XCTAssertEqual(combinedField1.secretKey, "key1")
    XCTAssertEqual(combinedField1.secretValue, "secret1")

    XCTAssertTrue(combined.contains { $0.id == id2 })
    XCTAssertTrue(combined.contains { $0.id == field3.id })
  }

  func test_arrayExtension_combined_withIncompatibleFields() throws {
    let id = ResourceCustomFieldDTO.ID.init(rawValue: UUID())
    let field1 = createCustomFieldDTO(id: id, metadataKey: "key1")
    let field2 = createCustomFieldDTO(id: id, metadataKey: "key2")

    let array1 = [field1]
    let array2 = [field2]

    let combined = array1.combined(with: array2)

    XCTAssertEqual(combined.count, 1)
    XCTAssertEqual(combined.first?.id, id)
    XCTAssertEqual(combined.first?.metadataKey, "key1")
  }

  private func createCustomFieldDTO(
    id: ResourceCustomFieldDTO.ID? = nil,
    metadataKey: String? = nil,
    metadataValue: String? = nil,
    secretKey: String? = nil,
    secretValue: String? = nil
  ) -> ResourceCustomFieldDTO {
    let fieldId = id ?? .init(rawValue: UUID())
    var jsonDict: [String: JSON] = [
      "id": JSON.string(fieldId.rawValue.uuidString),
      "type": "text",
    ]

    if let metadataKey = metadataKey {
      jsonDict["metadata_key"] = JSON.string(metadataKey)
    }
    if let metadataValue = metadataValue {
      jsonDict["metadata_value"] = JSON.string(metadataValue)
    }
    if let secretKey = secretKey {
      jsonDict["secret_key"] = JSON.string(secretKey)
    }
    if let secretValue = secretValue {
      jsonDict["secret_value"] = JSON.string(secretValue)
    }

    let json = JSON.object(jsonDict)

    return ResourceCustomFieldDTO(json: json)!
  }
}
