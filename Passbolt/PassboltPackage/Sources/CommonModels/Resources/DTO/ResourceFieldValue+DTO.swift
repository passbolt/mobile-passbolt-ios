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

extension ResourceFieldValue: Codable {

  public init(
    from decoder: Decoder
  ) throws {
    if let string: String = try? .init(from: decoder) {
      self = .string(string)
    }
    else if let otpSecret: OTPSecret = try? .init(from: decoder) {
      self = .otp(otpSecret)
    }
    else {
      self = try .unknown(.init(from: decoder))
    }
  }

  public func encode(
    to encoder: Encoder
  ) throws {
    switch self {
    case .string(let value):
      var container: SingleValueEncodingContainer = encoder.singleValueContainer()
      try container.encode(value)

    case .otp(let secret):
      var container: SingleValueEncodingContainer = encoder.singleValueContainer()
      try container.encode(secret)

    case .encrypted:
      throw
        InternalInconsistency
        .error("Can't encode encrypted value, you have to decrypt it first!")

    case .unknown(let json):
      try json.encode(to: encoder)
    }
  }
}
