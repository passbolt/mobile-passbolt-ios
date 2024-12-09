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

import OrderedCollections

import struct Foundation.Data
import class Foundation.JSONEncoder

@dynamicMemberLookup
public enum JSON: Sendable {

  case null
  case bool(Bool)
  // JSON does not differentiate between float and integer
  // however it is helpful to make that distinction in swift
  case integer(Int)
  case float(Double)
  case string(String)
  case array(Array<JSON>)
  case object(Dictionary<String, JSON>)

  public static func integer(
    _ int: Int64
  ) -> Self {
    .integer(Int(int))
  }

  public static func integer(
    _ int: UInt
  ) -> Self {
    .integer(Int(int))
  }

  public static func integer(
    _ int: UInt64
  ) -> Self {
    .integer(Int(int))
  }

  public subscript(
    dynamicMember key: String
  ) -> JSON {
    get {
      switch self {
      case .object(let dictionary):
        return dictionary[key] ?? .null

      case .array(let array):
        if let index: Int = Int(key), array.count > index {
          return array[index]
        }
        else {
          return .null
        }

      case .null, .bool, .integer, .float, .string:
        return .null
      }
    }
    set {
      switch (self, newValue) {
      case (.object(var dictionary), let newValue):
        if case .null = newValue {
          // remove the value when assigning null
          dictionary[key] = .none
        }
        else {
          dictionary[key] = newValue
        }
        self = .object(dictionary)

      case (.array(var array), let newValue):
        guard let index: Int = Int(key)
        else {
          InternalInconsistency
            .error("JSON array index invalid!")
            .asAssertionFailure()
          return  // NOP
        }

        if array.count > index {
          if case .null = newValue {
            // remove the value when assigning null
            array.remove(at: index)
          }
          else {
            array.insert(newValue, at: index)
            array.remove(at: index + 1)
          }

          self = .array(array)
        }
        else if array.count == index {
          if case .null = newValue {
            // NOP - do not add value when assigning null
          }
          else {
            array.append(newValue)
          }

          self = .array(array)
        }
        else {
          InternalInconsistency
            .error("JSON array index out of bounds!")
            .asAssertionFailure()
          return  // NOP
        }

      case (.null, let newValue):
        if case .null = newValue {
          return  // do not set null inside null
        }
        else {
          self = .object([key: newValue])
        }

      case (.bool, _), (.integer, _), (.float, _), (.string, _):
        InternalInconsistency
          .error("JSON primitives can't take nested values!")
          .asAssertionFailure()
      }
    }
  }
}

extension JSON: Equatable {}

extension JSON: Decodable {

  public init(
    from decoder: Decoder
  ) throws {
    let container = try decoder.singleValueContainer()

    if let object = try? container.decode(Dictionary<String, JSON>.self) {
      self = .object(object)
    }
    else if let array = try? container.decode(Array<JSON>.self) {
      self = .array(array)
    }
    else if let string = try? container.decode(String.self) {
      self = .string(string)
    }
    else if let integer = try? container.decode(Int.self) {
      self = .integer(integer)
    }
    else if let float = try? container.decode(Double.self) {
      self = .float(float)
    }
    else if let bool = try? container.decode(Bool.self) {
      self = .bool(bool)
    }
    else if container.decodeNil() {
      self = .null
    }
    else {
      throw
        DecodingError
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
    case let .object(object):
      try container.encode(object)
    case let .array(array):
      try container.encode(array)
    case let .string(string):
      try container.encode(string)
    case let .integer(integer):
      try container.encode(integer)
    case let .float(float):
      try container.encode(float)
    case let .bool(bool):
      try container.encode(bool)
    case .null:
      try container.encodeNil()
    }
  }
}

extension JSON {

  public var boolValue: Bool? {
    switch self {
    case .bool(let value):
      return value

    case .integer(let value):
      return value != 0

    case .float(let value):
      return value != 0

    case .string:
      return .none

    case .object:
      return .none

    case .array:
      return .none

    case .null:
      return .none
    }
  }

