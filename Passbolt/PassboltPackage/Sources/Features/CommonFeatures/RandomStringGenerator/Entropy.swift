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

public struct Entropy: RawRepresentable, Strideable, Equatable {
  public typealias Stride = Double

  public var rawValue: Double

  public init(rawValue: Double) {
    assert(rawValue >= 0)
    self.rawValue = rawValue
  }

  public func distance(to other: Entropy) -> Double {
    other.rawValue - self.rawValue
  }

  public func advanced(by n: Double) -> Entropy {
    .init(rawValue: self.rawValue + n)
  }
}

extension Entropy: Comparable {

  public static func < (lhs: Entropy, rhs: Entropy) -> Bool {
    lhs.rawValue < rhs.rawValue
  }
}

extension Entropy {

  public static let zero: Self = .init(rawValue: 0)
  public static let veryWeakPassword: Self = .init(rawValue: 1)
  public static let weakPassword: Self = .init(rawValue: 60)
  public static let fairPassword: Self = .init(rawValue: 80)
  public static let strongPassword: Self = .init(rawValue: 112)
  public static let veryStrongPassword: Self = .init(rawValue: 128)
  public static let greatestFinite: Self = .init(rawValue: Double.greatestFiniteMagnitude)
}


