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

import struct Foundation.UUID

// currently backend is not handling uppercased UUID properly
// making it lowercased has to be done when used in the client-server
// communication - using this proxy allows to ensure proper behavior
public struct PassboltID {

  public let rawValue: UUID

  public init() {
    self.rawValue = .init()
  }

  public init(
    rawValue: UUID
  ) {
    self.rawValue = rawValue
  }

  public init?(
    uuidString: String
  ) {
    guard let uuid: UUID = .init(uuidString: uuidString)
    else { return nil }
    self.rawValue = uuid
  }
}

extension PassboltID: RawRepresentable {}

extension PassboltID: CustomStringConvertible {

  // lowercase description as well in order to provide
  // lowercased UUID in URLs
  public var description: String {
    self.rawValue.uuidString.lowercased()
  }
}

extension PassboltID: Sendable {}
extension PassboltID: Hashable {}

extension PassboltID: Encodable {

  public func encode(
    to encoder: Encoder
  ) throws {
    try self.rawValue.uuidString.lowercased().encode(to: encoder)
  }
}

extension PassboltID: Decodable {

  public init(
    from decoder: Decoder
  ) throws {
    self.rawValue = try .init(from: decoder)
  }
}

extension Tagged
where RawValue == PassboltID {

  public init() {
    self.init(rawValue: PassboltID())
  }

  public init?(
    uuidString: String
  ) {
    guard let id: PassboltID = .init(uuidString: uuidString) else { return nil }
    self.init(rawValue: id)
  }

  public init(
    rawValue: UUID
  ) {
    self.init(rawValue: PassboltID(rawValue: rawValue))
  }
}
