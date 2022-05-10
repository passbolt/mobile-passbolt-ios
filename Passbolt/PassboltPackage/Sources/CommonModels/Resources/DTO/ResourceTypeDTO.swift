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

public struct ResourceTypeDTO {

  public var id: ResourceType.ID
  public var slug: ResourceType.Slug
  public var name: String
  public var fields: Array<ResourceFieldDTO>

  public init(
    id: ResourceType.ID,
    slug: ResourceType.Slug,
    name: String,
    fields: Array<ResourceFieldDTO>
  ) {
    self.id = id
    self.slug = slug
    self.name = name
    self.fields = fields
  }
}

extension ResourceTypeDTO: DTO {}

extension ResourceTypeDTO: Decodable {

  public init(
    from decoder: Decoder
  ) throws {
    let container: KeyedDecodingContainer<ResourceTypeDTO.CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)
    self.id = try container.decode(ResourceType.ID.self, forKey: .id)
    self.slug = try container.decode(ResourceType.Slug.self, forKey: .slug)
    self.name = try container.decode(String.self, forKey: .name)
    let definition: TypeDefinition = try container.decode(TypeDefinition.self, forKey: .definition)

    self.fields =
      definition.fields.compactMap { field in
        let valueType: ResourceFieldValueTypeDTO
        switch field.type {
        case .null:
          return nil  // null field has no values...

        case .string:
          valueType = .string
        }

        return ResourceFieldDTO(
          name: .init(rawValue: field.name),
          valueType: valueType,
          required: field.required,
          encrypted: false,
          maxLength: field.maxLength
        )
      }
      + definition.secretFields.compactMap { field in
        let valueType: ResourceFieldValueTypeDTO
        switch field.type {
        case .null:
          return nil  // null field has no values...

        case .string:
          valueType = .string
        }

        return ResourceFieldDTO(
          name: .init(rawValue: field.name),
          valueType: valueType,
          required: field.required,
          encrypted: true,
          maxLength: field.maxLength
        )
      }
  }

  private enum CodingKeys: String, CodingKey {

    case id = "id"
    case slug = "slug"
    case name = "name"
    case definition = "definition"
  }
}

extension ResourceTypeDTO: Hashable {}

#if DEBUG

extension ResourceTypeDTO: RandomlyGenerated {

  public static func randomGenerator(
    using randomnessGenerator: RandomnessGenerator
  ) -> Generator<Self> {
    zip(
      with: ResourceTypeDTO.init(id:slug:name:fields:),
      ResourceType.ID
        .randomGenerator(using: randomnessGenerator),
      ResourceType.Slug
        .randomGenerator(using: randomnessGenerator),
      [
        ResourceType.Slug.defaultSlug.rawValue
      ]
      .randomNonEmptyElementGenerator(
        using: randomnessGenerator
      ),
      ResourceFieldDTO
        .randomGenerator(using: randomnessGenerator)
        .array(withCount: 3)
    )
  }
}
#endif

private struct TypeDefinition {

  public var fields: Array<Field>
  public var secretFields: Array<Field>
}

extension TypeDefinition: Decodable {

  public init(
    from decoder: Decoder
  ) throws {
    let container: KeyedDecodingContainer<CodingKeys> =
      try decoder
      .container(
        keyedBy: CodingKeys.self
      )

    let fieldsContainer: KeyedDecodingContainer<DefinitionObjectCodingKeys> =
      try container
      .nestedContainer(
        keyedBy: DefinitionObjectCodingKeys.self,
        forKey: .resource
      )

    let fieldsDefinitionsContainer: KeyedDecodingContainer<AnyCodingKey> =
      try fieldsContainer
      .nestedContainer(
        keyedBy: AnyCodingKey.self,
        forKey: .properties
      )

    self.fields = try fieldsDefinitionsContainer.allKeys
      .map { key -> Field in
        try Field(
          name: key.stringValue,
          description:
            fieldsDefinitionsContainer
            .decode(
              FieldDescription.self,
              forKey: key
            )
        )
      }

    do {
      let secretFieldsContainer: KeyedDecodingContainer<DefinitionObjectCodingKeys> =
        try container
        .nestedContainer(
          keyedBy: DefinitionObjectCodingKeys.self,
          forKey: .secret
        )

      let secretFieldsDefinitionsContainer: KeyedDecodingContainer<AnyCodingKey> =
        try secretFieldsContainer
        .nestedContainer(
          keyedBy: AnyCodingKey.self,
          forKey: .properties
        )

      self.secretFields = try secretFieldsDefinitionsContainer.allKeys
        .map { key -> Field in
          try Field(
            name: key.stringValue,
            description:
              secretFieldsDefinitionsContainer
              .decode(
                FieldDescription.self,
                forKey: key
              )
          )
        }
    }
    catch {
      // try to decode legacy secret type
      self.secretFields = [
        try Field(
          name: "secret",
          description:
            container
            .decode(
              FieldDescription.self,
              forKey: .secret
            )
        )
      ]
    }
  }

  private enum CodingKeys: String, CodingKey {

    case resource = "resource"
    case secret = "secret"
  }

  private enum DefinitionObjectCodingKeys: String, CodingKey {

    case properties = "properties"
  }
}

private struct Field {

  fileprivate var name: String
  fileprivate var type: FieldType
  fileprivate var required: Bool
  fileprivate var maxLength: Int?

  fileprivate init(
    name: String,
    description: FieldDescription
  ) {
    self.name = name
    self.type = description.type
    self.required = description.required
    self.maxLength = description.maxLength
  }
}

private enum FieldType: String, Decodable {

  case null = "null"
  case string = "string"
}

private struct FieldDescription {

  fileprivate var type: FieldType
  fileprivate var required: Bool
  fileprivate var maxLength: Int?
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
      self.required = !oneOf.contains(where: { $0.type == .null })
      self.maxLength = description.maxLength
    }
    else {
      self.type =
        try container
        .decode(
          FieldType.self,
          forKey: .type
        )
      self.required = true
      self.maxLength =
        try container
        .decodeIfPresent(
          Int.self,
          forKey: .maxLength
        )
    }
  }

  private enum CodingKeys: String, CodingKey {

    case oneOf = "anyOf"
    case type = "type"
    case maxLength = "maxLength"
  }
}
