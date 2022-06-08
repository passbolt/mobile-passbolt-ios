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

public struct UserDetailsDSV {

  public var id: User.ID
  public var username: String
  public var firstName: String
  public var lastName: String
  public var fingerprint: Fingerprint
  public var avatarImageURL: URLString

  public init(
    id: User.ID,
    username: String,
    firstName: String,
    lastName: String,
    fingerprint: Fingerprint,
    avatarImageURL: URLString
  ) {
    self.id = id
    self.username = username
    self.firstName = firstName
    self.lastName = lastName
    self.fingerprint = fingerprint
    self.avatarImageURL = avatarImageURL
  }
}

extension UserDetailsDSV: DSV {}

#if DEBUG

extension UserDetailsDSV: RandomlyGenerated {

  public static func randomGenerator(
    using randomnessGenerator: RandomnessGenerator
  ) -> Generator<Self> {
    zip(
      with: UserDetailsDSV.init(id:username:firstName:lastName:fingerprint:avatarImageURL:),
      User.ID.randomGenerator(using: randomnessGenerator),
      Generator<String>.randomEmail(using: randomnessGenerator),
      Generator<String>.randomFirstName(using: randomnessGenerator),
      Generator<String>.randomLastName(using: randomnessGenerator),
      Generator<String>
        .randomKeyFingerprint(using: randomnessGenerator)
        .map(Fingerprint.init(rawValue:)),
      Generator<String>.randomURL(using: randomnessGenerator)
        .map(URLString.init(rawValue:))
    )
  }
}
#endif