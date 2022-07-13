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

import Accounts
import CommonModels
import Features
import NetworkClient

import struct Foundation.Data

// MARK: - Interface

public struct UserDetails {

  public var details: () async throws -> UserDetailsDSV
  public var permissionToResource: (Resource.ID) async throws -> PermissionType?
  public var avatarImage: () async -> Data?
}

extension UserDetails: LoadableFeature {

  public typealias Context = User.ID
}

// MARK: - Implementation

extension UserDetails {

  @FeaturesActor fileprivate static func load(
    features: FeatureFactory,
    context userID: Context,
    cancellables: Cancellables
  ) async throws -> Self {
    let diagnostics: Diagnostics = try await features.instance()
    let sessionData: AccountSessionData = try await features.instance()
    let networkClient: NetworkClient = try await features.instance()
    let userDetailsDatabaseFetch: UserDetailsDatabaseFetch = try await features.instance()
    let userResourcePermissionDatabaseFetch: UserResourcePermissionDatabaseFetch = try await features.instance()

    @Sendable nonisolated func fetchUserDetails() async throws -> UserDetailsDSV {
      try await userDetailsDatabaseFetch(userID)
    }

    let currentDetails: UpdatableValue<UserDetailsDSV> = .init(
      updatesSequence:
        sessionData
        .updatesSequence(),
      update: fetchUserDetails
    )

    let avatarImageCache: AsyncCache<Data> = .init()

    @StorageAccessActor func details() async throws -> UserDetailsDSV {
      try await currentDetails.value
    }

    @AccountSessionActor func permissionToResource(
      _ resourceID: Resource.ID
    ) async throws -> PermissionType? {
      try await userResourcePermissionDatabaseFetch(
        (
          userID: currentDetails.value.id,
          resourceID: resourceID
        )
      )
    }

    @AccountSessionActor func avatarImage() async -> Data? {
      do {
        return
          try await avatarImageCache
          .valueOrUpdate {
            return
              try await networkClient
              .mediaDownload
              .makeAsync(
                using: currentDetails
                  .value
                  .avatarImageURL
              )
          }
      }
      catch {
        diagnostics.log(error)
        return .none
      }
    }

    return UserDetails(
      details: details,
      permissionToResource: permissionToResource(_:),
      avatarImage: avatarImage
    )
  }
}

extension FeatureFactory {

  @FeaturesActor public func usePassboltUserDetails() {
    self.use(
      .lazyLoaded(
        UserDetails.self,
        load: UserDetails.load(features:context:cancellables:)
      )
    )
  }
}

#if DEBUG

extension UserDetails {

  public static var placeholder: Self {
    Self(
      details: unimplemented(),
      permissionToResource: unimplemented(),
      avatarImage: unimplemented()
    )
  }
}
#endif
