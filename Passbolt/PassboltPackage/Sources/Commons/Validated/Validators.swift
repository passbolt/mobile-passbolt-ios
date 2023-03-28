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

extension Validator
where Value: Collection {

  public static func nonEmpty(
    displayable: DisplayableString,
    file: StaticString = #fileID,
    line: UInt = #line
  ) -> Self {
    Self { value in
      if !value.isEmpty {
        return .valid(value)
      }
      else {
        return .invalid(
          value,
          error: InvalidValue.empty(
            value: value,
            displayable: displayable,
            file: file,
            line: line
          )
        )
      }
    }
  }

  public static func minLength(
    _ minLength: UInt,
    displayable: DisplayableString,
    file: StaticString = #fileID,
    line: UInt = #line
  ) -> Self {
    Self { value in
      if value.count >= minLength {
        return .valid(value)
      }
      else {
        return .invalid(
          value,
          error: InvalidValue.tooShort(
            value: value,
            displayable: displayable,
            file: file,
            line: line
          )
        )
      }
    }
  }

  public static func maxLength(
    _ maxLength: UInt,
    displayable: DisplayableString,
    file: StaticString = #fileID,
    line: UInt = #line
  ) -> Self {
    Self { value in
      if value.count <= maxLength {
        return .valid(value)
      }
      else {
        return .invalid(
          value,
          error: InvalidValue.tooLong(
            value: value,
            displayable: displayable,
            file: file,
            line: line
          )
        )
      }
    }
  }

  public static func contains(
    where predicate: @escaping (Value.Element) -> Bool,
    displayable: DisplayableString,
    file: StaticString = #fileID,
    line: UInt = #line
  ) -> Self {
    Self { value in
      if value.contains(where: predicate) {
        return .valid(value)
      }
      else {
        return .invalid(
          value,
          error: InvalidValue.notContains(
            value: value,
            displayable: displayable,
            file: file,
            line: line
          )
        )
      }
    }
  }
}
extension Validator {

  public static func nonNull<WrappedValue>(
    displayable: DisplayableString,
    file: StaticString = #fileID,
    line: UInt = #line
  ) -> Self
  where Value == Optional<WrappedValue> {
    Self { value in
      if case .some = value {
        return .valid(value)
      }
      else {
        return .invalid(
          value,
          error: InvalidValue.null(
            value: value,
            displayable: displayable,
            file: file,
            line: line
          )
        )
      }
    }
  }
}
