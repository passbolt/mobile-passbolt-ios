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

import Localization

public struct Validated<Value> {

  public var value: Value
  public private(set) var error: TheError?

  public init(
    value: Value,
    error: TheError?
  ) {
    self.value = value
    self.error = error
  }

  public var validValue: Value {
    get throws {
      if let error: TheError = self.error {
        throw error
      }
      else {
        return self.value
      }
    }
  }

  public var isValid: Bool { error == nil }

  public var displayableErrorMessage: DisplayableString? {
    error?.displayableMessage
  }
}

extension Validated {

  public static func valid(
    _ value: Value
  ) -> Self {
    Self(
      value: value,
      error: .none
    )
  }

  public static func invalid(
    _ value: Value,
    error: TheError
  ) -> Self {
    Self(
      value: value,
      error: error
    )
  }

  public static func invalid(
    message: StaticString = "InvalidValue",
    validationRule: StaticString,
    value: Value,
    displayable: DisplayableString,
    file: StaticString = #fileID,
    line: UInt = #line
  ) -> Self {
    Self(
      value: value,
      error: InvalidValue.error(
        message,
        validationRule: validationRule,
        value: value,
        displayable: displayable,
        file: file,
        line: line
      )
    )
  }
}

extension Validated: Equatable
where Value: Equatable {

  public static func == (
    _ lhs: Validated,
    _ rhs: Validated
  ) -> Bool {
    lhs.value == rhs.value
      && lhs.displayableErrorMessage == rhs.displayableErrorMessage
  }
}

extension Validated: Hashable
where Value: Hashable {
  public func hash(
    into hasher: inout Hasher
  ) {
    hasher.combine(self.value)
    hasher.combine(self.isValid)
  }
}

extension Validated {

  public func map<NewValue>(
    _ transform: @escaping (Value) -> NewValue
  ) -> Validated<NewValue> {
    .init(
      value: transform(self.value),
      error: self.error
    )
  }

  public func toOptional() -> Validated<Optional<Value>> {
    .init(
      value: .some(self.value),
      error: self.error
    )
  }

  public func fromOptional<WrappedValue>() -> Validated<WrappedValue>?
  where Value == Optional<WrappedValue> {
    if let wrappedValue: WrappedValue = self.value {
      return .init(
        value: wrappedValue,
        error: self.error
      )
    }
    else {
      return .none
    }
  }
}
