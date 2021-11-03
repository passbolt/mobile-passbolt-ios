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

  case name
  case username
  case password
  case uri
  case description
  case undefined(name: String)
}

extension ResourceField: RawRepresentable {

  public init(rawValue: String) {
    switch rawValue {
    case "name":
      self = .name

    case "username":
      self = .username

    case "password", "secret":
      self = .password

    case "uri":
      self = .uri

    case "description":
      self = .description

    case let undefined:
      self = .undefined(name: undefined)
    }
  }

  public var rawValue: String {
    switch self {
    case .name:
      return "name"

    case .uri:
      return "uri"

    case .username:
      return "username"

    case .password:
      return "password"

    case .description:
      return "description"

    case let .undefined(name):
      return name
    }
  }
}

extension ResourceField: Hashable {}

extension ResourceField: Comparable {

  public static func < (
    _ lhs: Self,
    _ rhs: Self
  ) -> Bool {
    switch (lhs, rhs) {
    case (.name, _):
      return true

    case (_, .name):
      return false

    case (.username, _):
      return true

    case (_, .username):
      return false

    case (.password, _):
      return true

    case (_, .password):
      return false

    case (.uri, _):
      return true

    case (_, .uri):
      return false

    case (.description, _):
      return true

    case (_, .description):
      return false

    case (.undefined, _):
      return true

    case (_, .undefined):
      return false
    }
  }
}

extension ResourceField: Codable {

  public func encode(
    to encoder: Encoder
  ) throws {
    var container: SingleValueEncodingContainer = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}
