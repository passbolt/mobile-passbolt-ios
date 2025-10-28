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

public struct ResourceCustomFieldDTO: Sendable, Identifiable, Decodable {

  public typealias ID = Tagged<UUID, Self>

  public let id: ID
  public let type: ResourceCustomFieldType
  public let metadataKey: String?
  public let secretKey: String?
  public let metadataValue: String?
  public let secretValue: String?

  public var key: String? {
    metadataKey ?? secretKey
  }

  public var value: String? {
    metadataValue ?? secretValue
  }

  public init?(json: JSON) {
    guard
      let id: ID = .init(json: json.id),
      let type: ResourceCustomFieldType = .init(json: json.type)
    else {
      return nil
    }

    self.id = id
    self.type = type
    self.metadataKey = json.metadata_key.stringValue
    self.secretKey = json.secret_key.stringValue
    self.metadataValue = json.metadata_value.stringValue
    self.secretValue = json.secret_value.stringValue
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case type
    case metadataKey = "metadata_key"
    case secretKey = "secret_key"
    case metadataValue = "metadata_value"
    case secretValue = "secret_value"
  }

  private init(
    id: ID,
    type: ResourceCustomFieldType,
    metadataKey: String?,
    metadataValue: String?,
    secretKey: String?,
    secretValue: String?
  ) {
    self.id = id
    self.type = type
    self.metadataKey = metadataKey
    self.metadataValue = metadataValue
    self.secretKey = secretKey
    self.secretValue = secretValue
  }

  public func validate() throws {
    if metadataKey == .none && secretKey == .none {
      throw InvalidValue.invalid(
        validationRule: ValidationRule.missingKey,
        value: key,
        displayable: "One of metadataKey or secretKey must be provided."
      )
    }
    if metadataKey != .none && secretKey != .none {
      throw InvalidValue.invalid(
        validationRule: ValidationRule.invalidKey,
        value: key,
        displayable: "Only one of metadataKey or secretKey can be provided."
      )
    }

    if let key: String = self.key, key.count > Self.maxKeyLength {
      throw InvalidValue.invalid(
        validationRule: ValidationRule.keyTooLong,
        value: key,
        displayable: "Key must have less than 256 characters."
      )
    }

    if let value: String = self.value, value.count > Self.maxValueLength {
      throw InvalidValue.invalid(
        validationRule: ValidationRule.valueTooLong,
        value: value,
        displayable: "Value must have less than \(Self.maxValueLength) characters."
      )
    }
  }

  public func combined(with other: ResourceCustomFieldDTO) -> ResourceCustomFieldDTO? {
    guard id == other.id, type == other.type else {
      return .none
    }
    // filter out invalid states - we cannot have both keys or both values
    if (metadataKey != .none && other.metadataKey != .none)
      || (secretKey != .none && other.secretKey != .none)
    {
      return nil
    }

    return .init(
      id: id,
      type: type,
      metadataKey: metadataKey ?? other.metadataKey,
      metadataValue: metadataValue ?? other.metadataValue,
      secretKey: secretKey ?? other.secretKey,
      secretValue: secretValue ?? other.secretValue
    )
  }

  struct ValidationRule {
    static let missingKey: StaticString = "missingKey"
    static let invalidKey: StaticString = "invalidKey"
    static let keyTooLong: StaticString = "keyTooLong"
    static let valueTooLong: StaticString = "valueTooLong"
  }
}

extension JSON {

  public var customFieldDTOs: Array<ResourceCustomFieldDTO>? {
    arrayValue?.compactMap { ResourceCustomFieldDTO(json: $0) }
  }
}

extension Array where Element == ResourceCustomFieldDTO {

  public func combined(with other: Self) -> Self {
    // combine two arrays of ResourceCustomFieldDTOs
    var combined: Array<ResourceCustomFieldDTO> = self

    for field in other {
      if let existingIndex: Index = combined.firstIndex(where: { $0.id == field.id }) {
        if let combinedField: ResourceCustomFieldDTO = combined[existingIndex].combined(with: field) {
          combined[existingIndex] = combinedField
        }
      }
      else {
        combined.append(field)
      }
    }
    return combined
  }
}

extension ResourceCustomFieldDTO {

  fileprivate static let maxKeyLength: Int = 255
  fileprivate static let maxValueLength: Int = 20_000
}
