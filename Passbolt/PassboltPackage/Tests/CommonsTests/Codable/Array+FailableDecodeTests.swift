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

import XCTest

internal final class ArrayFailableDecodeTests: XCTestCase {

  internal func test_defaultDecoding_failsWithError() throws {
    let decoder: JSONDecoder = .init()
    do {
      _ = try decoder.decode(DefaultDecoder.self, from: json)
    }
    catch let error as DecodingError {
      if case .valueNotFound = error {
        // Expected error
      }
      else {
        XCTFail("Unexpected DecodingError case: \(error)")
      }
    }
    catch {
      XCTFail("Unexpected error type: \(error)")
    }
  }

  internal func test_failableDecoding_succeedsWithPartialResults() throws {
    let decoder: JSONDecoder = .init()

    let result: FailableDecoder = try decoder.decode(
      FailableDecoder.self,
      from: json
    )

    XCTAssertEqual(
      result.items.count,
      1,
      "Expected only one item to be decoded successfully"
    )
    XCTAssertEqual(
      result.items.first?.id,
      "A",
      "Expected the successfully decoded item to have id 'A'"
    )
  }

  private let sampleJSONString: String = """
    [
      {
        "id": "A",
        "nested": {
          "name": "Item A"
        }
      },
      {
        "id": "B",
        "nested": {
          "name": null
        }
      },
      {
        "id": "C",
        "nested": null
      }
    ]
    """

  private var json: Data {
    .init(self.sampleJSONString.utf8)
  }

  private struct TestItem: Decodable {
    let id: String
    let nested: Nested

    struct Nested: Decodable {
      let name: String
    }
  }

  private struct DefaultDecoder: Decodable {
    let items: Array<TestItem>

    init(from decoder: Decoder) throws {
      self.items = try Array<TestItem>(from: decoder)
    }
  }

  private struct FailableDecoder: Decodable {

    let items: Array<TestItem>

    init(from decoder: Decoder) throws {
      self.items = try .failableDecode(from: decoder)
    }
  }
}
