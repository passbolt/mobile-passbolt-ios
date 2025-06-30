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

import struct Foundation.Data
import class Foundation.JSONDecoder
import class Foundation.JSONEncoder
import class Foundation.JSONSerialization

public struct ResourceMetadataDTO: Sendable {
  public let resourceId: Resource.ID
  public let name: String
  public let description: String?
  public let username: String?
  public let data: Data
  public let uris: [ResourceURIDTO]
  public let objectType: MetadataObjectType?
  public let resourceTypeId: ResourceType.ID?
  public let icon: ResourceIcon?

  /// Initialize a new resource metadata DTO from decrypted JSON data.
  /// - Parameters:
  ///  - resourceId: The resource ID.
  ///  - data: The decrypted JSON data.
  ///
  ///  > Throws:
  ///  > - `InternalInconsistency` if the resource name is missing.
  ///  > - `DecodingError` if the JSON data cannot be decoded.
  public init(resourceId: Resource.ID, data: Data) throws {
    self.resourceId = resourceId
    self.data = data
    let json = try JSONDecoder.default.decode(JSON.self, from: data)
    // todo: add resource_type_id validation?
    guard let name = json[keyPath: \.name].stringValue
    else {
      throw EntityValidationError.error(
        message: "Resource name is missing.",
        details: [
          "resourceId": resourceId
        ]
      )
    }
    self.description = json[keyPath: \.description].stringValue
    self.username = json[keyPath: \.username].stringValue
    self.name = name
    self.uris = json[keyPath: \.uris].arrayValue?.compactMap { ResourceURIDTO(resourceId: resourceId, json: $0) } ?? []
    self.objectType = json[keyPath: \.object_type].stringValue.flatMap { MetadataObjectType(rawValue: $0) }
    self.resourceTypeId = json[keyPath: \.resource_type_id].stringValue.flatMap { ResourceType.ID(uuidString: $0) }
    self.icon = .init(json: json[keyPath: \.icon])
  }

  /// Initialize a new resource metadata DTO from Resource DTO.
  /// - Parameter resource: The resource DTO.
  ///
  /// - Throws: `EntityValidationError` if the resource name is missing.
  public init(resource: ResourceDTO) throws {
    resourceId = resource.id
    guard let name = resource.name
    else {
      throw EntityValidationError.error(
        message: "Resource name is missing.",
        details: [
          "resourceId": resourceId
        ]
      )
    }
    self.name = name
    description = resource.description
    username = resource.username
    var json: JSON = .null
    json[keyPath: \.name] = .string(name)
    if let description = resource.description {
      json[keyPath: \.description] = .string(description)
    }
    if let username = resource.username {
      json[keyPath: \.username] = .string(username)
    }
    if let uri = resource.uri {
      json[keyPath: \.uris] = .array([.string(uri)])
      self.uris = [.init(resourceId: resourceId, uri: uri)]
    }
    else {
      self.uris = []
    }
    objectType = .resourceMetadata
    json[keyPath: \.object_type] = .string(MetadataObjectType.resourceMetadata.rawValue)
    resourceTypeId = resource.typeID
    json[keyPath: \.resource_type_id] = .string(resource.typeID.rawValue.rawValue.uuidString)

    self.icon = nil

    data = try JSONEncoder.default.encode(json)
  }
}

extension ResourceMetadataDTO {
  public static func initialResourceMetadataJSON(for resource: Resource) -> JSON {
    var json: JSON = .object([:])
    json[keyPath: \.resource_type_id] = .string(resource.type.id.rawValue.rawValue.uuidString)
    json[keyPath: \.object_type] = .string(MetadataObjectType.resourceMetadata.rawValue)
    json[keyPath: \.uris] = .array([])
    return json
  }

  public static func initialResourceMetadataJSON(for resourceType: ResourceType) -> JSON {
    var json: JSON = .object([:])
    json[keyPath: \.resource_type_id] = .string(resourceType.id.rawValue.rawValue.uuidString)
    json[keyPath: \.object_type] = .string(MetadataObjectType.resourceMetadata.rawValue)
    json[keyPath: \.uris] = .array([])
    return json
  }
}

extension ResourceMetadataDTO {
  /// Validate the resource metadata.
  /// > Throws:
  /// > - `EntityValidationError` if the metadata is invalid.
  /// > - `InvalidValue` if the metadata is invalid.
  public func validate(with resource: ResourceDTO) throws {
    // validate internal state
    let json = try JSONDecoder.default.decode(JSON.self, from: data)
    guard json[keyPath: \.name].stringValue == name
    else {
      throw
        EntityValidationError
        .error(
          message: "Resource metadata name mismatch.",
          underlyingError: .none,
          details: [
            "field": name,
            "json": json[keyPath: \.name],
          ]
        )
    }

    guard json[keyPath: \.description].stringValue == description
    else {
      throw
        EntityValidationError
        .error(
          message: "Resource metadata description mismatch.",
          underlyingError: .none,
          details: [
            "field": description as Any,
            "json": json[keyPath: \.description],
          ]
        )
    }

    guard json[keyPath: \.username].stringValue == username
    else {
      throw
        EntityValidationError
        .error(
          message: "Resource metadata username mismatch.",
          underlyingError: .none,
          details: [
            "field": username as Any,
            "json": json[keyPath: \.username],
          ]
        )
    }

    // Validate fields
    if name.count > 255 {
      throw InvalidValue.tooLong(
        validationRule: ValidationRule.nameTooLong,
        value: name,
        displayable: .raw("Name is too long.")
      )
    }

    if name.isEmpty {
      throw InvalidValue.invalid(
        validationRule: ValidationRule.nameEmpty,
        value: name,
        displayable: "Name is empty."
      )
    }

    if let username = username {
      if username.count > 255 {
        throw InvalidValue.tooLong(
          validationRule: ValidationRule.usernameTooLong,
          value: username,
          displayable: "Username is too long."
        )
      }
    }

    if let description = description {
      if description.count > 10_000 {
        throw InvalidValue.tooLong(
          validationRule: ValidationRule.descriptionTooLong,
          value: description,
          displayable: "Description is too long."
        )
      }
    }

    if json[keyPath: \.object_type].stringValue.flatMap({ MetadataObjectType(rawValue: $0) }) != .resourceMetadata {
      throw InvalidValue.invalid(
        validationRule: ValidationRule.objectTypeMismatch,
        value: json[keyPath: \.object_type].stringValue,
        displayable: "Object type is invalid."
      )
    }

    let resourceTypeId = resource.typeID.rawValue.rawValue.uuidString.lowercased()

    if json[keyPath: \.resource_type_id].stringValue?.lowercased() != resourceTypeId {
      throw InvalidValue.invalid(
        validationRule: ValidationRule.resourceTypeMismatch,
        value: json[keyPath: \.resource_type_id].stringValue,
        displayable: "Resource type is invalid."
      )
    }
  }

  struct ValidationRule {
    static let nameTooLong: StaticString = "name-too-long"
    static let nameEmpty: StaticString = "name-empty"
    static let usernameTooLong: StaticString = "username-too-long"
    static let descriptionTooLong: StaticString = "description-too-long"
    static let resourceTypeMismatch: StaticString = "resource-type-mismatch"
    static let objectTypeMismatch: StaticString = "object-type-mismatch"
  }
}
