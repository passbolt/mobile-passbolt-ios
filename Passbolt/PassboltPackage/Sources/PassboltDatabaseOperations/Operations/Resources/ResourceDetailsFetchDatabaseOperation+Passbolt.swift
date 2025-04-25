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

import struct Foundation.Data
import class Foundation.JSONDecoder

// MARK: - Implementation

extension ResourceDetailsFetchDatabaseOperation {

  @Sendable fileprivate static func execute(
    _ input: Resource.ID,
    connection: SQLiteConnection
  ) throws -> Resource {
    let selectResourceWithTypeStatement: SQLiteStatement =
      .statement(
        """
        SELECT
          resources.id AS id,
          resourceMetadata.name AS name,
          resources.favoriteID AS favoriteID,
          resources.permission AS permission,
          resourceMetadata.username AS username,
          resourceMetadata.description AS description,
          resources.expired AS expired,
          resourceTypes.id AS typeID,
          resourceTypes.slug AS typeSlug,
          resourceMetadata.data AS metadata,
          metadata_key_id,
          metadata_key_type
        FROM
          resources
        JOIN
          resourceTypes
        ON
          resources.typeID == resourceTypes.id
        JOIN
          resourceMetadata
        ON
          resources.id == resourceMetadata.resource_id
        WHERE
          resources.id == ?1
        LIMIT
          1;
        """,
        arguments: input
      )

    let selectResourcePathStatement: SQLiteStatement =
      .statement(
        """
        WITH RECURSIVE
          path(
            id,
            name,
            shared,
            parentID
          )
        AS
        (
          SELECT
            resourceFolders.id AS id,
            resourceFolders.name AS name,
            resourceFolders.shared AS shared,
            resourceFolders.parentFolderID AS parentID
          FROM
            resourceFolders
          JOIN
            resources
          ON
            resourceFolders.id == resources.parentFolderID
          WHERE
            resources.id == ?

          UNION

          SELECT
            resourceFolders.id AS id,
            resourceFolders.name AS name,
            resourceFolders.shared AS shared,
            resourceFolders.parentFolderID AS parentID
          FROM
            resourceFolders,
            path
          WHERE
            resourceFolders.id == path.parentID
        )
        SELECT
          path.id,
          path.name AS name,
          path.shared AS shared
        FROM
          path;
        """,
        arguments: input
      )

    let selectResourcesUsersPermissionsStatement: SQLiteStatement =
      .statement(
        """
        SELECT
          usersResources.userID AS userID,
          usersResources.permission AS permission,
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
          userGroupsResources.permission AS permission,
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
    let selectResourceURIsStatement: SQLiteStatement =
      .statement(
        """
        SELECT
          resourceURI.resource_id,
          resourceURI.uri
        FROM
          resourceURI
        WHERE
          resourceURI.resource_id == ?;
        """,
        arguments: input
      )
    let path: OrderedSet<ResourceFolderPathItem> = try OrderedSet(
      connection.fetch(
        using: selectResourcePathStatement
      ) { dataRow in
        guard
          let id: ResourceFolder.ID = dataRow.id.flatMap(ResourceFolder.ID.init(rawValue:)),
          let name: String = dataRow.name,
          let shared: Bool = dataRow.shared
        else {
          throw
            DatabaseDataInvalid
            .error(for: ResourceFolderPathItem.self)
            .recording(dataRow, for: "dataRow")
        }

        return ResourceFolderPathItem(
          id: id,
          name: name,
          shared: shared
        )
      }
      .reversed()
    )

    let usersPermissions: Array<ResourcePermission> = try connection.fetch(
      using: selectResourcesUsersPermissionsStatement
    ) {
      dataRow in
      guard
        let userID: User.ID = dataRow.userID.flatMap(User.ID.init(rawValue:)),
        let permission: Permission = dataRow.permission.flatMap(Permission.init(rawValue:)),
        let permissionID: Permission.ID = dataRow.permissionID.flatMap(Permission.ID.init(rawValue:))
      else {
        throw
          DatabaseDataInvalid
          .error(for: ResourcePermission.self)
          .recording(dataRow, for: "dataRow")
      }

      return .user(
        id: userID,
        permission: permission,
        permissionID: permissionID
      )
    }

    let userGroupsPermissions: Array<ResourcePermission> = try connection.fetch(
      using: selectResourcesUserGroupsPermissionsStatement
    ) { dataRow in
      guard
        let userGroupID: UserGroup.ID = dataRow.userGroupID.flatMap(UserGroup.ID.init(rawValue:)),
        let permission: Permission = dataRow.permission.flatMap(Permission.init(rawValue:)),
        let permissionID: Permission.ID = dataRow.permissionID.flatMap(Permission.ID.init(rawValue:))
      else {
        throw
          DatabaseDataInvalid
          .error(for: ResourcePermission.self)
          .recording(dataRow, for: "dataRow")
      }

      return .userGroup(
        id: userGroupID,
        permission: permission,
        permissionID: permissionID
      )
    }

    let tags: OrderedSet<ResourceTag> = try OrderedSet(
      connection.fetch(
        using: selectResourceTagsStatement
      ) { dataRow in
        guard
          let id: ResourceTag.ID = dataRow.id.flatMap(ResourceTag.ID.init(rawValue:)),
          let slug: ResourceTag.Slug = dataRow.slug.flatMap(ResourceTag.Slug.init(rawValue:)),
          let shared: Bool = dataRow.shared
        else {
          throw
            DatabaseDataInvalid
            .error(for: ResourceTag.self)
            .recording(dataRow, for: "dataRow")
        }

        return ResourceTag(
          id: id,
          slug: slug,
          shared: shared
        )
      }
    )

    let uris: [String] = try connection.fetch(
      using: selectResourceURIsStatement,
      mapping: { dataRow in
        guard
          let _: Resource.ID = dataRow.resource_id.flatMap(Resource.ID.init(rawValue:)),
          let uri: String = dataRow.uri
        else {
          throw
            DatabaseDataInvalid
            .error(for: ResourceURIDTO.self)
            .recording(dataRow, for: "dataRow")
        }

        return uri
      }
    )

    let record: Resource? =
      try connection.fetchFirst(
        using: selectResourceWithTypeStatement
      ) { (dataRow: SQLiteRow) throws -> Resource in
        guard
          let id: Resource.ID = dataRow.id,
          let permission: Permission = dataRow.permission,
          let typeID: ResourceType.ID = dataRow.typeID,
          let typeSlug: ResourceSpecification.Slug = dataRow.typeSlug,
          let metadata: Data = dataRow.metadata
        else {
          throw
            DatabaseDataInvalid
            .error(for: Resource.self)
            .recording(dataRow, for: "dataRow")
        }

        let metadataJSON = try JSONDecoder.default.decode(JSON.self, from: metadata)

        let resource: Resource = .init(
          id: id,
          path: path,
          favoriteID: dataRow.favoriteID.flatMap(Resource.Favorite.ID.init(rawValue:)),
          type: .init(
            id: typeID,
            slug: typeSlug
          ),
          permission: permission,
          tags: tags,
          permissions: OrderedSet(
            usersPermissions + userGroupsPermissions
          ),
          modified: dataRow.modified.flatMap(Timestamp.init(rawValue:)),
          meta: metadataJSON,
          expired: dataRow.expired.flatMap(Timestamp.init(rawValue:)),
          metadataKeyId: dataRow.metadata_key_id,
          metadataKeyType: dataRow.metadata_key_type
        )

        return resource
      }

    if let record {
      return record
    }
    else {
      throw
        DatabaseDataInvalid
        .error(for: Resource.self)
    }
  }
}

extension FeaturesRegistry {

  internal mutating func usePassboltResourceDetailsFetchDatabaseOperation() {
    self.use(
      FeatureLoader.databaseOperation(
        of: ResourceDetailsFetchDatabaseOperation.self,
        execute: ResourceDetailsFetchDatabaseOperation.execute(_:connection:)
      ),
      in: SessionScope.self
    )
  }
}
