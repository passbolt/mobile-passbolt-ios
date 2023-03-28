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

extension Validator where Value == String {

  public static func uuid(
    displayable: DisplayableString = .raw("Invalid UUID"),
    file: StaticString = #fileID,
    line: UInt = #line
  ) -> Self {
    Self { value in
      if value.matches(regex: uuidRegex) {
        return .valid(value)
      }
      else {
        return .invalid(
          value,
          error: InvalidValue.notValidUUID(
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

extension InvalidValue {

  public static func notValidUUID<Value>(
    message: StaticString = "InvalidValue-NotMatchingUUID",
    validationRule: StaticString = "validUUID",
    value: Value,
    displayable: DisplayableString,
    file: StaticString = #fileID,
    line: UInt = #line
  ) -> Self {
    .error(
      message,
      validationRule: validationRule,
      value: value,
      displayable: displayable,
      file: file,
      line: line
    )
  }
}

private let uuidRegex: Regex = "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"
