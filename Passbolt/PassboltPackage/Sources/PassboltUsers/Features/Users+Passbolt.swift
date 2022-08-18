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

import DatabaseOperations
import Users

// MARK: - Implementation

extension Users {

  @MainActor fileprivate static func load(
    features: FeatureFactory,
    cancellables: Cancellables
  ) async throws -> Self {
    unowned let features: FeatureFactory = features
    let usersListFetchDatabaseOperation: UsersListFetchDatabaseOperation = try await features.instance()

    @Sendable nonisolated func filteredUsers(
      _ filter: UsersFilter
    ) async throws -> Array<UserDetailsDSV> {
      try await usersListFetchDatabaseOperation(
        .init(text: filter.text)
      )
    }

    @Sendable nonisolated func userDetails(
      for userID: User.ID
    ) async throws -> UserDetailsDSV {
      try await features
        .instance(
          of: UserDetails.self,
          context: userID
        )
        .details()
    }

    @Sendable nonisolated func userPermissionToResource(
      userID: User.ID,
      resourceID: Resource.ID
    ) async throws -> PermissionType? {
      try await features
        .instance(
          of: UserDetails.self,
          context: userID
        )
        .permissionToResource(resourceID)
    }

    @Sendable nonisolated func userAvatarImage(
      for userID: User.ID
    ) async throws -> Data? {
      try await features
        .instance(
          of: UserDetails.self,
          context: userID
        )
        .avatarImage()
    }

    return Self(
      filteredUsers: filteredUsers(_:),
      userDetails: userDetails(for:),
      userPermissionToResource: userPermissionToResource(userID:resourceID:),
      userAvatarImage: userAvatarImage(for:)
    )
  }
}
extension FeatureFactory {

  @MainActor public func usePassboltUsers() {
    self.use(
      .lazyLoaded(
        Users.self,
        load: Users.load(features:cancellables:)
      )
    )
  }
}
