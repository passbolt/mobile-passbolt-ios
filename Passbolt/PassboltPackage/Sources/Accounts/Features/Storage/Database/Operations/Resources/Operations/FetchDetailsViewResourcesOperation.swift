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

import Environment

public typealias FetchResourceDetailsDSVsOperation = DatabaseOperation<
  FetchResourceDetailsDSVsOperationFilter, ResourceDetailsDSV
>

public struct FetchResourceDetailsDSVsOperationFilter {

  public var resourceID: Resource.ID

  public init(
    resourceID: Resource.ID
  ) {
    self.resourceID = resourceID
  }
}

extension FetchResourceDetailsDSVsOperation {

  internal static func using(
    _ connection: @escaping () async throws -> SQLiteConnection
  ) -> Self {
    withConnection(
      using: connection
    ) { conn, input in
      let selectResourcesUsersPermissionsStatement: SQLiteStatement =
        .statement(
          """
          SELECT
            usersResources.userID AS userID,
            usersResources.resourceID AS resourceID,
            usersResources.permissionType AS permissionType
          FROM
            usersResources
          WHERE
            usersResources.resourceID == ?;
          """,
          arguments: input.resourceID
        )

      let selectResourcesUserGroupsPermissionsStatement: SQLiteStatement =
        .statement(
          """
          SELECT
            userGroupsResources.userGroupID AS userGroupID,
            userGroupsResources.resourceID AS resourceID,
            userGroupsResources.permissionType AS permissionType
          FROM
            userGroupsResources
          WHERE
            userGroupsResources.resourceID == ?;
          """,
          arguments: input.resourceID
        )

      let record: ResourceDetailsDSV? =
        try conn.fetchFirst(
          using: .statement(
            """
            SELECT
              id,
              name,
              permissionType,
              url,
              username,
              description,
              fields
            FROM
              resourceDetailsView
            WHERE
              id == ?1
            LIMIT
              1;
            """,
            arguments: input.resourceID
          )
        ) { dataRow -> ResourceDetailsDSV in
          guard
            let id: Resource.ID = dataRow.id.flatMap(Resource.ID.init(rawValue:)),
            let name: String = dataRow.name,
            let permissionType: PermissionTypeDSV = dataRow.permissionType.flatMap(PermissionTypeDSV.init(rawValue:)),
            let rawFields: String = dataRow.fields
          else {
            throw
              DatabaseIssue
              .error(
                underlyingError:
                  DatabaseDataInvalid
                  .error(for: ResourceTypeDSV.self)
              )
          }

          let usersPermissions: Array<PermissionDSV> = try conn.fetch(using: selectResourcesUsersPermissionsStatement) {
            dataRow in
            guard
              let userID: User.ID = dataRow.userID.flatMap(User.ID.init(rawValue:)),
              let resourceID: Resource.ID = dataRow.resourceID.flatMap(Resource.ID.init(rawValue:)),
              let permissionType: PermissionTypeDSV = dataRow.permissionType.flatMap(PermissionTypeDSV.init(rawValue:))
            else {
              throw
                DatabaseIssue
                .error(
                  underlyingError:
                    DatabaseDataInvalid
                    .error(for: PermissionTypeDSV.self)
                )
            }

            return .userToResource(
              userID: userID,
              resourceID: resourceID,
              type: permissionType
            )
          }

          let userGroupsPermissions: Array<PermissionDSV> = try conn.fetch(
            using: selectResourcesUserGroupsPermissionsStatement
          ) { dataRow in
            guard
              let userGroupID: UserGroup.ID = dataRow.userGroupID.flatMap(UserGroup.ID.init(rawValue:)),
              let resourceID: Resource.ID = dataRow.resourceID.flatMap(Resource.ID.init(rawValue:)),
              let permissionType: PermissionTypeDSV = dataRow.permissionType.flatMap(PermissionTypeDSV.init(rawValue:))
            else {
              throw
                DatabaseIssue
                .error(
                  underlyingError:
                    DatabaseDataInvalid
                    .error(for: PermissionDSV.self)
                )
            }

            return .userGroupToResource(
              userGroupID: userGroupID,
              resourceID: resourceID,
              type: permissionType
            )
          }

          return ResourceDetailsDSV(
            id: id,
            permissionType: permissionType,
            name: name,
            url: dataRow.url,
            username: dataRow.username,
            description: dataRow.description,
            fields: ResourceFieldDSV.decodeArrayFrom(rawString: rawFields),
            permissions: Set(
              usersPermissions + userGroupsPermissions
            )
          )
        }

      if let resourceDetails: ResourceDetailsDSV = record {
        return resourceDetails
      }
      else {
        throw
          DatabaseIssue
          .error(
            underlyingError:
              DatabaseDataInvalid
              .error(for: ResourceDetailsDSV.self)
          )
      }
    }
  }
}
