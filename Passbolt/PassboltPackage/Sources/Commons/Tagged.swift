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

public struct Tagged<RawValue: Hashable, Type>: Hashable, RawRepresentable {
  
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

extension Tagged {
  
  public static func ~= <RawValue: Hashable, Type>(
    _ lhs: RawValue,
    _ rhs: Tagged<RawValue, Type>
  ) -> Bool {
    lhs == rhs.rawValue
  }
}
