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

  // WARNING: to refresh data use Resources.refreshIfNeeded instead
  // this function is called by Resources if needed
  public var refreshIfNeeded: () async throws -> Void
  public var filteredResourceUserGroupList:
    (AnyAsyncSequence<String>) -> AnyAsyncSequence<Array<ListViewResourcesUserGroup>>
  public var featureUnload: @FeaturesActor () async throws -> Void
}

extension UserGroups: Feature {

  public static func load(
    in environment: AppEnvironment,
    using features: FeatureFactory,
    cancellables: Cancellables
  ) async throws -> Self {
    let diagnostics: Diagnostics = try await features.instance()
    let networkClient: NetworkClient = try await features.instance()
    let accountDatabase: AccountDatabase = try await features.instance()

    let updatesSequence: AsyncVariable<Void> = .init(initial: Void())

    let refreshTask: ManagedTask<Void> = .init()

    nonisolated func refreshIfNeeded() async throws {
      try await refreshTask.run {
        let userGroupsResponse: UserGroupsRequestResponse =
          try await networkClient
          .userGroupsRequest
          .makeAsync()

        // TODO: when diffing endpoint becomes available
        // there should be some additional logic here

        try await accountDatabase
          .storeUserGroups(
            userGroupsResponse
              .body
              .map { responseGroup in
                UserGroup(
                  id: .init(rawValue: responseGroup.id),
                  name: responseGroup.name
                )
              }
          )
      }

      await userGroupsUpdated()
    }

    nonisolated func userGroupsUpdated() async {
      try? await updatesSequence.send(Void())
    }

    nonisolated func filteredResourceUserGroupList(
      filters: AnyAsyncSequence<String>
    ) -> AnyAsyncSequence<Array<ListViewResourcesUserGroup>> {
      AsyncCombineLatestSequence(updatesSequence, filters)
        .map { (_, filter: String) async -> Array<ListViewResourcesUserGroup> in
          let userGroups: Array<ListViewResourcesUserGroup>
          do {
            userGroups =
              try await accountDatabase
              .fetchResourceUserGroupList(filter)
          }
          catch {
            diagnostics.log(error)
            userGroups = .init()
          }

          return userGroups
        }
        .asAnyAsyncSequence()
    }

    @FeaturesActor func featureUnload() async throws {
      // always succeed
    }

    return Self(
      refreshIfNeeded: refreshIfNeeded,
      filteredResourceUserGroupList: filteredResourceUserGroupList(filters:),
      featureUnload: featureUnload
    )
  }
}

#if DEBUG

extension UserGroups {

  public static var placeholder: Self {
    Self(
      refreshIfNeeded: unimplemented("You have to provide mocks for used methods"),
      filteredResourceUserGroupList: unimplemented("You have to provide mocks for used methods"),
      featureUnload: unimplemented("You have to provide mocks for used methods")
    )
  }
}
#endif
