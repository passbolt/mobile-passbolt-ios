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

import CommonModels
import Features

import struct Foundation.Data

// MARK: - Interface

/// Access details for a given user
/// using current session.
public struct UserDetails {

  /// Access user details data for the context user.
  public var details: @Sendable () async throws -> UserDetailsDSV
  /// Access user permission to a given resource for the context user.
  public var permissionToResource: @Sendable (Resource.ID) async throws -> PermissionType?
  /// Access user avatar image for the context user.
  public var avatarImage: @Sendable () async -> Data?

  public init(
    details: @escaping @Sendable () async throws -> UserDetailsDSV,
    permissionToResource: @escaping @Sendable (Resource.ID) async throws -> PermissionType?,
    avatarImage: @escaping @Sendable () async -> Data?
  ) {
    self.details = details
    self.permissionToResource = permissionToResource
    self.avatarImage = avatarImage
  }
}

extension UserDetails: LoadableFeature {

  public typealias Context = User.ID

  #if DEBUG
  public static var placeholder: Self {
    Self(
      details: unimplemented0(),
      permissionToResource: unimplemented1(),
      avatarImage: unimplemented0()
    )
  }
  #endif
}
