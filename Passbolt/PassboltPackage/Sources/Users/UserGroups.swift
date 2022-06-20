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

public struct UserGroups {

  public var filteredResourceUserGroupList:
    (AnyAsyncSequence<String>) -> AnyAsyncSequence<Array<ResourceUserGroupListItemDSV>>
  public var groupMembers: (UserGroup.ID) async throws -> OrderedSet<UserDetailsDSV>
  public var featureUnload: @FeaturesActor () async throws -> Void
}

extension UserGroups: LegacyFeature {

  public static func load(
    in environment: AppEnvironment,
    using features: FeatureFactory,
    cancellables: Cancellables
  ) async throws -> Self {
    unowned let features: FeatureFactory = features
    let diagnostics: Diagnostics = try await features.instance()
    let accountSession: AccountSession = try await features.instance()
    let sessionData: AccountSessionData = try await features.instance()
    let accountDatabase: AccountDatabase = try await features.instance()

    nonisolated func filteredResourceUserGroupList(
      filters: AnyAsyncSequence<String>
    ) -> AnyAsyncSequence<Array<ResourceUserGroupListItemDSV>> {
      AsyncCombineLatestSequence(sessionData.updatesSequence(), filters)
        .map { (_, filterText: String) async -> Array<ResourceUserGroupListItemDSV> in
          let userGroups: Array<ResourceUserGroupListItemDSV>
          do {
            userGroups =
              try await accountDatabase
              .fetchResourceUserGroupList(
                .init(
                  userID: accountSession.currentState().currentAccount?.userID,
                  text: filterText
                )
              )
          }
          catch {
            diagnostics.log(error)
            userGroups = .init()
          }

          return userGroups
        }
        .asAnyAsyncSequence()
    }

    @StorageAccessActor func groupMembers(
      _ userGroupID: UserGroup.ID
    ) async throws -> OrderedSet<UserDetailsDSV> {
      try await features
        .instance(
          of: UserGroupDetails.self,
          context: userGroupID
        )
        .details()
        .members
    }

    @FeaturesActor func featureUnload() async throws {
      // always succeed
    }

    return Self(
      filteredResourceUserGroupList: filteredResourceUserGroupList(filters:),
      groupMembers: groupMembers(_:),
      featureUnload: featureUnload
    )
  }
}

#if DEBUG

extension UserGroups {

  public static var placeholder: Self {
    Self(
      filteredResourceUserGroupList: unimplemented("You have to provide mocks for used methods"),
      groupMembers: unimplemented("You have to provide mocks for used methods"),
      featureUnload: unimplemented("You have to provide mocks for used methods")
    )
  }
}
#endif
