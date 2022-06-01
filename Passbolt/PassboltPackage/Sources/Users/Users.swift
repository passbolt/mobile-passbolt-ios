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

public struct Users {

  public var userDetails: @StorageAccessActor (User.ID) async throws -> UserDetailsDSV
  public var userAvatarImage: @StorageAccessActor (User.ID) async throws -> Data?
  public var featureUnload: @FeaturesActor () async throws -> Void
}

extension Users: Feature {

  public static func load(
    in environment: AppEnvironment,
    using features: FeatureFactory,
    cancellables: Cancellables
  ) async throws -> Self {
    let userDetailsFetch: UserDetailsDatabaseFetch = try await features.instance()
    let networkClient: NetworkClient = try await features.instance()

    @StorageAccessActor func userDetails(
      for userID: User.ID
    ) async throws -> UserDetailsDSV {
      try await userDetailsFetch(userID)
    }

    // access only with StorageAccessActor
    var avatarsCache: Dictionary<User.ID, Data> = .init()

    @StorageAccessActor func userAvatarImage(
      for userID: User.ID
    ) async throws -> Data? {
      if let cachedAvatar: Data = avatarsCache[userID] {
        return cachedAvatar
      }
      else {
        let avatar: Data = try await networkClient.mediaDownload
          .makeAsync(
            using: userDetailsFetch(userID).avatarImageURL
          )
        avatarsCache[userID] = avatar
        return avatar
      }
    }

    @FeaturesActor func featureUnload() async throws {
      /* NOP */
    }

    return Self(
      userDetails: userDetails(for:),
      userAvatarImage: userAvatarImage(for:),
      featureUnload: featureUnload
    )
  }
}

#if DEBUG
extension Users {

  public nonisolated static var placeholder: Self {
    Self(
      userDetails: unimplemented("You have to provide mocks for used methods"),
      userAvatarImage: unimplemented("You have to provide mocks for used methods"),
      featureUnload: unimplemented("You have to provide mocks for used methods")
    )
  }
}
#endif