  public var intValue: Int? {
    switch self {
    case .integer(let value):
      return value

    case .float(let value):
      return Int(value)

    case .string(let value):
      return Int(value)

    case .object:
      return .none

    case .array:
      return .none

    case .bool:
      return .none

    case .null:
      return .none
    }
  }

  public var int64Value: Int64? {
    switch self {
    case .integer(let value):
      return Int64(value)

    case .float(let value):
      return Int64(value)

    case .string(let value):
      return Int64(value)

    case .object:
      return .none

    case .array:
      return .none

    case .bool:
      return .none

    case .null:
      return .none
    }
  }

  public var uIntValue: UInt? {
    switch self {
    case .integer(let value):
      return UInt(value)

    case .float(let value):
      return UInt(value)

    case .string(let value):
      return UInt(value)

    case .object:
      return .none

    case .array:
      return .none

    case .bool:
      return .none

    case .null:
      return .none
    }
  }

  public var uInt64Value: UInt64? {
    switch self {
    case .integer(let value):
      return UInt64(value)

    case .float(let value):
      return UInt64(value)

    case .string(let value):
      return UInt64(value)

    case .object:
      return .none

    case .array:
      return .none

    case .bool:
      return .none

    case .null:
      return .none
    }
  }

  public var doubleValue: Double? {
    switch self {
    case .float(let value):
      return value

    case .integer(let value):
      return Double(value)

    case .string(let value):
      return Double(value)

    case .object:
      return .none

    case .array:
      return .none

    case .bool:
      return .none

    case .null:
      return .none
    }
  }

  public var stringValue: String? {
    switch self {
    case .string(let value):
      return value

    case .integer(let value):
      return "\(value)"

    case .float(let value):
      return "\(value)"

    case .object, .array:  // fallback for displaying unknown resource fields
      guard let encoded: Data = try? JSONEncoder.pretty.encode(self)
      else {
        assertionFailure("JSON is always a valid json")
        return .none
      }
      guard let string: String = .init(data: encoded, encoding: .utf8)
      else {
        assertionFailure("encoded json is always a valid utf8 string")
        return .none
      }
      return string

    case .bool:
      return .none

    case .null:
      return .none
    }
  }
  
  public var arrayValue: [JSON]? {
    guard case .array(let array) = self
    else {
      return .none
    }
    return array
  }
}

extension JSON: ExpressibleByNilLiteral {

  public init(
    nilLiteral: Void
  ) {
    self = .null
  }
}

extension JSON: ExpressibleByArrayLiteral {

  public init(
    arrayLiteral elements: JSON...
  ) {
    self = .array(elements)
  }
}

extension JSON: ExpressibleByDictionaryLiteral {

  public init(
    dictionaryLiteral elements: (String, JSON)...
  ) {
    self = .object(.init(uniqueKeysWithValues: elements))
  }
}

extension JSON: ExpressibleByStringLiteral {

  public init(
    stringLiteral value: String
  ) {
    self = .string(value)
  }
}

extension JSON: ExpressibleByBooleanLiteral {

  public init(
    booleanLiteral value: Bool
  ) {
    self = .bool(value)
  }
}

extension JSON: ExpressibleByIntegerLiteral {

  public init(
    integerLiteral value: Int
  ) {
    self = .integer(value)
  }
}

extension JSON: ExpressibleByFloatLiteral {

  public init(
    floatLiteral value: Double
  ) {
    self = .float(value)
  }
}

extension JSON {

  public var resourceSecretString: String? {
    switch self {
    case .array, .object:
      guard let encoded: Data = try? JSONEncoder.default.encode(self)
      else {
        assertionFailure("JSON is always a valid json")
        return .none
      }
      guard let string: String = .init(data: encoded, encoding: .utf8)
      else {
        assertionFailure("encoded json is always a valid utf8 string")
        return .none
      }
      return string

    case .string(let value):
      return value

    case .null:
      return .none

    case .integer(let value):
      return "\(value)"

    case .float(let value):
      return "\(value)"

    case .bool(let value):
      return value ? "true" : "false"
    }
  }

  // remove value if able or set it to null
  public mutating func remove() {
    self = .null
  }
}
