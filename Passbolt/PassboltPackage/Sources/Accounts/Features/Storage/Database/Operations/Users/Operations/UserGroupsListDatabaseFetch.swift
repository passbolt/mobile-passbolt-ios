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
import Environment

public struct UserGroupsListDatabaseFetch {

  public var execute: @StorageAccessActor (UserGroupsFilter) async throws -> Array<UserGroupDetailsDSV>

  public init(
    execute: @escaping @StorageAccessActor (Input) async throws -> Output
  ) {
    self.execute = execute
  }
}

extension UserGroupsListDatabaseFetch: DatabaseOperationFeature {

  public static func using(
    _ connection: @escaping () async throws -> SQLiteConnection
  ) -> Self {
    withConnection(
      using: connection
    ) { conn, input in
      var groupSelectStatement: SQLiteStatement =
        .statement(
          """
          SELECT
            userGroups.id AS id,
            userGroups.name AS name
          FROM
            userGroups
          WHERE
            1 -- equivalent of true, used to simplify dynamic query building
          """
        )

      if !input.text.isEmpty {
        groupSelectStatement
          .append(
            """
            AND
            (
               users.username LIKE '%' || ? || '%'
            OR users.firstName LIKE '%' || ? || '%'
            OR users.lastName LIKE '%' || ? || '%'
            )

            """
          )
        // adding multiple times since we can't count args when using dynamic query
        // and argument has to be used multiple times
        groupSelectStatement.appendArgument(input.text)
        groupSelectStatement.appendArgument(input.text)
        groupSelectStatement.appendArgument(input.text)
      }
      else { /* NOP */  }

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
        try conn
        .fetch(
          using: groupSelectStatement
        ) { dataRow -> UserGroupDetailsDSV in
          guard
            let id: UserGroup.ID = dataRow.id.flatMap(UserGroup.ID.init(rawValue:)),
            let name: String = dataRow.name
          else {
            throw
              DatabaseIssue
              .error(
                underlyingError:
                  DatabaseDataInvalid
                  .error(for: UserGroupDetailsDSV.self)
              )
          }

          var groupMembersSelectStatement: SQLiteStatement = membersSelectStatement
          groupMembersSelectStatement.appendArgument(id)

          let groupMembers: Array<UserDetailsDSV> =
            try conn
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
                  DatabaseIssue
                  .error(
                    underlyingError:
                      DatabaseDataInvalid
                      .error(for: UserDetailsDSV.self)
                  )
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

          return UserGroupDetailsDSV(
            id: id,
            name: name,
            members: OrderedSet(groupMembers)
          )
        }
    }
  }
}
