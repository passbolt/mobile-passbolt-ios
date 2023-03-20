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

extension ResourceField {

  internal static func decodeOrderedSetFrom(
    rawString: String
  ) throws -> OrderedSet<Self> {
    try OrderedSet(
      rawString
        .components(separatedBy: ";")
        .map(from(string:))
    )
  }

  private static func from(
    string: String
  ) throws -> Self {
    var parts: Array<String> = string.components(separatedBy: ",")

    guard parts.count >= 1
    else {
      throw
        DatabaseDataInvalid
        .error(
          for: ResourceField.self,
          "Invalid or missing name/type"
        )
        .recording(string, for: "string")
    }

    let nameAndType: Array<String> = parts.removeFirst().components(separatedBy: ":")

    guard
      nameAndType.count == 2,
      let name: String = nameAndType.first,
      let type: String = nameAndType.last
    else {
      throw
        DatabaseDataInvalid
        .error(
          for: ResourceField.self,
          "Invalid name/type"
        )
        .recording(string, for: "string")
    }
    var properties: Dictionary<String, Any> = .init()
    for part in parts {
      let partElements: Array<String> = part.components(separatedBy: "=")
      guard
        partElements.count == 2,
        let property: String = partElements.first,
        let value: String = partElements.last
      else {
        throw
          DatabaseDataInvalid
          .error(for: ResourceField.self)
          .recording(string, for: "string")
      }
      switch property {
      case "encrypted", "required":
        properties[property] = value == "1"

      case "minimum", "maximum":
        properties[property] = UInt(value)

      case _:
        throw
          DatabaseDataInvalid
          .error(
            for: ResourceField.self,
            "Invalid field property"
          )
          .recording(string, for: "string")
      }
    }

    if type == "totp" {
      return .init(
        name: name,
        content: .totp(
          required: properties["required"] as? Bool ?? false
        )
      )
    }
    else if type == "string" {

      return .init(
        name: name,
        content: .string(
          encrypted: properties["encrypted"] as? Bool ?? false,
          required: properties["required"] as? Bool ?? false,
          minLength: properties["minLength"] as? UInt,
          maxLength: properties["maxLength"] as? UInt
        )
      )
    }
    else {
      throw
        DatabaseDataInvalid
        .error(
          for: ResourceField.self,
          "Invalid field type"
        )
        .recording(string, for: "string")
    }
  }
}
