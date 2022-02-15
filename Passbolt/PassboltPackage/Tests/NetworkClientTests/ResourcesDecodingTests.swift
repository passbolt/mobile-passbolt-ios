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

    let decodedData: ResourcesTypesRequestResponseBodyItem? = try? JSONDecoder().decode(
      ResourcesTypesRequestResponseBodyItem.self,
      from: rawJSON
    )

    XCTAssertEqual(decodedData?.id, "669f8c64-242a-59fb-92fc-81f660975fd3")
    XCTAssertEqual(decodedData?.name, "Simple password")
    XCTAssertEqual(decodedData?.slug, "simple-password")
    XCTAssertTrue(
      decodedData?.definition.resourceProperties.contains(where: {
        switch $0 {
        case let .string(name, isOptional, maxLength):
          return name == "name"
            && isOptional == false
            && maxLength == 64
        }
      }) ?? false
    )
    XCTAssertTrue(
      decodedData?.definition.resourceProperties.contains(where: {
        switch $0 {
        case let .string(name, isOptional, maxLength):
          return name == "username"
            && isOptional == true
            && maxLength == 64
        }
      }) ?? false
    )
    XCTAssertTrue(
      decodedData?.definition.resourceProperties.contains(where: {
        switch $0 {
        case let .string(name, isOptional, maxLength):
          return name == "uri"
            && isOptional == true
            && maxLength == 1024
        }
      }) ?? false
    )
    XCTAssertTrue(
      decodedData?.definition.resourceProperties.contains(where: {
        switch $0 {
        case let .string(name, isOptional, maxLength):
          return name == "description"
            && isOptional == true
            && maxLength == 10000
        }
      }) ?? false
    )
    XCTAssertTrue(
      decodedData?.definition.secretProperties.contains(where: {
        switch $0 {
        case let .string(name, isOptional, maxLength):
          return name == "secret"
            && isOptional == false
            && maxLength == 4064
        }
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

    let decodedData: ResourcesTypesRequestResponseBodyItem? = try? JSONDecoder().decode(
      ResourcesTypesRequestResponseBodyItem.self,
      from: rawJSON
    )

    XCTAssertEqual(decodedData?.id, "669f8c64-242a-59fb-92fc-81f660975fd3")
    XCTAssertEqual(decodedData?.name, "Simple password")
    XCTAssertEqual(decodedData?.slug, "simple-password")
    XCTAssertTrue(
      decodedData?.definition.resourceProperties.contains(where: {
        switch $0 {
        case let .string(name, isOptional, maxLength):
          return name == "name"
            && isOptional == false
            && maxLength == 64
        }
      }) ?? false
    )
    XCTAssertTrue(
      decodedData?.definition.resourceProperties.contains(where: {
        switch $0 {
        case let .string(name, isOptional, maxLength):
          return name == "username"
            && isOptional == true
            && maxLength == 64
        }
      }) ?? false
    )
    XCTAssertTrue(
      decodedData?.definition.resourceProperties.contains(where: {
        switch $0 {
        case let .string(name, isOptional, maxLength):
          return name == "uri"
            && isOptional == true
            && maxLength == 1024
        }
      }) ?? false
    )
    XCTAssertTrue(
      decodedData?.definition.secretProperties.contains(where: {
        switch $0 {
        case let .string(name, isOptional, maxLength):
          return name == "description"
            && isOptional == true
            && maxLength == 10000
        }
      }) ?? false
    )
    XCTAssertTrue(
      decodedData?.definition.secretProperties.contains(where: {
        switch $0 {
        case let .string(name, isOptional, maxLength):
          return name == "password"
            && isOptional == false
            && maxLength == 4096
        }
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
        "modified": "2022-02-15T13:28:15+00:00"
      }
      """.data(using: .utf8)!

    let decodedData: ResourcesRequestResponseBodyItem
    do {
      let decoder: JSONDecoder = .init()
      decoder.dateDecodingStrategy = .iso8601
      decodedData = try decoder.decode(
        ResourcesRequestResponseBodyItem.self,
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
    XCTAssertEqual(decodedData.resourceTypeID, "e2aa01a9-84ec-55f8-aaed-24ee23259339")
    XCTAssertEqual(decodedData.permission, .owner)
    XCTAssertEqual(decodedData.favorite, false)
    XCTAssertEqual(decodedData.modified, .init(timeIntervalSince1970: 1_644_931_695))
  }
}
