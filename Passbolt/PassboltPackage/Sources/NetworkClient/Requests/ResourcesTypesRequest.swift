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
import Environment

import struct Foundation.UUID

public typealias ResourcesTypesRequest = NetworkRequest<
  AuthorizedNetworkSessionVariable, ResourcesTypesRequestVariable, ResourcesTypesRequestResponse
>

extension ResourcesTypesRequest {

  internal static func live(
    using networking: Networking,
    with sessionVariablePublisher: AnyPublisher<AuthorizedNetworkSessionVariable, TheError>
  ) -> Self {
    Self(
      template: .init { sessionVariable, requestVariable in
        .combined(
          .url(string: sessionVariable.domain.rawValue),
          .path("/resource-types.json"),
          .header("Authorization", value: "Bearer \(sessionVariable.accessToken)"),
          .whenSome(
            sessionVariable.mfaToken,
            then: { mfaToken in
              .header("Cookie", value: "passbolt_mfa=\(mfaToken)")
            }
          ),
          .method(.get)
        )
      },
      responseDecoder: .bodyAsJSON(),
      using: networking,
      with: sessionVariablePublisher
    )
  }
}

public typealias ResourcesTypesRequestVariable = Void

public typealias ResourcesTypesRequestResponse = CommonResponse<ResourcesTypesRequestResponseBody>

public typealias ResourcesTypesRequestResponseBody = Array<ResourcesTypesRequestResponseBodyItem>

public struct ResourcesTypesRequestResponseBodyItem: Decodable {

  public var id: String
  public var slug: String
  public var name: String
  public var definition: Definition

  private enum CodingKeys: String, CodingKey {

    case id = "id"
    case name = "name"
    case slug = "slug"
    case definition = "definition"
  }
}

extension ResourcesTypesRequestResponseBodyItem {

  public struct Definition: Decodable {

    public var resourceProperties: Array<Property>
    public var secretProperties: Array<Property>

    public init(
      from decoder: Decoder
    ) throws {
      let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)

      let resourceContainer: KeyedDecodingContainer<DefinitionObjectCodingKeys> = try container.nestedContainer(
        keyedBy: DefinitionObjectCodingKeys.self,
        forKey: .resource
      )

      let resourcePropertiesContainer: KeyedDecodingContainer<AnyCodingKey> = try resourceContainer.nestedContainer(
        keyedBy: AnyCodingKey.self,
        forKey: .properties
      )
      self.resourceProperties = try resourcePropertiesContainer.allKeys
        .compactMap { key -> Property? in
          let propertyDescription: PropertyDescription = try resourcePropertiesContainer.decode(
            PropertyDescription.self,
            forKey: key
          )
          switch propertyDescription.type {
          case .string:
            return Property.string(
              name: key.stringValue,
              isOptional: propertyDescription.isOptional,
              maxLength: propertyDescription.maxLength
            )

          case .null:
            return nil
          }
        }

      do {
        let secretContainer: KeyedDecodingContainer<DefinitionObjectCodingKeys> = try container.nestedContainer(
          keyedBy: DefinitionObjectCodingKeys.self,
          forKey: .secret
        )
        let secretPropertiesContainer: KeyedDecodingContainer<AnyCodingKey> = try secretContainer.nestedContainer(
          keyedBy: AnyCodingKey.self,
          forKey: .properties
        )
        self.secretProperties = try secretPropertiesContainer.allKeys
          .compactMap { key -> Property? in
            let propertyDescription: PropertyDescription = try secretPropertiesContainer.decode(
              PropertyDescription.self,
              forKey: key
            )
            switch propertyDescription.type {
            case .string:
              return Property.string(
                name: key.stringValue,
                isOptional: propertyDescription.isOptional,
                maxLength: propertyDescription.maxLength
              )

            case .null:
              return nil
            }
          }
      }
      catch {
        do {
          // legacy secret type
          let propertyDescription: PropertyDescription = try container.decode(PropertyDescription.self, forKey: .secret)
          switch propertyDescription.type {
          case .string:
            self.secretProperties = [
              Property.string(
                name: "secret",
                isOptional: propertyDescription.isOptional,
                maxLength: propertyDescription.maxLength
              )
            ]

          case .null:
            self.secretProperties = []
          }
        }
        catch {
          throw error
        }
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
}

extension ResourcesTypesRequestResponseBodyItem.Definition {

  public enum Property {

    case string(name: String, isOptional: Bool, maxLength: Int?)
  }

  fileprivate enum PropertyType: String, Decodable {

    case null = "null"
    case string = "string"
  }

  fileprivate struct PropertyDescription: Decodable {

    fileprivate var type: PropertyType
    fileprivate var isOptional: Bool
    fileprivate var maxLength: Int?

    fileprivate init(from decoder: Decoder) throws {
      let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)
      if container.allKeys.contains(.oneOf) {
        let oneOf: Array<PropertyDescription> = try container.decode(Array<PropertyDescription>.self, forKey: .oneOf)
        guard let description: PropertyDescription = oneOf.first(where: { $0.type == .string })
        else {
          throw DecodingError.dataCorruptedError(
            forKey: .oneOf,
            in: container,
            debugDescription: "Unsupported or invalid property description"
          )
        }
        self.type = description.type
        self.isOptional = oneOf.contains(where: { $0.type == .null })
        self.maxLength = description.maxLength
      }
      else {
        self.type = try container.decode(PropertyType.self, forKey: .type)
        self.isOptional = false
        self.maxLength = try container.decodeIfPresent(Int.self, forKey: .maxLength)
      }
    }

    private enum CodingKeys: String, CodingKey {

      case oneOf = "anyOf"
      case type = "type"
      case maxLength = "maxLength"
    }
  }
}
