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
  public var gpgKey: UserGPGKeyDTO?

  public init(
    id: User.ID,
    active: Bool,
    deleted: Bool,
    username: String,
    profile: UserProfileDTO?,
    gpgKey: UserGPGKeyDTO?
  ) {
    self.id = id
    self.active = active
    self.deleted = deleted
    self.username = username
    self.profile = profile
    self.gpgKey = gpgKey
  }
}

extension UserDTO: DTO {}

extension UserDTO {

  internal static let validator: Validator<Self> = User.ID
    .validator
    .contraMap(\.id)

  public var isValid: Bool {
    Self
      .validator
      .validate(self)
      .isValid
  }
}

extension UserDTO {

  public var asFilteredDSO: UserDSO? {
    guard
      let gpgKey: UserGPGKeyDTO = self.gpgKey,
      let profile: UserProfileDTO = self.profile,
      self.active && !self.deleted
    else { return nil }

    return .init(
      id: self.id,
      username: self.username,
      profile: profile,
      gpgKey: gpgKey
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
    case gpgKey = "gpgkey"
  }
}

#if DEBUG

extension UserDTO: RandomlyGenerated {

  public static func randomGenerator(
    using randomnessGenerator: RandomnessGenerator
  ) -> Generator<Self> {
    zip(
      with: UserDTO.init(id:active:deleted:username:profile:gpgKey:),
      User.ID
        .randomGenerator(using: randomnessGenerator),
      Bool
        .randomGenerator(using: randomnessGenerator),
      Bool
        .randomGenerator(using: randomnessGenerator),
      Generator<String>
        .randomEmail(using: randomnessGenerator),
      UserProfileDTO
        .randomGenerator(using: randomnessGenerator),
      UserGPGKeyDTO
        .randomGenerator(using: randomnessGenerator)
    )
  }
}
#endif
