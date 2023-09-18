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

import let os.CLOCK_MONOTONIC_RAW
import func os.clock_gettime_nsec_np

public struct UpdateGeneration: RawRepresentable {

  public static let uninitialized: Self = .init(rawValue: 0)

  @_transparent
  public static func next() -> UpdateGeneration {
    // using CLOCK_MONOTONIC_RAW allows monotonically
    // increasing value which has very low risk of duplication
    // across multiple instances, it is like very precise timestamp
    // of when update was sent, measured in CPU ticks
    UpdateGeneration(
      rawValue: clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)
    )
  }

  public typealias RawValue = UInt64

  @inline(__always) public let rawValue: RawValue

  @_transparent
  public init(
    rawValue: RawValue
  ) {
    self.rawValue = rawValue
  }
}

extension UpdateGeneration: Sendable {}

extension UpdateGeneration: Equatable {

  @_transparent public static func == (
    lhs: UpdateGeneration,
    rhs: UpdateGeneration
  ) -> Bool {
    lhs.rawValue == rhs.rawValue
  }

  @_transparent public static func != (
    lhs: UpdateGeneration,
    rhs: UpdateGeneration
  ) -> Bool {
    lhs.rawValue != rhs.rawValue
  }
}

extension UpdateGeneration: Hashable {

  @_transparent public func hash(
    into hasher: inout Hasher
  ) {
    hasher.combine(self.rawValue)
  }
}

extension UpdateGeneration: Comparable {

  @_transparent public static func < (
    lhs: UpdateGeneration,
    rhs: UpdateGeneration
  ) -> Bool {
    lhs.rawValue < rhs.rawValue
  }

  @_transparent public static func <= (
    lhs: UpdateGeneration,
    rhs: UpdateGeneration
  ) -> Bool {
    lhs.rawValue <= rhs.rawValue
  }

  @_transparent public static func > (
    lhs: UpdateGeneration,
    rhs: UpdateGeneration
  ) -> Bool {
    lhs.rawValue > rhs.rawValue
  }

  @_transparent public static func >= (
    lhs: UpdateGeneration,
    rhs: UpdateGeneration
  ) -> Bool {
    lhs.rawValue >= rhs.rawValue
  }
}
