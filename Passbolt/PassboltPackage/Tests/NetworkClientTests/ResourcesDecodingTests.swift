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

import Accounts
import XCTest

@testable import NetworkClient

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class ResourcesDecodingTests: XCTestCase {

  func test_resourceTypesDecoding_withLegacySecret() {
    let rawJSON: Data = """
      {
        "id": "669f8c64-242a-59fb-92fc-81f660975fd3",
        "name": "Simple password",
        "slug": "simple-password",
        "definition": {
          "resource": {
          "type": "object",
          "required": ["name"],
          "properties": {
              "name": {
                "type": "string",
                "maxLength": 64
              },
              "username": {
                "anyOf": [
                  {
                    "type": "string",
                    "maxLength": 64
                  },
                  {
                    "type": "null"
                  }
                ]
              },
              "uri": {
                "anyOf": [
                  {
                    "type": "string",
                    "maxLength": 1024
                  },
                  {
                    "type": "null"
                  }
                ]
              },
              "description": {
                "anyOf": [
                  {
                    "type": "string",
                    "maxLength": 10000
                  },
                  {
                    "type": "null"
                  }
                ]
              }
            }
          },
          "secret": {
            "type": "string",
            "maxLength": 4064
          }
        }
      }
      """.data(using: .utf8)!

    let decodedData: ResourceTypeDTO? = try? JSONDecoder().decode(
      ResourceTypeDTO.self,
      from: rawJSON
    )

    XCTAssertEqual(decodedData?.id, "669f8c64-242a-59fb-92fc-81f660975fd3")
    XCTAssertEqual(decodedData?.name, "Simple password")
    XCTAssertEqual(decodedData?.slug, "simple-password")
    XCTAssertTrue(
      decodedData?.fields.contains(where: { field in
        return field.valueType == .string
          && field.name == .name
          && field.required == true
          && field.encrypted == false
          && field.maxLength == 64
      }) ?? false
    )
    XCTAssertTrue(
      decodedData?.fields.contains(where: { field in
        field.valueType == .string
          && field.name == .username
          && field.required == false
          && field.encrypted == false
          && field.maxLength == 64
      }) ?? false
    )
    XCTAssertTrue(
      decodedData?.fields.contains(where: { field in
        field.valueType == .string
          && field.name == .uri
          && field.required == false
          && field.encrypted == false
          && field.maxLength == 1024
      }) ?? false
    )
    XCTAssertTrue(
      decodedData?.fields.contains(where: {
        field in
        field.valueType == .string
          && field.name == .description
          && field.required == false
          && field.encrypted == false
          && field.maxLength == 10000
      }) ?? false
    )
    XCTAssertTrue(
      decodedData?.fields.contains(where: { field in
        field.valueType == .string
          && field.name == .password
          && field.required == true
          && field.encrypted == true
          && field.maxLength == 4064
      }) ?? false
    )
  }

  func test_resourceTypesDecoding_withSecretContainingDescription() {
    let rawJSON: Data = """
      {
        "id": "669f8c64-242a-59fb-92fc-81f660975fd3",
        "name": "Simple password",
        "slug": "simple-password",
        "definition": {
          "resource": {
          "type": "object",
          "required": ["name"],
          "properties": {
              "name": {
                "type": "string",
                "maxLength": 64
              },
              "username": {
                "anyOf": [
                  {
                    "type": "string",
                    "maxLength": 64
                  },
                  {
                    "type": "null"
                  }
                ]
              },
              "uri": {
                "anyOf": [
                  {
                    "type": "string",
                    "maxLength": 1024
                  },
                  {
                    "type": "null"
                  }
                ]
              },
              "description": {
                "anyOf": [
                  {
                    "type": "string",
                    "maxLength": 10000
                  },
                  {
                    "type": "null"
                  }
                ]
              }
            }
          },
          "secret": {
            "type": "object",
            "required": [
              "password"
            ],
            "properties": {
              "password": {
                 "type": "string",
                 "maxLength": 4096
               },
               "description": {
                 "anyOf": [
                   {
                     "type": "string",
                     "maxLength": 10000
                   },
                   {
                     "type": "null"
                   }
                 ]
               }
             }
           }
        }
      }
      """.data(using: .utf8)!

    let decodedData: ResourceTypeDTO? = try? JSONDecoder().decode(
      ResourceTypeDTO.self,
      from: rawJSON
    )

    XCTAssertEqual(decodedData?.id, "669f8c64-242a-59fb-92fc-81f660975fd3")
    XCTAssertEqual(decodedData?.name, "Simple password")
    XCTAssertEqual(decodedData?.slug, "simple-password")
    XCTAssertTrue(
      decodedData?.fields.contains(where: { field in
        return field.valueType == .string
          && field.name == .name
          && field.required == true
          && field.encrypted == false
          && field.maxLength == 64
      }) ?? false
    )
    XCTAssertTrue(
      decodedData?.fields.contains(where: { field in
        field.valueType == .string
          && field.name == .username
          && field.required == false
          && field.encrypted == false
          && field.maxLength == 64
      }) ?? false
    )
    XCTAssertTrue(
      decodedData?.fields.contains(where: { field in
        field.valueType == .string
          && field.name == .uri
          && field.required == false
          && field.encrypted == false
          && field.maxLength == 1024
      }) ?? false
    )
    XCTAssertTrue(
      decodedData?.fields.contains(where: { field in
        field.valueType == .string
          && field.name == .description
          && field.required == false
          && field.encrypted == false
          && field.maxLength == 10000
      }) ?? false
    )
    XCTAssertTrue(
      decodedData?.fields.contains(where: { field in
        field.valueType == .string
          && field.name == .password
          && field.required == true
          && field.encrypted == true
          && field.maxLength == 4096
      }) ?? false
    )
  }

  func test_resourcesDecoding() {
    let rawJSON: Data = """
      {
        "id": "daaf057e-7fc3-5537-a8a9-e8c151890878",
        "name": "cakephp",
        "username": "cake",
        "uri": "cakephp.org",
        "description": "The rapid and tasty php development framework",
        "resource_type_id": "e2aa01a9-84ec-55f8-aaed-24ee23259339",
        "permission": {
          "type": 15
        },
        "favorite": null,
        "modified": "2022-02-15T13:28:15+00:00",
        "permissions": [
          {
            "aco": "Resource",
            "aco_foreign_key": "03c81a81-0cf0-4463-a693-7ea49401af92",
            "aro": "User",
            "aro_foreign_key": "c793731e-27a7-43be-badf-ea60760a64e4",
            "type": 1
          }
        ]
      }
      """.data(using: .utf8)!

    let decodedData: ResourceDTO
    do {
      let decoder: JSONDecoder = .init()
      decoder.dateDecodingStrategy = .iso8601
      decodedData = try decoder.decode(
        ResourceDTO.self,
        from: rawJSON
      )
    }
    catch {
      return XCTFail("Unexpected error: \(error)")
    }

    XCTAssertEqual(decodedData.id, "daaf057e-7fc3-5537-a8a9-e8c151890878")
    XCTAssertEqual(decodedData.name, "cakephp")
    XCTAssertEqual(decodedData.username, "cake")
    XCTAssertEqual(decodedData.url, "cakephp.org")
    XCTAssertEqual(decodedData.description, "The rapid and tasty php development framework")
    XCTAssertEqual(decodedData.typeID, "e2aa01a9-84ec-55f8-aaed-24ee23259339")
    XCTAssertEqual(decodedData.permissionType, .owner)
    XCTAssertEqual(decodedData.favorite, false)
    XCTAssertEqual(decodedData.modified, .init(timeIntervalSince1970: 1_644_931_695))
    XCTAssertEqual(
      decodedData.permissions,
      [
        .userToResource(
          userID: "c793731e-27a7-43be-badf-ea60760a64e4",
          resourceID: "03c81a81-0cf0-4463-a693-7ea49401af92",
          type: .read
        )
      ]
    )
  }
}
