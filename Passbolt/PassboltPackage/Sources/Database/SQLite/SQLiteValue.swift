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

public enum SQLiteValue {

  case null
  case bool(Bool)
  case int(Int)
  case double(Double)
  case string(String)
  case date(Date)
  case data(Data)
}

public protocol SQLiteValueConvertible {

  var asSQLiteValue: SQLiteValue { get }
}

extension SQLiteValue: SQLiteValueConvertible {

  public var asSQLiteValue: SQLiteValue {
    self
  }
}

extension Optional: SQLiteValueConvertible
where Wrapped: SQLiteValueConvertible {

  public var asSQLiteValue: SQLiteValue {
    switch self {
    case let .some(value):
      return value.asSQLiteValue

    case .none:
      return .null
    }
  }
}

extension Tagged: SQLiteValueConvertible
where RawValue: SQLiteValueConvertible {

  public var asSQLiteValue: SQLiteValue {
    self.rawValue.asSQLiteValue
  }
}

extension Bool: SQLiteValueConvertible {

  public var asSQLiteValue: SQLiteValue {
    .bool(self)
  }
}

extension Int: SQLiteValueConvertible {

  public var asSQLiteValue: SQLiteValue {
    .int(self)
  }
}

extension UInt: SQLiteValueConvertible {

  public var asSQLiteValue: SQLiteValue {
    .int(Int(self))
  }
}

extension Int64: SQLiteValueConvertible {

  public var asSQLiteValue: SQLiteValue {
    .int(Int(self))
  }
}

extension Double: SQLiteValueConvertible {

  public var asSQLiteValue: SQLiteValue {
    .double(self)
  }
}

extension String: SQLiteValueConvertible {

  public var asSQLiteValue: SQLiteValue {
    .string(self)
  }
}

extension Date: SQLiteValueConvertible {

  public var asSQLiteValue: SQLiteValue {
    .date(self)
  }
}

extension UUID: SQLiteValueConvertible {

	public var asSQLiteValue: SQLiteValue {
		.data(
			Data([
				self.uuid.0,
				self.uuid.1,
				self.uuid.2,
				self.uuid.3,
				self.uuid.4,
				self.uuid.5,
				self.uuid.6,
				self.uuid.7,
				self.uuid.8,
				self.uuid.9,
				self.uuid.10,
				self.uuid.11,
				self.uuid.12,
				self.uuid.13,
				self.uuid.14,
				self.uuid.15
			])
		)
	}
}

extension Data: SQLiteValueConvertible {

  public var asSQLiteValue: SQLiteValue {
    .data(self)
  }
}

extension SQLiteValue: ExpressibleByNilLiteral {

  public init(
    nilLiteral: Void
  ) {
    self = .null
  }
}

extension SQLiteValue: ExpressibleByBooleanLiteral {

  public init(
    booleanLiteral value: Bool
  ) {
    self = .bool(value)
  }
}

extension SQLiteValue: ExpressibleByIntegerLiteral {

  public init(
    integerLiteral value: Int
  ) {
    self = .int(value)
  }
}

extension SQLiteValue: ExpressibleByFloatLiteral {

  public init(
    floatLiteral value: Double
  ) {
    self = .double(value)
  }
}

extension SQLiteValue: ExpressibleByStringLiteral {

  public init(
    stringLiteral value: StaticString
  ) {
    self = .string(value.description)
  }
}
