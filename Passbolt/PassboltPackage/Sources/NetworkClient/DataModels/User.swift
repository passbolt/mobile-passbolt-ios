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
import Crypto

public struct User: Decodable {

  public typealias ID = Tagged<String, Self>
  public var id: ID
  public var profile: Profile
  public var gpgKey: GPGKey

  public init(
    id: ID,
    profile: Profile,
    gpgKey: GPGKey
  ) {
    self.id = id
    self.profile = profile
    self.gpgKey = gpgKey
  }

  public enum CodingKeys: String, CodingKey {

    case id = "id"
    case profile = "profile"
    case gpgKey = "gpgkey"
  }
}

extension User {

  public struct Profile: Decodable {

    public var firstName: String
    public var lastName: String
    public var avatar: Avatar

    public init(
      firstName: String,
      lastName: String,
      avatar: Avatar
    ) {
      self.firstName = firstName
      self.lastName = lastName
      self.avatar = avatar
    }

    public enum CodingKeys: String, CodingKey {

      case firstName = "first_name"
      case lastName = "last_name"
      case avatar = "avatar"
    }
  }
}

extension User.Profile {

  public struct Avatar: Decodable {

    public var url: Image

    public init(
      url: Image
    ) {
      self.url = url
    }
  }
}

extension User.Profile.Avatar {

  public struct Image: Decodable {

    public var medium: String

    public init(
      medium: String
    ) {
      self.medium = medium
    }
  }
}

extension User {

  public struct GPGKey: Decodable {

    public var armoredKey: ArmoredPGPPublicKey

    public init(
      armoredKey: ArmoredPGPPublicKey
    ) {
      self.armoredKey = armoredKey
    }

    public enum CodingKeys: String, CodingKey {

      case armoredKey = "armored_key"
    }
  }
}
