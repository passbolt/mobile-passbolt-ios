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

public struct InvalidValue: TheError {

  public static func error<Value>(
    _ message: StaticString = "InvalidValue",
    validationRule: StaticString,
    value: Value,
    displayable: DisplayableString,
    file: StaticString = #fileID,
    line: UInt = #line
  ) -> Self {
    Self(
      context: .context(
        .message(
          message,
          file: file,
          line: line
        )
      )
      .recording(validationRule, for: "validationRule")
      .recording(value, for: "value"),
      displayableMessage: displayable,
      validationRule: validationRule
    )
  }

  public var context: DiagnosticsContext
  public var displayableMessage: DisplayableString
  public var validationRule: StaticString
}

extension InvalidValue: Hashable {

  public static func == (
    _ lhs: InvalidValue,
    _ rhs: InvalidValue
  ) -> Bool {
    lhs.validationRule == rhs.validationRule
      && lhs.displayableMessage == rhs.displayableMessage
  }

  public func hash(
    into hasher: inout Hasher
  ) {
    hasher.combine(self.validationRule)
  }
}

extension InvalidValue {

  public static func alwaysInvalid<Value>(
    message: StaticString = "InvalidValue-alwaysInvalid",
    validationRule: StaticString = "alwaysInvalid",
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

  public static func empty<Value>(
    message: StaticString = "InvalidValue-empty",
    validationRule: StaticString = "nonEmpty",
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

  public static func tooShort<Value>(
    message: StaticString = "InvalidValue-tooShort",
    validationRule: StaticString = "minimumLength",
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

  public static func tooLong<Value>(
    message: StaticString = "InvalidValue-tooLong",
    validationRule: StaticString = "maximumLength",
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

  public static func notContains<Value>(
    message: StaticString = "InvalidValue-notContains",
    validationRule: StaticString = "contains",
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
