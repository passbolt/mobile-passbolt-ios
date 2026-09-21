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

public enum SessionMFAProvider: String {

  case totp = "totp"
  case yubiKey = "yubikey"
  case duo = "duo"
  case webauthn = "webauthn"
  case unknown

  public init(from decoder: Decoder) throws {
    let container: SingleValueDecodingContainer = try decoder.singleValueContainer()
    let rawValue: String = try container.decode(String.self)
    if let provider: Self = Self(rawValue: rawValue) {
      self = provider
    }
    else {
      // the raw value is dropped by `unknown`, log it to allow
      // diagnosing which provider was requested by the server
      Diagnostics.logger.info("Unsupported MFA provider requested: \(rawValue, privacy: .public)")
      self = .unknown
    }
  }

  public var isSupported: Bool { self != .unknown }
}

extension SessionMFAProvider: Hashable {}
extension SessionMFAProvider: Decodable {}
extension SessionMFAProvider: Sendable {}

extension Array where Element == SessionMFAProvider {

  /// Providers which can be presented by this application, in the original order.
  public var supportedProviders: Array<SessionMFAProvider> {
    self.filter(\.isSupported)
  }
}
