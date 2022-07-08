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

// MARK: - Interface

public struct UserGroupDetails {

  public var details: () async throws -> UserGroupDetailsDSV
}

extension UserGroupDetails: LoadableFeature {

  public typealias Context = UserGroup.ID
}

// MARK: - Implementation

extension UserGroupDetails {

  fileprivate static func load(
    features: FeatureFactory,
    context userGroupID: Context,
    cancellables: Cancellables
  ) async throws -> Self {
    let sessionData: AccountSessionData = try await features.instance()
    let userGroupDetailsDatabaseFetch: UserGroupDetailsDatabaseFetch = try await features.instance()

    @Sendable nonisolated func fetchUserGroupDetails() async throws -> UserGroupDetailsDSV {
      try await userGroupDetailsDatabaseFetch(userGroupID)
    }

    let currentDetails: UpdatableValue<UserGroupDetailsDSV> = .init(
      updatesSequence:
        sessionData
        .updatesSequence(),
      update: fetchUserGroupDetails
    )

    @StorageAccessActor func details() async throws -> UserGroupDetailsDSV {
      try await currentDetails.value
    }

    return .init(
      details: details
    )
  }
}

extension FeatureFactory {

  @FeaturesActor public func usePassboltUserGroupDetails() {
    self.use(
      .lazyLoaded(
        UserGroupDetails.self,
        load: UserGroupDetails.load(features:context:cancellables:)
      )
    )
  }
}

#if DEBUG

extension UserGroupDetails {

  public static var placeholder: Self {
    Self(
      details: unimplemented()
    )
  }
}
#endif
