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

public struct Users {

  public var userDetails: (User.ID) async throws -> UserDetailsDSV
  public var userPermissionToResource: (User.ID, Resource.ID) async throws -> PermissionType?
  public var userAvatarImage: (User.ID) async throws -> Data?
  public var featureUnload: () async throws -> Void
}

extension Users: LoadableContextlessFeature {}

// MARK: - Implementation

extension Users {

  fileprivate static func load(
    features: FeatureFactory,
    cancellables: Cancellables
  ) async throws -> Self {
    unowned let features: FeatureFactory = features

    @StorageAccessActor func userDetails(
      for userID: User.ID
    ) async throws -> UserDetailsDSV {
      try await features
        .instance(
          of: UserDetails.self,
          context: userID
        )
        .details()
    }

    @StorageAccessActor func userPermissionToResource(
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

    @StorageAccessActor func userAvatarImage(
      for userID: User.ID
    ) async throws -> Data? {
      try await features
        .instance(
          of: UserDetails.self,
          context: userID
        )
        .avatarImage()
    }

    @FeaturesActor func featureUnload() async throws {
      /* NOP */
    }

    return Self(
      userDetails: userDetails(for:),
      userPermissionToResource: userPermissionToResource(userID:resourceID:),
      userAvatarImage: userAvatarImage(for:),
      featureUnload: featureUnload
    )
  }
}
extension FeatureFactory {

  @FeaturesActor public func usePassboltUsers() {
    self.use(
      .lazyLoaded(
        Users.self,
        load: Users.load(features:cancellables:)
      )
    )
  }
}

#if DEBUG
extension Users {

  public nonisolated static var placeholder: Self {
    Self(
      userDetails: unimplemented(),
      userPermissionToResource: unimplemented(),
      userAvatarImage: unimplemented(),
      featureUnload: unimplemented()
    )
  }
}
#endif
