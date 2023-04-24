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

public struct ResourceField {

  public typealias ValuePath = WritableKeyPath<Dictionary<String, ResourceFieldValue>, ResourceFieldValue?>

  // used only to refer certain fields from code
  internal static func valuePath(
    forName name: StaticString
  ) -> ValuePath {
    \Dictionary<String, ResourceFieldValue>[name.description]
  }

  public let name: String
  public let content: Content

  public init(
    name: String,
    content: Content
  ) {
    self.name = name
    self.content = content
  }

  public var valuePath: ValuePath {
    \Dictionary<String, ResourceFieldValue>[self.name]
  }
}

extension ResourceField: Hashable {

  public static func == (
    _ lhs: ResourceField,
    _ rhs: ResourceField
  ) -> Bool {
    // this implementations does not properly check equality
    // since it does not take into account content differences
    // however we are treating it as immutable after decoding
    // and no content changes are allowed while identifying
    // fields only by its name - this implementation is required
    // for proper Set and Dictionary behaviors to avoid duplicates
    lhs.valuePath == rhs.valuePath
  }

  public func hash(
    into hasher: inout Hasher
  ) {
    hasher.combine(self.valuePath)
  }
}

extension ResourceField: Comparable {

  public static func < (
    lhs: ResourceField,
    rhs: ResourceField
  ) -> Bool {
    switch (lhs.name, rhs.name) {
    case ("name", _):
      return true

    case ("uri", "name"):
      return false

    case ("uri", _):
      return true

    case ("username", "name"), ("username", "uri"):
      return false

    case ("username", _):
      return true

    case ("password", "name"), ("password", "uri"), ("password", "username"):
      return false

    case ("password", _):
      return true

    case ("description", "name"), ("description", "uri"), ("description", "username"), ("description", "password"):
      return false

    case ("description", _):
      return true

    case ("otp", "name"), ("otp", "uri"), ("otp", "username"), ("otp", "password"), ("otp", "description"):
      return false

    case ("otp", _):
      return true

    case _:
      return false
    }
  }
}

extension ResourceField {

  public var valueTypeName: String? {
    self.content.typeName
  }

  public var encrypted: Bool {
    switch self.content {
    case .string(let encrypted, _, _, _):
      return encrypted

    case .totp:
      return true

    case .unknown(let encrypted, _):
      return encrypted
    }
  }

  public var required: Bool {
    switch self.content {
    case .string(_, let required, _, _):
      return required

    case .totp(let required):
      return required

    case .unknown(_, let required):
      return required
    }
  }

  public var minimum: UInt? {
    switch self.content {
    case .string(_, _, let minimum, _):
      return minimum

    case .totp:
      return .none

    case .unknown:
      return .none
    }
  }

  public var maximum: UInt? {
    switch self.content {
    case .string(_, _, _, let maximum):
      return maximum

    case .totp:
      return .none

    case .unknown:
      return .none
    }
  }
}
