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

/// Access users data using current session.
public struct Users {

  /// Access filtered users details.
  public var filteredUsers: (UsersFilter) async throws -> Array<UserDetailsDSV>
  /// Access details for a given user.
  public var userDetails: (User.ID) async throws -> UserDetailsDSV
  /// Access permissions to a given resource for a given user.
  public var userPermissionToResource: (User.ID, Resource.ID) async throws -> Permission?
  /// Access avatar image for a given user.
  public var userAvatarImage: (User.ID) async throws -> Data?

  public init(
    filteredUsers: @escaping @Sendable (UsersFilter) async throws -> Array<UserDetailsDSV>,
    userDetails: @escaping @Sendable (User.ID) async throws -> UserDetailsDSV,
    userPermissionToResource: @escaping @Sendable (User.ID, Resource.ID) async throws -> Permission?,
    userAvatarImage: @escaping @Sendable (User.ID) async throws -> Data?
  ) {
    self.filteredUsers = filteredUsers
    self.userDetails = userDetails
    self.userPermissionToResource = userPermissionToResource
    self.userAvatarImage = userAvatarImage
  }
}

extension Users: LoadableFeature {

  public typealias Context = ContextlessLoadableFeatureContext

  #if DEBUG

  public nonisolated static var placeholder: Self {
    Self(
      filteredUsers: unimplemented1(),
      userDetails: unimplemented1(),
      userPermissionToResource: unimplemented2(),
      userAvatarImage: unimplemented1()
    )
  }
  #endif
}

extension Users {

  @Sendable public func avatarImage(
    for userID: User.ID
  ) -> @Sendable () async -> Data? {
    { [self] () async -> Data? in
      try? await self.userAvatarImage(userID)
    }
  }
}
