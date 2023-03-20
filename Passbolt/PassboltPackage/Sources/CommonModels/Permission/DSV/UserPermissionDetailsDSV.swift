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

public struct UserPermissionDetailsDSV {

  public var id: User.ID
  public var username: String
  public var firstName: String
  public var lastName: String
  public var fingerprint: Fingerprint
  public var avatarImageURL: URLString
  public var permission: Permission

  public init(
    id: User.ID,
    username: String,
    firstName: String,
    lastName: String,
    fingerprint: Fingerprint,
    avatarImageURL: URLString,
    permission: Permission
  ) {
    self.id = id
    self.username = username
    self.firstName = firstName
    self.lastName = lastName
    self.fingerprint = fingerprint
    self.avatarImageURL = avatarImageURL
    self.permission = permission
  }
}

extension UserPermissionDetailsDSV: Hashable {}

extension UserPermissionDetailsDSV {

  public var asUserDetails: UserDetailsDSV {
    .init(
      id: self.id,
      username: self.username,
      firstName: self.firstName,
      lastName: self.lastName,
      fingerprint: self.fingerprint,
      avatarImageURL: self.avatarImageURL
    )
  }
}
