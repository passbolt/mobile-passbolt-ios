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

public typealias FetchResourceListItemDSVsOperation = DatabaseOperation<ResourcesFilter, Array<ResourceListItemDSV>>

extension FetchResourceListItemDSVsOperation {

  internal static func using(
    _ connection: @escaping () async throws -> SQLiteConnection
  ) -> Self {
    withConnection(
      using: connection
    ) { conn, input in
      var statement: SQLiteStatement

      if let foldersFilter: ResourcesFolderFilter = input.folders {

        // note that current filters application is not optimal,
        // it should be more performant if applied on recursive
        // select but it might be less readable
        // unless there is any performance issue it is preferred
        // to be left in this way
        if foldersFilter.flattenContent {
          statement = """
              WITH RECURSIVE
                flattenedResourceFolders(
                  id,
                  parentFolderID
                )
              AS
                (
                  SELECT
                    resourceFolders.id,
                    resourceFolders.parentFolderID
                  FROM
                    resourceFolders
                  WHERE
                    resourceFolders.id IS ?

                  UNION ALL

                  SELECT
                    resourceFolders.id,
                    resourceFolders.parentFolderID
                  FROM
                    resourceFolders,
                    flattenedResourceFolders
                  WHERE
                    resourceFolders.parentFolderID IS flattenedResourceFolders.id
                )
              SELECT DISTINCT
                resources.id,
                resources.parentFolderID,
                resources.name AS name,
                resources.username AS username,
                resources.url AS url
              FROM
                resources
              LEFT JOIN
                flattenedResourceFolders
              ON
                resources.parentFolderID IS ?
              OR
                resources.parentFolderID IS flattenedResourceFolders.id
              WHERE
                1 -- equivalent of true, used to simplify dynamic query building
            """
          statement.appendArguments(
            foldersFilter.folderID,
            foldersFilter.folderID
          )
        }
        else {
          statement = """
              SELECT
                resources.id,
                resources.parentFolderID,
                resources.name AS name,
                resources.username AS username,
                resources.url AS url
              FROM
                resources
              WHERE
                resources.parentFolderID IS ?
            """
          statement.appendArgument(foldersFilter.folderID)
        }
      }
      else {
        statement = """
            SELECT
              resources.id,
              resources.parentFolderID,
              resources.name AS name,
              resources.username AS username,
              resources.url AS url
            FROM
              resources
            WHERE
              1 -- equivalent of true, used to simplify dynamic query building
          """
      }

      if !input.text.isEmpty {
        statement
          .append(
            """
            AND
            (
               resources.name LIKE '%' || ? || '%'
            OR resources.url LIKE '%' || ? || '%'
            OR resources.username LIKE '%' || ? || '%'
            OR (
              SELECT
                1
              FROM
                resourcesTags
              INNER JOIN
                resourceTags
              ON
                resourcesTags.resourceTagID == resourceTags.id
              WHERE
                resourcesTags.resourceID == resources.id
              AND
                resourceTags.slug LIKE '%' || ? || '%'
              LIMIT 1
              )
            )
            """
          )
        // adding multiple times since we can't count args when using dynamic query
        // and argument has to be used multiple times
        statement.appendArgument(input.text)
        statement.appendArgument(input.text)
        statement.appendArgument(input.text)
        statement.appendArgument(input.text)
      }
      else {
        /* NOP */
      }

      if !input.name.isEmpty {
        statement.append("AND resources.name LIKE '%' || ? || '%' ")
        statement.appendArgument(input.name)
      }
      else {
        /* NOP */
      }

      if !input.url.isEmpty {
        statement.append("AND resources.url LIKE '%' || ? || '%' ")
        statement.appendArgument(input.url)
      }
      else {
        /* NOP */
      }

      if !input.username.isEmpty {
        statement.append("AND resources.username LIKE '%' || ? || '%' ")
        statement.appendArgument(input.username)
      }
      else {
        /* NOP */
      }

      if input.favoriteOnly {
        statement.append("AND resources.favorite != 0 ")
      }
      else {
        /* NOP */
      }

      // since we cannot use array in query directly
      // we are preparing it manually as argument for each element
      if input.permissions.count > 1 {
        statement.append("AND resources.permissionType IN (")
        for index in input.permissions.indices {
          if index == input.permissions.startIndex {
            statement.append("?")
          }
          else {
            statement.append(", ?")
          }
          statement.appendArgument(input.permissions[index].rawValue)
        }
        statement.append(") ")
      }
      else if let permissionType: PermissionType = input.permissions.first {
        statement.append("AND resources.permissionType == ? ")
        statement.appendArgument(permissionType)
      }
      else {
        /* NOP */
      }

      // since we cannot use array in query directly
      // we are preparing it manually as argument for each element
      if input.tags.count > 1 {
        statement.append(
          """
          AND (
            SELECT
              1
            FROM
              resourcesTags
            WHERE
              resourcesTags.resourceID == resources.id
            AND
              resourcesTags.resourceTagID
            IN (
          """
        )
        for index in input.tags.indices {
          if index == input.tags.startIndex {
            statement.append("?")
          }
          else {
            statement.append(", ?")
          }
          statement.appendArgument(input.tags[index])
        }
        statement.append(") LIMIT 1")
      }
      else if let tag: ResourceTag.ID = input.tags.first {
        statement.append(
          """
          AND (
            SELECT
              1
            FROM
              resourcesTags
            WHERE
              resourcesTags.resourceID == resources.id
            AND
              resourcesTags.resourceTagID == ?
            LIMIT 1
          )
          """
        )
        statement.appendArgument(tag)
      }
      else {
        /* NOP */
      }

      // since we cannot use array in query directly
      // we are preparing it manually as argument for each element
      if input.userGroups.count > 1 {
        statement.append(
          """
          AND (
            SELECT
              1
            FROM
              userGroupsResources
            WHERE
              userGroupsResources.resourceID == resources.id
            AND
              userGroupsResources.userGroupID
            IN (
          )
          """
        )
        for index in input.userGroups.indices {
          if index == input.userGroups.startIndex {
            statement.append("?")
          }
          else {
            statement.append(", ?")
          }
          statement.appendArgument(input.userGroups[index])
        }
        statement.append(") LIMIT 1")
      }
      else if let userGroup: UserGroup.ID = input.userGroups.first {
        statement.append(
          """
          AND (
            SELECT
              1
            FROM
              userGroupsResources
            WHERE
              userGroupsResources.resourceID == resources.id
            AND
              userGroupsResources.userGroupID == ?
            LIMIT 1
          )
          """
        )
        statement.appendArgument(userGroup)
      }
      else {
        /* NOP */
      }

      switch input.sorting {
      case .nameAlphabetically:
        statement.append("ORDER BY resources.name COLLATE NOCASE ASC")

      case .modifiedRecently:
        statement.append("ORDER BY resources.modified DESC")
      }

      // end query
      statement.append(";")

      return
        try conn
        .fetch(using: statement) { dataRow -> ResourceListItemDSV in
          guard
            let id: Resource.ID = dataRow.id.flatMap(Resource.ID.init(rawValue:)),
            let name: String = dataRow.name
          else {
            throw
              DatabaseIssue
              .error(
                underlyingError:
                  DatabaseDataInvalid
                  .error(for: ResourceListItemDSV.self)
              )
          }

          return ResourceListItemDSV(
            id: id,
            parentFolderID: dataRow.parentFolderID.flatMap(ResourceFolder.ID.init(rawValue:)),
            name: name,
            username: dataRow.username,
            url: dataRow.url
          )
        }
    }
  }
}

extension ResourceTagDSV {

  internal static func setFrom(
    rawString: String
  ) -> Set<Self> {
    Set(
      rawString
        .components(separatedBy: ",")
        .compactMap(from(string:))
    )
  }

  internal static func from(
    string: String
  ) -> Self? {
    var fields = string.components(separatedBy: ";")
    guard
      let shared: Bool = fields.popLast()?.components(separatedBy: "=").last.flatMap({ $0 == "1" }),
      let slug: ResourceTag.Slug = fields.popLast()?.components(separatedBy: "=").last.map(
        ResourceTag.Slug.init(rawValue:)
      ),
      let id: ResourceTag.ID = fields.popLast()?.components(separatedBy: "=").last.map(ResourceTag.ID.init(rawValue:))
    else { return nil }

    return ResourceTagDSV(
      id: id,
      slug: slug,
      shared: shared
    )
  }
}
