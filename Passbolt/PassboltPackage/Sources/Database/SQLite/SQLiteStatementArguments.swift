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

public struct SQLiteStatementArguments {

  public private(set) var arguments: Array<SQLiteValue>
}

extension SQLiteStatementArguments {

  public init() {
    self.arguments = .init()
  }

  public mutating func append(
    _ other: SQLiteStatementArguments?
  ) {
    self.arguments.append(contentsOf: other?.arguments ?? .init())
  }

  public func appending(
    _ other: SQLiteStatementArguments?
  ) -> SQLiteStatementArguments {
    var copy: Self = self
    copy.append(other)
    return copy
  }

  @_disfavoredOverload
  public mutating func append(
    _ argument: SQLiteValue
  ) {
    self.arguments.append(argument)
  }

  @_disfavoredOverload
  public mutating func append(
    _ argument: SQLiteValueConvertible
  ) {
    self.arguments.append(argument.asSQLiteValue)
  }

  @_disfavoredOverload
  public mutating func append(
    _ head: SQLiteValueConvertible,
    _ tail: SQLiteValueConvertible...
  ) {
    self.append([head] + tail)
  }

  @_disfavoredOverload
  public mutating func append(
    _ arguments: Array<SQLiteValueConvertible>
  ) {
    self.arguments.append(contentsOf: arguments.map(\.asSQLiteValue))
  }

  public mutating func append(
    _ value: Bool
  ) {
    self.arguments.append(.bool(value))
  }

  public mutating func append(
    _ value: Int
  ) {
    self.arguments.append(.int(value))
  }

  public mutating func append(
    _ value: Double
  ) {
    self.arguments.append(.double(value))
  }

  public mutating func append(
    _ value: String
  ) {
    self.arguments.append(.string(value))
  }

  public mutating func append(
    _ value: Date
  ) {
    self.arguments.append(.date(value))
  }

  public mutating func append(
    _ value: Data
  ) {
    self.arguments.append(.data(value))
  }
}

extension SQLiteStatementArguments: ExpressibleByArrayLiteral {

  public init(
    arrayLiteral elements: SQLiteValueConvertible...
  ) {
    self.arguments = elements.map(\.asSQLiteValue)
  }
}
