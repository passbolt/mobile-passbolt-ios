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
import Session

// MARK: - Implementation

extension ResourceUserGroupPermissionsDetailsFetchDatabaseOperation {

  @Sendable fileprivate static func execute(
    _ input: Resource.ID,
    connection: SQLiteConnection
  ) throws -> Array<UserGroupPermissionDetailsDSV> {
    let groupsSelectStatement: SQLiteStatement =
      .statement(
        """
        SELECT
          userGroups.id AS id,
          userGroups.name AS name,
          userGroupsResources.permission AS permission
        FROM
          userGroupsResources
        INNER JOIN
          userGroups
        ON
          userGroups.id == userGroupsResources.userGroupID
        WHERE
          userGroupsResources.resourceID == ?1
        ;
        """,
        arguments: input
      )

    let membersSelectStatement: SQLiteStatement =
      .statement(
        """
        SELECT DISTINCT
          users.id AS id,
          users.username AS username,
          users.firstName AS firstName,
          users.lastName AS lastName,
          users.publicPGPKeyFingerprint AS fingerprint,
          users.avatarImageURL AS avatarImageURL
        FROM
          users
        INNER JOIN
          usersGroups
        ON
          users.id == usersGroups.userID
        WHERE
          usersGroups.userGroupID == ?1
        ;
        """
      )

    return
      try connection
      .fetch(using: groupsSelectStatement) { dataRow -> UserGroupPermissionDetailsDSV in
        guard
          let id: UserGroup.ID = dataRow.id.flatMap(UserGroup.ID.init(rawValue:)),
          let name: String = dataRow.name,
          let permission: Permission = dataRow.permission.flatMap(Permission.init(rawValue:))
        else {
          throw
            DatabaseDataInvalid
            .error(for: UserGroupPermissionDetailsDSV.self)
            .recording(dataRow, for: "dataRow")
        }

        var groupMembersSelectStatement: SQLiteStatement = membersSelectStatement
        groupMembersSelectStatement.appendArgument(id)

        let groupMembers: Array<UserDetailsDSV> =
          try connection
          .fetch(using: groupMembersSelectStatement) { dataRow -> UserDetailsDSV in
            guard
              let id: User.ID = dataRow.id.flatMap(User.ID.init(rawValue:)),
              let username: String = dataRow.username,
              let firstName: String = dataRow.firstName,
              let lastName: String = dataRow.lastName,
              let fingerprint: Fingerprint = dataRow.fingerprint.flatMap(Fingerprint.init(rawValue:)),
              let avatarImageURL: URLString = dataRow.avatarImageURL.flatMap(URLString.init(rawValue:))
            else {
              throw
                DatabaseDataInvalid
                .error(for: UserDetailsDSV.self)
                .recording(dataRow, for: "dataRow")
            }

            return UserDetailsDSV(
              id: id,
              username: username,
              firstName: firstName,
              lastName: lastName,
              fingerprint: fingerprint,
              avatarImageURL: avatarImageURL
            )
          }

        return UserGroupPermissionDetailsDSV(
          id: id,
          name: name,
          permission: permission,
          members: OrderedSet(groupMembers)
        )
      }
  }
}

extension FeaturesRegistry {

  internal mutating func usePassboltResourceUserGroupPermissionsDetailsFetchDatabaseOperation() {
    self.use(
      FeatureLoader.databaseOperation(
        of: ResourceUserGroupPermissionsDetailsFetchDatabaseOperation.self,
        execute: ResourceUserGroupPermissionsDetailsFetchDatabaseOperation.execute(_:connection:)
      ),
      in: SessionScope.self
    )
  }
}
