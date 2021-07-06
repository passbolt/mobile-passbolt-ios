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

public struct Validated<Value> {

  public let value: Value
  public private(set) var errors: Array<TheError>

  public init(
    value: Value,
    errors: Array<TheError>
  ) {
    self.value = value
    self.errors = errors
  }

  public var isValid: Bool { errors.isEmpty }

  public func withError(_ error: TheError) -> Self {
    var copy: Self = self
    copy.errors.append(error)
    return copy
  }

  public func withErrors<Errors>(
    _ errors: Errors
  ) -> Self
  where Errors: Sequence, Errors.Element == TheError {
    var copy: Self = self
    copy.errors.append(contentsOf: errors)
    return copy
  }
}

extension Validated {

  public static func valid(_ value: Value) -> Self {
    Self(
      value: value,
      errors: []
    )
  }

  public static func invalid(
    _ value: Value,
    errors: TheError...
  ) -> Self {
    Self(
      value: value,
      errors: errors
    )
  }
}
