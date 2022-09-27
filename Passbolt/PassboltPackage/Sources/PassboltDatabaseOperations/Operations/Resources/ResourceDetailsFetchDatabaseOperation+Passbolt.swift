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
import Session

// MARK: - Implementation

extension ResourceDetailsFetchDatabaseOperation {

  @MainActor fileprivate static func load(
    features: FeatureFactory
  ) async throws -> Self {
    unowned let features: FeatureFactory = features

    let sessionDatabase: SessionDatabase = try await features.instance()

    nonisolated func execute(
      _ input: Resource.ID,
      connection: SQLiteConnection
    ) throws -> ResourceDetailsDSV {
      let selectResourcesUsersPermissionsStatement: SQLiteStatement =
        .statement(
          """
          SELECT
            usersResources.userID AS userID,
            usersResources.resourceID AS resourceID,
            usersResources.permissionType AS permissionType,
            usersResources.permissionID AS permissionID
          FROM
            usersResources
          WHERE
            usersResources.resourceID == ?;
          """,
          arguments: input
        )

      let selectResourcesUserGroupsPermissionsStatement: SQLiteStatement =
        .statement(
          """
          SELECT
            userGroupsResources.userGroupID AS userGroupID,
            userGroupsResources.resourceID AS resourceID,
            userGroupsResources.permissionType AS permissionType,
            userGroupsResources.permissionID AS permissionID
          FROM
            userGroupsResources
          WHERE
            userGroupsResources.resourceID == ?;
          """,
          arguments: input
        )

      let selectResourceTagsStatement: SQLiteStatement =
        .statement(
          """
          SELECT
            resourceTags.id AS id,
            resourceTags.slug AS slug,
            resourceTags.shared AS shared
          FROM
            resourceTags
          JOIN
            resourcesTags
          ON
            resourceTags.id == resourcesTags.resourceTagID
          WHERE
            resourcesTags.resourceID == ?;
          """,
          arguments: input
        )

      let record: ResourceDetailsDSV? =
        try connection.fetchFirst(
          using: .statement(
            """
            SELECT
              id,
              name,
              favoriteID,
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
            arguments: input
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
              .recording(dataRow, for: "dataRow")
          }

          let usersPermissions: Array<PermissionDSV> = try connection.fetch(
            using: selectResourcesUsersPermissionsStatement
          ) {
            dataRow in
            guard
              let userID: User.ID = dataRow.userID.flatMap(User.ID.init(rawValue:)),
              let resourceID: Resource.ID = dataRow.resourceID.flatMap(Resource.ID.init(rawValue:)),
              let permissionType: PermissionTypeDSV = dataRow.permissionType.flatMap(PermissionTypeDSV.init(rawValue:)),
              let permissionID: Permission.ID = dataRow.permissionID.flatMap(Permission.ID.init(rawValue:))
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
              id: permissionID,
              userID: userID,
              resourceID: resourceID,
              type: permissionType
            )
          }

          let userGroupsPermissions: Array<PermissionDSV> = try connection.fetch(
            using: selectResourcesUserGroupsPermissionsStatement
          ) { dataRow in
            guard
              let userGroupID: UserGroup.ID = dataRow.userGroupID.flatMap(UserGroup.ID.init(rawValue:)),
              let resourceID: Resource.ID = dataRow.resourceID.flatMap(Resource.ID.init(rawValue:)),
              let permissionType: PermissionTypeDSV = dataRow.permissionType.flatMap(PermissionTypeDSV.init(rawValue:)),
              let permissionID: Permission.ID = dataRow.permissionID.flatMap(Permission.ID.init(rawValue:))
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
              id: permissionID,
              userGroupID: userGroupID,
              resourceID: resourceID,
              type: permissionType
            )
          }

          let tags: Array<ResourceTagDSV> = try connection.fetch(
            using: selectResourceTagsStatement
          ) { dataRow in
            guard
              let id: ResourceTag.ID = dataRow.id.flatMap(ResourceTag.ID.init(rawValue:)),
              let slug: ResourceTag.Slug = dataRow.slug.flatMap(ResourceTag.Slug.init(rawValue:)),
              let shared: Bool = dataRow.shared
            else {
              throw
                DatabaseIssue
                .error(
                  underlyingError:
                    DatabaseDataInvalid
                    .error(for: ResourceTagDSV.self)
                )
            }

            return ResourceTagDSV(
              id: id,
              slug: slug,
              shared: shared
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
            favoriteID: dataRow.favoriteID.flatMap(Resource.FavoriteID.init(rawValue:)),
            permissions: OrderedSet(
              usersPermissions + userGroupsPermissions
            ),
            tags: tags
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

    nonisolated func executeAsync(
      _ input: Resource.ID
    ) async throws -> ResourceDetailsDSV {
      try await execute(
        input,
        connection: sessionDatabase.connection()
      )
    }

    return Self(
      execute: executeAsync(_:)
    )
  }
}

extension FeatureFactory {

  internal func usePassboltResourceDetailsFetchDatabaseOperation() {
    self.use(
      .disposable(
        ResourceDetailsFetchDatabaseOperation.self,
        load: ResourceDetailsFetchDatabaseOperation
          .load(features:)
      )
    )
  }
}
