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
import XCTest

final class JSONTests: XCTestCase {

  func test_decoding() throws {
    let json: JSON = try JSONDecoder()
      .decode(
        JSON.self,
        from: """
          				{
          					"string": "answer",
          					"number": 42,
          					"nested": {
          						"nestedString": "nestedAnswer",
          						"nestedNumber": 8
          					},
          					"array": [
          						42,
          						{
          							"nestedInArrayString": "nestedInArrayAnswer",
          							"nestedInArrayNumber": 39
          						}
          					]
          				}
          				"""
          .data(using: .utf8)!
      )

    XCTAssertEqual(
      json,
      .object([
        "string": .string("answer"),
        "number": .integer(42),
        "nested": .object([
          "nestedString": .string("nestedAnswer"),
          "nestedNumber": .integer(8),
        ]),
        "array": .array([
          .integer(42),
          .object([
            "nestedInArrayString": .string("nestedInArrayAnswer"),
            "nestedInArrayNumber": .integer(39),
          ]),
        ]),
      ])
    )
  }

  func test_literals() throws {
    let json: JSON = [
      "string": "answer",
      "number": 42,
      "nested": [
        "nestedString": "nestedAnswer",
        "nestedNumber": 8,
      ],
      "array": [
        42,
        [
          "nestedInArrayString": "nestedInArrayAnswer",
          "nestedInArrayNumber": 39,
        ],
      ],
    ]

    XCTAssertEqual(
      json,
      .object([
        "string": .string("answer"),
        "number": .integer(42),
        "nested": .object([
          "nestedString": .string("nestedAnswer"),
          "nestedNumber": .integer(8),
        ]),
        "array": .array([
          .integer(42),
          .object([
            "nestedInArrayString": .string("nestedInArrayAnswer"),
            "nestedInArrayNumber": .integer(39),
          ]),
        ]),
      ])
    )
  }

  func test_encoding() throws {
    let json: JSON = [
      "string": "answer",
      "number": 42,
      "nested": [
        "nestedString": "nestedAnswer",
        "nestedNumber": 8,
      ],
      "array": [
        42,
        [
          "nestedInArrayString": "nestedInArrayAnswer",
          "nestedInArrayNumber": 39,
        ],
      ],
    ]

    let encoded: Data = try JSONEncoder().encode(json)
    let decoded: JSON = try JSONDecoder().decode(JSON.self, from: encoded)

    XCTAssertEqual(
      json,
      decoded
    )
  }

  func test_paths() throws {
    let json: JSON = try JSONDecoder()
      .decode(
        JSON.self,
        from: """
          				{
          					"string": "answer",
          					"number": 42,
          					"nested": {
          						"nestedString": "nestedAnswer",
          						"nestedNumber": 8.5
          					},
          					"array": [
          						true,
          						{
          							"nestedInArrayString": "nestedInArrayAnswer",
          							"nestedInArrayNumber": 39
          						}
          					]
          				}
          				"""
          .data(using: .utf8)!
      )

    XCTAssertEqual(json.string.stringValue, "answer")
    XCTAssertEqual(json.number.intValue, 42)
    XCTAssertEqual(json.nested.nestedString.stringValue, "nestedAnswer")
    XCTAssertEqual(json.nested.nestedNumber.doubleValue, 8.5)
    XCTAssertEqual(json.array.0.boolValue, true)
    XCTAssertEqual(json.array.1.nestedInArrayString.stringValue, "nestedInArrayAnswer")
    XCTAssertEqual(json.array.1.nestedInArrayNumber.intValue, 39)
  }

  func test_pathAssignment() throws {
    var json: JSON = .null

    json.string = "answer"
    json.number = 42
    json.nested.nestedString = "nestedAnswer"
    json.nested.nestedNumber = 8.5
    json.array = []
    json.array.0 = true
    json.array.1.nestedInArrayString = "nestedInArrayAnswer"
    json.array.1.nestedInArrayNumber = 39
    XCTAssertEqual(json.string.stringValue, "answer")
    XCTAssertEqual(json.number.intValue, 42)
    XCTAssertEqual(json.nested.nestedString.stringValue, "nestedAnswer")
    XCTAssertEqual(json.nested.nestedNumber.doubleValue, 8.5)
    XCTAssertEqual(json.array.0.boolValue, true)
    XCTAssertEqual(json.array.1.nestedInArrayString.stringValue, "nestedInArrayAnswer")
    XCTAssertEqual(json.array.1.nestedInArrayNumber.intValue, 39)
  }

  func test_resourceSecretString() throws {
    let json: JSON = [
      "string": "ans\"\\wer",
      "number": 42,
    ]

    XCTAssertEqual(
      try JSONDecoder()
        .decode(
          JSON.self,
          from: json
            .resourceSecretString!
            .data(using: .utf8)!
        ),
      json
    )

    let jsonString: JSON = "string"

    XCTAssertEqual(
      jsonString.resourceSecretString,
      "string"
    )
  }
}
