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

import Foundation
import Localization

public struct Validator<Value> {

  public var validate: (Value) -> Validated<Value>

  public init(validate: @escaping (Value) -> Validated<Value>) {
    self.validate = validate
  }
}

extension Validator {

  public func callAsFunction(_ value: Value) -> Validated<Value> {
    validate(value)
  }
}

extension Validator {

  public func contraMap<MappedValue>(
    _ mapping: @escaping (MappedValue) -> Value
  ) -> Validator<MappedValue> {
    Validator<MappedValue> { mappedValue in
      Validated
        .valid(mappedValue)
        .withErrors(
          self.validate(mapping(mappedValue)).errors
        )
    }
  }
}

public func zip<Value>(
  _ validators: Validator<Value>...
) -> Validator<Value> {
  Validator<Value> { value in
    validators
      .reduce(
        into: .valid(value)
      ) { validated, validator in
        validated = validated.withErrors(validator(value).errors)
      }
  }
}

extension Validator {

  public static var alwaysValid: Self {
    Self { value in
      .valid(value)
    }
  }

  public static func alwaysInvalid(
    displayable: DisplayableString,
    file: StaticString = #fileID,
    line: UInt = #line
  ) -> Self {
    Self { value in
      .invalid(
        value,
        errors: .alwaysInvalid(
          value: value,
          displayable: displayable,
          file: file,
          line: line
        )
      )
    }
  }
}
