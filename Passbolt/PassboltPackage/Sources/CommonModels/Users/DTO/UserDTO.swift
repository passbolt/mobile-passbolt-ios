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

public struct UserDTO {

  public var id: User.ID
  public var active: Bool
  public var deleted: Bool
  public var username: String
  public var profile: UserProfileDTO?
  public var key: PGPKeyDetails?

  public init(
    id: User.ID,
    active: Bool,
    deleted: Bool,
    username: String,
    profile: UserProfileDTO?,
    key: PGPKeyDetails?
  ) {
    self.id = id
    self.active = active
    self.deleted = deleted
    self.username = username
    self.profile = profile
    self.key = key
  }
}

extension UserDTO {

  public var asFilteredDSO: UserDSO? {
    guard
      let profile: UserProfileDTO = self.profile,
      let key: PGPKeyDetails = self.key,
      self.active && !self.deleted
    else { return nil }

    return .init(
      id: self.id,
      username: self.username,
      profile: profile,
			publicKey: key.publicKey,
			keyFingerprint: key.fingerprint
    )
  }
}

extension UserDTO: Decodable {

  private enum CodingKeys: String, CodingKey {

    case id = "id"
    case active = "active"
    case deleted = "deleted"
    case username = "username"
    case profile = "profile"
    case key = "gpgkey"
  }
}
