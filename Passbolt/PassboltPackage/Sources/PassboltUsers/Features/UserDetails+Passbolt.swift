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
import NetworkOperations
import OSFeatures
import SessionData
import Users

import struct Foundation.Data

// MARK: - Implementation

extension UserDetails {

  @MainActor fileprivate static func load(
    features: Features,
    context userID: Context,
    cancellables: Cancellables
  ) throws -> Self {
    let diagnostics: OSDiagnostics = features.instance()
    let sessionData: SessionData = try features.instance()
    let mediaDownloadNetworkOperation: MediaDownloadNetworkOperation = try features.instance()
    let userDetailsFetchDatabaseOperation: UserDetailsFetchDatabaseOperation = try features.instance()
    let userResourcePermissionTypeFetchDatabaseOperation: UserResourcePermissionTypeFetchDatabaseOperation =
      try features.instance()

    @Sendable nonisolated func fetchUserDetails() async throws -> UserDetailsDSV {
      try await userDetailsFetchDatabaseOperation(userID)
    }

    let currentDetails: UpdatableValue<UserDetailsDSV> = .init(
      updatesSequence:
        sessionData
        .updatesSequence,
      update: fetchUserDetails
    )

    let avatarImageCache: AsyncCache<Data> = .init()

    @Sendable nonisolated func details() async throws -> UserDetailsDSV {
      try await currentDetails.value
    }

    @Sendable nonisolated func permissionToResource(
      _ resourceID: Resource.ID
    ) async throws -> Permission? {
      try await userResourcePermissionTypeFetchDatabaseOperation(
        (
          userID: currentDetails.value.id,
          resourceID: resourceID
        )
      )
    }

    @Sendable nonisolated func avatarImage() async -> Data? {
      do {
        return
          try await avatarImageCache
          .valueOrUpdate {
            return
              try await mediaDownloadNetworkOperation
              .execute(
                currentDetails
                  .value
                  .avatarImageURL
              )
          }
      }
      catch {
        diagnostics.log(error: error)
        return .none
      }
    }

    return Self(
      details: details,
      permissionToResource: permissionToResource(_:),
      avatarImage: avatarImage
    )
  }
}

extension FeaturesRegistry {

  internal mutating func usePassboltUserDetails() {
    self.use(
      .lazyLoaded(
        UserDetails.self,
        load: UserDetails.load(features:context:cancellables:)
      ),
      in: SessionScope.self
    )
  }
}
