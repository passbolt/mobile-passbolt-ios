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

public struct PasswordExpirySettings: Sendable, Equatable, Decodable {

  public let automaticUpdate: Bool
  public let automaticExpiry: Bool
  public let defaultExpiryPeriod: Int?

  public init(
    automaticUpdate: Bool,
    automaticExpiry: Bool,
    defaultExpiryPeriod: Int?
  ) {
    self.automaticUpdate = automaticUpdate
    self.automaticExpiry = automaticExpiry
    self.defaultExpiryPeriod = defaultExpiryPeriod
  }

  private enum CodingKeys: String, CodingKey {

    case automaticUpdate = "automatic_update"
    case automaticExpiry = "automatic_expiry"
    case defaultExpiryPeriod = "default_expiry_period"
  }
}
