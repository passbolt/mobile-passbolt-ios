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

import struct Foundation.Data
import struct Foundation.Date

public struct SQLiteStatement {

  internal private(set) var rawString: String
  internal private(set) var arguments: SQLiteStatementArguments

  private init(
    rawString: String,
    arguments: SQLiteStatementArguments
  ) {
    self.rawString = rawString
    self.arguments = arguments
  }

  public static func statement(
    _ string: StaticString,
    arguments: SQLiteValueConvertible...
  ) -> Self {
    .init(
      string,
      arguments: .init(
        arguments: arguments.map(\.asSQLiteValue)
      )
    )
  }

  @_disfavoredOverload
  public init(
    _ string: StaticString,
    arguments: SQLiteStatementArguments
  ) {
    self.rawString = string.description
    self.arguments = arguments
  }
}

extension SQLiteStatement {

  public mutating func append(
    _ other: SQLiteStatement?
  ) {
    self.rawString.append("\n\(other?.rawString ?? "")")
    self.arguments.append(other?.arguments)
  }

  public func appending(
    _ other: SQLiteStatement?
  ) -> SQLiteStatement {
    var copy: Self = self
    copy.append(other)
    return copy
  }

  public static func + (
    _ lhs: SQLiteStatement,
    _ rhs: SQLiteStatement
  ) -> SQLiteStatement {
    lhs.appending(rhs)
  }
}

extension SQLiteStatement: ExpressibleByStringLiteral {

  public init(
    stringLiteral value: StaticString
  ) {
    self.init(
      rawString: value.description,
      arguments: .init()
    )
  }
}

extension SQLiteStatement: CustomStringConvertible {

  public var description: String { self.rawString }
}

extension SQLiteStatement: CustomDebugStringConvertible {

  public var debugDescription: String {
    "SQL: \(self.rawString)\nArguments:\(self.arguments)"
  }
}

extension SQLiteStatement {

  public mutating func appendArguments(
    _ head: SQLiteValueConvertible,
    _ tail: SQLiteValueConvertible...
  ) {
    self.arguments.append([head] + tail)
  }

  public mutating func appendArgument(
    _ argument: SQLiteValueConvertible
  ) {
    self.arguments.append(argument)
  }

  public func appendingArgument(
    _ argument: SQLiteValueConvertible
  ) -> Self {
    var copy: Self = self
    copy.appendArgument(argument)
    return copy
  }

  public mutating func appendArgument(
    _ value: Bool
  ) {
    self.arguments.append(value)
  }

  public mutating func appendArgument(
    _ value: Int
  ) {
    self.arguments.append(value)
  }

  public mutating func appendArgument<Value>(
    _ value: Value
  ) where Value: RawRepresentable, Value.RawValue == Int {
    self.arguments.append(value.rawValue)
  }

  public mutating func appendArgument(
    _ value: Double
  ) {
    self.arguments.append(value)
  }

  public mutating func appendArgument(
    _ value: String
  ) {
    self.arguments.append(value)
  }

  public mutating func appendArgument<Value>(
    _ value: Value
  ) where Value: RawRepresentable, Value.RawValue == String {
    self.arguments.append(value.rawValue)
  }

  public mutating func appendArgument(
    _ value: Date
  ) {
    self.arguments.append(value)
  }

  public mutating func appendArgument(
    _ value: Data
  ) {
    self.arguments.append(value)
  }

  public mutating func appendArgument<Value>(
    _ value: Value
  ) where Value: RawRepresentable, Value.RawValue == Data {
    self.arguments.append(value.rawValue)
  }
}
