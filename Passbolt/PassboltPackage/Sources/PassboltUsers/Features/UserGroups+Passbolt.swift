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
import FeatureScopes
import OSFeatures
import Session
import SessionData
import Users

extension UserGroups {

  @MainActor fileprivate static func load(
    features: Features,
    cancellables: Cancellables
  ) throws -> Self {
    try features.ensureScope(SessionScope.self)

    let session: Session = try features.instance()
    let sessionData: SessionData = try features.instance()
    let resourceUserGroupsListFetchDatabaseOperation: ResourceUserGroupsListFetchDatabaseOperation =
      try features.instance()
    let userGroupsListFetchDatabaseOperation: UserGroupsListFetchDatabaseOperation = try features.instance()

    @Sendable nonisolated func filteredResourceUserGroupList(
      filters: AnyAsyncSequence<String>
    ) -> AnyAsyncSequence<Array<ResourceUserGroupListItemDSV>> {
      combineLatest(sessionData.lastUpdate.asAnyAsyncSequence(), filters)
        .map { (_, filterText: String) async -> Array<ResourceUserGroupListItemDSV> in
          let userGroups: Array<ResourceUserGroupListItemDSV>
          do {
            userGroups = try await resourceUserGroupsListFetchDatabaseOperation(
              .init(
                userID: session.currentAccount().userID,
                text: filterText
              )
            )
          }
          catch {
            error.logged()
            userGroups = .init()
          }

          return userGroups
        }
        .asAnyAsyncSequence()
    }

    @Sendable nonisolated func filteredResourceUserGroups(
      _ filter: UserGroupsFilter
    ) async throws -> Array<ResourceUserGroupListItemDSV> {
      try await resourceUserGroupsListFetchDatabaseOperation(
        .init(
          userID: filter.userID,
          text: filter.text
        )
      )
    }

    @Sendable nonisolated func filteredUserGroups(
      _ filter: UserGroupsFilter
    ) async throws -> Array<UserGroupDetailsDSV> {
      try await userGroupsListFetchDatabaseOperation(
        .init(
          userID: filter.userID,
          text: filter.text
        )
      )
    }

    @Sendable nonisolated func groupMembers(
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

    return Self(
      filteredResourceUserGroupList: filteredResourceUserGroupList(filters:),
      filteredResourceUserGroups: filteredResourceUserGroups(_:),
      filteredUserGroups: filteredUserGroups(_:),
      groupMembers: groupMembers(_:)
    )
  }
}

extension FeaturesRegistry {

  internal mutating func usePassboltUserGroups() {
    self.use(
      .lazyLoaded(
        UserGroups.self,
        load: UserGroups.load(features:cancellables:)
      ),
      in: SessionScope.self
    )
  }
}
