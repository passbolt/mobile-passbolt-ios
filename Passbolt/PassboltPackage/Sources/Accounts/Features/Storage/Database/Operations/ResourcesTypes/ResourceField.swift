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

public enum ResourceField {

  case string(name: String, required: Bool, encrypted: Bool, maxLength: Int?)

  // for database use
  internal init?(
    typeString: String,
    name: String,
    required: Bool,
    encrypted: Bool,
    maxLength: Int?
  ) {
    switch typeString {
    case "string":
      self = .string(
        name: name,
        required: required,
        encrypted: encrypted,
        maxLength: maxLength
      )

    case _:
      return nil
    }
  }

  // for database use
  internal var typeString: String {
    switch self {
    case .string:
      return "string"
    }
  }

  public var name: String {
    switch self {
    case let .string(name, _, _, _):
      return name
    }
  }

  public var required: Bool {
    switch self {
    case let .string(_, required, _, _):
      return required
    }
  }

  public var encrypted: Bool {
    switch self {
    case let .string(_, _, encrypted, _):
      return encrypted
    }
  }

  public var maxLength: Int? {
    switch self {
    case let .string(_, _, _, maxLength):
      return maxLength
    }
  }
}

extension ResourceField {

  internal static func arrayFrom(
    rawString: String
  ) -> Array<Self> {
    rawString.components(separatedBy: ",").compactMap(from(string:))
  }

  internal static func from(
    string: String
  ) -> Self? {
    var fields = string.components(separatedBy: ";")

    let maxLength: Int? = fields.popLast()?.components(separatedBy: "=").last.flatMap { Int($0) }

    guard
      let encrypted: Bool = fields.popLast()?.components(separatedBy: "=").last.flatMap({ $0 == "1" }),
      let required: Bool = fields.popLast()?.components(separatedBy: "=").last.flatMap({ $0 == "1" }),
      var nameAndTypeString: Array<String> = fields.popLast()?.components(separatedBy: ":"),
      let typeString: String = nameAndTypeString.popLast(),
      let name: String = nameAndTypeString.popLast()
    else { return nil }

    return .init(
      typeString: typeString,
      name: name,
      required: required,
      encrypted: encrypted,
      maxLength: maxLength
    )
  }
}
