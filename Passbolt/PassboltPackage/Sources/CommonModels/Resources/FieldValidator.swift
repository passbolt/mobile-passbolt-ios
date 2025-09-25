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

import struct Foundation.CharacterSet

public struct FieldValidator<Value>: Sendable, Hashable {

  private let id: UUID = .init()
  private let rule: @Sendable (Value) throws -> Void

  public init(
    rule: @escaping @Sendable (Value) throws -> Void
  ) {
    self.rule = rule
  }

  func callAsFunction(_ value: Value) throws {
    try self.rule(value)
  }

  public static func == (lhs: FieldValidator<Value>, rhs: FieldValidator<Value>) -> Bool {
    lhs.id == rhs.id
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(self.id)
  }

  struct ValidationError: Error {

    let message: StaticString

    static func error(_ message: StaticString) -> ValidationError {
      .init(message: message)
    }
  }
}

extension FieldValidator where Value == String {

  public static var base32: FieldValidator<String> {
    .init(
      rule: { value in
        let base32CharacterSet: CharacterSet = .init(
          charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567="
        )
        if value.uppercased().rangeOfCharacter(from: base32CharacterSet.inverted) != nil {
          throw ValidationError.error(
            "Value is not valid base32 encoded string"
          )
        }
      }
    )
  }
}

