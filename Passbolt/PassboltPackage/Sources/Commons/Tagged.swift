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

public struct Tagged<RawValue, Type>: RawRepresentable {

  public var rawValue: RawValue

  public init(
    rawValue: RawValue
  ) {
    self.rawValue = rawValue
  }
}

extension Tagged: CustomStringConvertible
where RawValue: CustomStringConvertible {

  public var description: String {
    rawValue.description
  }
}

extension Tagged: LosslessStringConvertible
where RawValue: LosslessStringConvertible {

  public init?(
    _ description: String
  ) {
    guard let rawValue = RawValue(description)
    else { return nil }
    self.init(rawValue: rawValue)
  }
}

extension Tagged: ExpressibleByUnicodeScalarLiteral
where RawValue: ExpressibleByUnicodeScalarLiteral {

  public init(
    unicodeScalarLiteral value: RawValue.UnicodeScalarLiteralType
  ) {
    self.init(
      rawValue: RawValue(
        unicodeScalarLiteral: value
      )
    )
  }
}

extension Tagged: ExpressibleByExtendedGraphemeClusterLiteral
where RawValue: ExpressibleByExtendedGraphemeClusterLiteral {

  public init(
    extendedGraphemeClusterLiteral value: RawValue.ExtendedGraphemeClusterLiteralType
  ) {
    self.init(
      rawValue: RawValue(
        extendedGraphemeClusterLiteral: value
      )
    )
  }
}

extension Tagged: ExpressibleByStringLiteral
where RawValue: ExpressibleByStringLiteral {

  public init(
    stringLiteral value: RawValue.StringLiteralType
  ) {
    self.init(
      rawValue: RawValue(
        stringLiteral: value
      )
    )
  }
}

extension Tagged: ExpressibleByStringInterpolation
where RawValue: ExpressibleByStringInterpolation {

  public init(
    stringInterpolation value: RawValue.StringInterpolation
  ) {
    self.init(
      rawValue: RawValue(
        stringInterpolation: value
      )
    )
  }
}

extension Tagged: ExpressibleByIntegerLiteral
where RawValue: ExpressibleByIntegerLiteral {

  public init(
    integerLiteral value: RawValue.IntegerLiteralType
  ) {
    self.init(
      rawValue: RawValue(
        integerLiteral: value
      )
    )
  }
}

extension Tagged: ExpressibleByFloatLiteral
where RawValue: ExpressibleByFloatLiteral {

  public init(
    floatLiteral value: RawValue.FloatLiteralType
  ) {
    self.init(
      rawValue: RawValue(
        floatLiteral: value
      )
    )
  }
}

extension Tagged: ExpressibleByNilLiteral
where RawValue: ExpressibleByNilLiteral {

  public init(
    nilLiteral: Void
  ) {
    self.init(
      rawValue: RawValue(
        nilLiteral: Void()
      )
    )
  }
}

extension Tagged: Encodable
where RawValue: Encodable {

  public func encode(to encoder: Encoder) throws {
    try rawValue.encode(to: encoder)
  }
}

extension Tagged: Decodable
where RawValue: Decodable {

  public init(from decoder: Decoder) throws {
    self.rawValue = try RawValue(from: decoder)
  }
}

extension Tagged: Equatable
where RawValue: Equatable {

  public static func == (
    _ lhs: RawValue,
    _ rhs: Tagged
  ) -> Bool {
    lhs == rhs.rawValue
  }

  public static func == (
    _ lhs: Tagged,
    _ rhs: RawValue
  ) -> Bool {
    lhs.rawValue == rhs
  }
}

extension Tagged: Hashable
where RawValue: Hashable {}

extension Tagged
where RawValue: Equatable {

  public static func ~= (
    _ lhs: RawValue,
    _ rhs: Tagged
  ) -> Bool {
    lhs == rhs.rawValue
  }
}

extension Tagged: Comparable
where RawValue: Comparable {

  public static func < (
    _ lhs: Self,
    _ rhs: Self
  ) -> Bool {
    lhs.rawValue < rhs.rawValue
  }
}

extension Tagged: AdditiveArithmetic
where RawValue: AdditiveArithmetic {

  public static var zero: Self {
    .init(rawValue: .zero)
  }

  public static func + (
    _ lhs: Self,
    _ rhs: Self
  ) -> Self {
    .init(
      rawValue: lhs.rawValue + rhs.rawValue
    )
  }

  public static func += (
    _ lhs: inout Self,
    _ rhs: Self
  ) {
    lhs.rawValue += rhs.rawValue
  }

  public static func - (
    _ lhs: Self,
    _ rhs: Self
  ) -> Self {
    .init(
      rawValue: lhs.rawValue - rhs.rawValue
    )
  }

  public static func -= (
    _ lhs: inout Self,
    _ rhs: Self
  ) {
    lhs.rawValue -= rhs.rawValue
  }
}

extension Tagged: Numeric
where RawValue: Numeric {

  public init?<Source>(
    exactly source: Source
  ) where Source: BinaryInteger {
    if let rawValue = RawValue(exactly: source) {
      self.init(rawValue: rawValue)
    }
    else {
      return nil
    }
  }

  public var magnitude: RawValue.Magnitude {
    self.rawValue.magnitude
  }

  public static func * (
    _ lhs: Self,
    _ rhs: Self
  ) -> Self {
    .init(
      rawValue: lhs.rawValue * rhs.rawValue
    )
  }

  public static func *= (
    _ lhs: inout Self,
    _ rhs: Self
  ) {
    lhs.rawValue *= rhs.rawValue
  }
}

extension Tagged: SignedNumeric
where RawValue: SignedNumeric {}

extension Tagged: Sequence
where RawValue: Sequence {

  public typealias Element = RawValue.Element
  public typealias Iterator = RawValue.Iterator

  public var underestimatedCount: Int { self.rawValue.underestimatedCount }

  public func makeIterator() -> Iterator {
    self.rawValue.makeIterator()
  }
}

extension Tagged: Collection
where RawValue: Collection {

  public typealias Index = RawValue.Index
  public typealias Indices = RawValue.Indices

  public var isEmpty: Bool { self.rawValue.isEmpty }
  public var count: Int { self.rawValue.count }

  public var startIndex: Index { self.rawValue.startIndex }
  public var endIndex: Index { self.rawValue.endIndex }

  public var indices: Indices { self.rawValue.indices }

  public func index(
    after idx: Index
  ) -> Index {
    self.rawValue.index(after: idx)
  }

  public subscript(
    position: Index
  ) -> Element {
    _read {
      yield self.rawValue[position]
    }
  }
}
