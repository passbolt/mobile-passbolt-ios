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

public typealias ResourceTypeDTO = ResourceType

extension ResourceTypeDTO: Decodable {

  public init(
    from decoder: Decoder
  ) throws {
    let container: KeyedDecodingContainer<ResourceTypeDTO.CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)
    self.id = try container.decode(ResourceType.ID.self, forKey: .id)
    self.slug = try container.decode(ResourceType.Slug.self, forKey: .slug)
    self._name = try container.decode(String.self, forKey: .name)

    let fieldsDefinition: FieldsDefinition = try container.decode(FieldsDefinition.self, forKey: .definition)
    self.fields = fieldsDefinition.fields
  }

  private enum CodingKeys: String, CodingKey {

    case id = "id"
    case slug = "slug"
    case name = "name"
    case definition = "definition"
  }
}

private struct FieldsDefinition {

  fileprivate var fields: OrderedSet<ResourceField>
}

extension FieldsDefinition: Decodable {

  fileprivate init(
    from decoder: Decoder
  ) throws {
    let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)

    let fieldsContainer: KeyedDecodingContainer<DefinitionCodingKeys> = try container.nestedContainer(
      keyedBy: DefinitionCodingKeys.self,
      forKey: .resource
    )
    let requiredFields: Set<String> = try fieldsContainer.decode(Set<String>.self, forKey: .required)

    let fieldsDefinitionsContainer: KeyedDecodingContainer<AnyCodingKey> =
      try fieldsContainer
      .nestedContainer(
        keyedBy: AnyCodingKey.self,
        forKey: .fields
      )

    self.fields = try OrderedSet(
      fieldsDefinitionsContainer.allKeys
        .compactMap { (key: AnyCodingKey) -> ResourceField? in
          let fieldDescription: FieldDescription = try fieldsDefinitionsContainer.decode(
            FieldDescription.self,
            forKey: key
          )
          switch fieldDescription.type {
          case .string:
            return .init(
              name: key.stringValue,
              content: .string(
                encrypted: false,
                required: requiredFields.contains(key.stringValue),
                minLength: fieldDescription.min,
                maxLength: fieldDescription.max
              )
            )
          case .object:
            throw
              DecodingError
              .dataCorruptedError(
                forKey: .resource,
                in: container,
                debugDescription: "Unsupported or invalid field description"
              )

          case .null:  // ignore
            assertionFailure("NULL types should not occur in models.")
            return .none
          }
        }
    )

    do {
      let secretFieldsContainer: KeyedDecodingContainer<DefinitionCodingKeys> =
        try container
        .nestedContainer(
          keyedBy: DefinitionCodingKeys.self,
          forKey: .secret
        )

      let requiredSecretFields: Set<String> = try secretFieldsContainer.decode(Set<String>.self, forKey: .required)

      let secretFieldsDefinitionsContainer: KeyedDecodingContainer<AnyCodingKey> =
        try secretFieldsContainer
        .nestedContainer(
          keyedBy: AnyCodingKey.self,
          forKey: .fields
        )

      try self.fields.append(
        contentsOf: secretFieldsDefinitionsContainer.allKeys
          .compactMap { (key: AnyCodingKey) -> ResourceField? in
            let fieldDescription: FieldDescription = try secretFieldsDefinitionsContainer.decode(
              FieldDescription.self,
              forKey: key
            )
            switch fieldDescription.type {
            case .string:
              return .init(
                name: key.stringValue,
                content: .string(
                  encrypted: true,
                  required: requiredSecretFields.contains(key.stringValue),
                  minLength: fieldDescription.min,
                  maxLength: fieldDescription.max
                )
              )

            case .object:
              if key.stringValue == "totp" {
                return .init(
                  name: key.stringValue,
                  content: .totp(required: requiredSecretFields.contains(key.stringValue))
                )
              }
              else {
                throw
                  DecodingError
                  .dataCorruptedError(
                    forKey: .secret,
                    in: container,
                    debugDescription: "Unsupported or invalid field description"
                  )
              }
            case .null:  // ignore
              assertionFailure("NULL types should not occur in models.")
              return .none
            }
          }
      )
    }
    catch DecodingError.keyNotFound {
      // fallback for legacy secret type
      self.fields.append(
        .init(
          name: "secret",
          content: .string(
            encrypted: true,
            required: true,
            minLength: .none,
            maxLength: .none
          )
        )
      )
    }
    catch {
      throw error
    }
  }

  private enum CodingKeys: String, CodingKey {

    case resource = "resource"
    case secret = "secret"
  }

  private enum DefinitionCodingKeys: String, CodingKey {

    case fields = "properties"
    case `required` = "required"
  }
}

private enum FieldType: String, Decodable {

  case null = "null"
  case string = "string"
  case object = "object"
}

private struct FieldDescription {

  fileprivate var type: FieldType
  fileprivate var min: UInt?
  fileprivate var max: UInt?
}

extension FieldDescription: Decodable {

  fileprivate init(
    from decoder: Decoder
  ) throws {
    let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)

    if container.allKeys.contains(.oneOf) {
      let oneOf: Array<FieldDescription> =
        try container.decode(
          Array<FieldDescription>.self,
          forKey: .oneOf
        )

      guard let description: FieldDescription = oneOf.first(where: { $0.type == .string })
      else {
        throw
          DecodingError
          .dataCorruptedError(
            forKey: .oneOf,
            in: container,
            debugDescription: "Unsupported or invalid field description"
          )
      }
      self.type = description.type
      self.max = description.max
    }
    else {
      self.type =
        try container
        .decode(
          FieldType.self,
          forKey: .type
        )
      self.min =
        try container
        .decodeIfPresent(
          UInt.self,
          forKey: .minLength
        )
        ?? container
        .decodeIfPresent(
          UInt.self,
          forKey: .minimum
        )
      self.max =
        try container
        .decodeIfPresent(
          UInt.self,
          forKey: .maxLength
        )
        ?? container
        .decodeIfPresent(
          UInt.self,
          forKey: .maximum
        )
    }
  }

  private enum CodingKeys: String, CodingKey {

    case oneOf = "anyOf"
    case type = "type"
    case minLength = "minLength"
    case maxLength = "maxLength"
    case minimum = "minimum"
    case maximum = "maximum"
  }
}
