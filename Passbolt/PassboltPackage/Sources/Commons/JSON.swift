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

public enum JSON {

  case null
  case bool(Bool)
  case number(Double)
  case string(String)
  case array(Array<JSON>)
  case object(Dictionary<String, JSON>)
}

extension JSON: Equatable {}

extension JSON: Decodable {

  public init(
    from decoder: Decoder
  ) throws {
    let container = try decoder.singleValueContainer()

    if let string = try? container.decode(String.self) {
      self = .string(string)
    } else if let object = try? container.decode(Dictionary<String, JSON>.self) {
      self = .object(object)
    } else if let array = try? container.decode(Array<JSON>.self) {
      self = .array(array)
    } else if let bool = try? container.decode(Bool.self) {
      self = .bool(bool)
    } else if let number = try? container.decode(Double.self) {
      self = .number(number)
    } else if container.decodeNil() {
      self = .null
    } else {
      throw DecodingError
        .dataCorruptedError(
          in: container,
          debugDescription: "Invalid JSON!"
        )
    }
  }
}

extension JSON: Encodable {

  public func encode(
    to encoder: Encoder
  ) throws {
    var container = encoder.singleValueContainer()

    switch self {
    case let .string(string):
      try container.encode(string)
    case let .object(object):
      try container.encode(object)
    case let .array(array):
      try container.encode(array)
    case let .bool(bool):
      try container.encode(bool)
    case let .number(number):
      try container.encode(number)
    case .null:
      try container.encodeNil()
    }
  }
}
