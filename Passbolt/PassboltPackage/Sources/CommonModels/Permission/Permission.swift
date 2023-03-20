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

import Commons

public enum Permission: Int {

  public typealias ID = Tagged<String, Self>

  case read = 1
  case write = 7
  case owner = 15
}

extension Permission: Hashable {}
extension Permission: RawRepresentable {}
extension Permission: Codable {}

extension Permission: CaseIterable {

  public static var allCases: Array<Self> {
    [
      .read,
      .write,
      .owner,
    ]
  }
}

extension Permission {

  public var canEdit: Bool {
    switch self {
    case .read:
      return false

    case .write, .owner:
      return true
    }
  }

  public var canShare: Bool {
    switch self {
    case .read, .write:
      return false

    case .owner:
      return true
    }
  }

  public var isOwner: Bool {
    switch self {
    case .read, .write:
      return false

    case .owner:
      return true
    }
  }
}

extension Permission.ID {

  internal static let validator: Validator<Self> = Validator<String>
    .uuid()
    .contraMap(\.rawValue)

  public var isValid: Bool {
    Self
      .validator
      .validate(self)
      .isValid
  }
}
