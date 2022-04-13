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

public typealias FetchListViewResourcesOperation = DatabaseOperation<ResourcesFilter, Array<ListViewResource>>

extension FetchListViewResourcesOperation {

  internal static func using(
    _ connection: @escaping () async throws -> SQLiteConnection
  ) -> Self {
    withConnection(
      using: connection
    ) { conn, input in
      var statement: SQLiteStatement
      var params: Array<SQLiteBindable?> = .init()

      if let foldersFilter: ResourcesFolderFilter = input.folders {

        // note that current filters application is not optimal,
        // it should be more performant if applied on recursive
        // select but it might be less readable
        // unless there is any performance issue it is preferred
        // to be left in this way
        if foldersFilter.flattenContent {
          statement = """
              WITH RECURSIVE
                flattenedFoldersListView(
                  id,
                  parentFolderID
                )
              AS
                (
                  SELECT
                    foldersListView.id,
                    foldersListView.parentFolderID
                  FROM
                    foldersListView
                  WHERE
                    foldersListView.id IS ?

                  UNION ALL

                  SELECT
                    foldersListView.id,
                    foldersListView.parentFolderID
                  FROM
                    foldersListView,
                    flattenedFoldersListView
                  WHERE
                    foldersListView.parentFolderID IS flattenedFoldersListView.id
                )
              SELECT DISTINCT
                resourcesListView.id,
                resourcesListView.parentFolderID,
                resourcesListView.name AS name,
                resourcesListView.username AS username,
                resourcesListView.url AS url
              FROM
                resourcesListView
              LEFT JOIN
                flattenedFoldersListView
              ON
                resourcesListView.parentFolderID IS ?
              OR
                resourcesListView.parentFolderID IS flattenedFoldersListView.id
              WHERE
                1 -- equivalent of true, used to simplify dynamic query building
            """
          params = [foldersFilter.folderID?.rawValue, foldersFilter.folderID?.rawValue]
        }
        else {
          statement = """
              SELECT
                resourcesListView.id,
                resourcesListView.parentFolderID,
                resourcesListView.name AS name,
                resourcesListView.username AS username,
                resourcesListView.url AS url
              FROM
                resourcesListView
              WHERE
                parentFolderID IS ?
            """
          params = [foldersFilter.folderID?.rawValue]
        }
      }
      else {
        statement = """
            SELECT
              resourcesListView.id,
              resourcesListView.parentFolderID,
              resourcesListView.name AS name,
              resourcesListView.username AS username,
              resourcesListView.url AS url
            FROM
              resourcesListView
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
               resourcesListView.name LIKE '%' || ? || '%'
            OR resourcesListView.url LIKE '%' || ? || '%'
            OR resourcesListView.username LIKE '%' || ? || '%'
            )

            """
          )
        // adding multiple times since we can't count args when using dynamic query
        // and argument has to be used multiple times
        params.append(input.text)
        params.append(input.text)
        params.append(input.text)
      }
      else {
        /* NOP */
      }

      if !input.name.isEmpty {
        statement.append("AND resourcesListView.name LIKE '%' || ? || '%' ")
        params.append(input.name)
      }
      else {
        /* NOP */
      }

      if !input.url.isEmpty {
        statement.append("AND resourcesListView.url LIKE '%' || ? || '%' ")
        params.append(input.url)
      }
      else {
        /* NOP */
      }

      if !input.username.isEmpty {
        statement.append("AND resourcesListView.username LIKE '%' || ? || '%' ")
        params.append(input.username)
      }
      else {
        /* NOP */
      }

      if input.favoriteOnly {
        statement.append("AND resourcesListView.favorite != 0 ")
      }
      else {
        /* NOP */
      }

      // since we cannot use array in query directly
      // we are preparing it manually as argument for each element
      if input.permissions.count > 1 {
        statement.append("AND resourcesListView.permission IN (")
        for index in input.permissions.indices {
          if index == input.permissions.startIndex {
            statement.append("?")
          }
          else {
            statement.append(", ?")
          }
          params.append(input.permissions[index].rawValue)
        }
        statement.append(") ")
      }
      else if let permission: Permission = input.permissions.first {
        statement.append("AND resourcesListView.permission = ? ")
        params.append(permission.rawValue)
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
              tags
            JOIN
              resourceTags
            ON
              resourceTags.tagID == tags.id
            WHERE
              resourceTags.resourceID == resourcesListView.id
            AND
              tags.id
            IN (
          )
          """
        )
        for index in input.tags.indices {
          if index == input.tags.startIndex {
            statement.append("?")
          }
          else {
            statement.append(", ?")
          }
          params.append(input.tags[index].rawValue)
        }
        statement.append(") ")
      }
      else if let tag: ResourceTag.ID = input.tags.first {
        statement.append(
          """
          AND (
            SELECT
              1
            FROM
              tags
            JOIN
              resourceTags
            ON
              resourceTags.tagID == tags.id
            WHERE
              resourceTags.resourceID == resourcesListView.id
            AND
              tags.id == ?
          )
          """
        )
        params.append(tag.rawValue)
      }
      else {
        /* NOP */
      }

      switch input.sorting {
      case .nameAlphabetically:
        statement.append("ORDER BY resourcesListView.name COLLATE NOCASE ASC")

      case .modifiedRecently:
        statement.append("ORDER BY resourcesListView.modified DESC")
      }

      // end query
      statement.append(";")

      return
        try conn
        .fetch(
          statement,
          with: params
        ) { rows in
          rows.compactMap { row -> ListViewResource? in
            guard
              let id: ListViewResource.ID = (row.id as String?).map(ListViewResource.ID.init(rawValue:)),
              let name: String = row.name
            else { return nil }
            return ListViewResource(
              id: id,
              parentFolderID: (row.parentFolderID as String?).map(Folder.ID.init(rawValue:)),
              name: name,
              username: row.username,
              url: row.url
            )
          }
        }
    }
  }
}

extension ResourceTag {

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
      let slug: String = fields.popLast()?.components(separatedBy: "=").last,
      let id: ResourceTag.ID = fields.popLast()?.components(separatedBy: "=").last.map(ResourceTag.ID.init(rawValue:))
    else { return nil }

    return .init(
      id: id,
      slug: slug,
      shared: shared
    )
  }
}
