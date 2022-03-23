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

import Combine
import CommonModels
import Environment

public typealias StoreFoldersOperation = DatabaseOperation<Array<Folder>, Void>

extension StoreFoldersOperation {

  static func using(
    _ connection: @escaping () async throws -> SQLiteConnection
  ) -> Self {
    withConnectionInTransaction(
      using: connection
    ) { conn, input in
      // We have to remove all previously stored folders before updating
      // due to lack of ability to get information about deleted folders.
      // Until data diffing endpoint becomes implemented we are replacing
      // whole data set with the new one as an update.
      // We are getting all possible results anyway until diffing becomes implemented.
      // Please remove later on when diffing becomes available or other method of
      // deleting records selecively becomes implemented.
      //
      // Delete currently stored folders
      try conn.execute("DELETE FROM folders;")

      // Since Folders make tree like structure and
      // tree integrity is verified by database foreign
      // key constraints it has to be inserted in a valid
      // order for operation to succeed (from root to leaf)
      var inputReminder: Array<Folder> = input
      var sortedFolders: Array<Folder> = .init()

      func isValidFolder(_ folder: Folder) -> Bool {
        folder.parentFolderID == nil
          || sortedFolders.contains(where: { $0.id == folder.parentFolderID })
      }

      while let index: Array<Folder>.Index = inputReminder.firstIndex(where: isValidFolder(_:)) {
        sortedFolders.append(inputReminder.remove(at: index))
      }

      // Insert or update all new folders
      for folder in sortedFolders {
        try conn
          .execute(
            upsertFoldersStatement,
            with: folder.id.rawValue,
            folder.name,
            folder.permission.rawValue,
            folder.shared,
            folder.parentFolderID?.rawValue
          )
      }
    }
  }
}

private let upsertFoldersStatement: SQLiteStatement = """
  INSERT OR REPLACE INTO
    folders(
      id,
      name,
      permission,
      shared,
      parentFolderID
    )
  VALUES
    (
      ?1,
      ?2,
      ?3,
      ?4,
      ?5
    );
  """

public typealias FetchFolderOperation = DatabaseOperation<Folder.ID, Folder?>

extension FetchFolderOperation {

  static func using(
    _ connection: @escaping () async throws -> SQLiteConnection
  ) -> Self {
    withConnection(
      using: connection
    ) { conn, input in
      let statement: SQLiteStatement = """
        SELECT
          id,
          name,
          permission,
          shared,
          parentFolderID
        FROM
          folders
        WHERE
          folders.id IS ?;
        """
      let params: Array<SQLiteBindable?> = [input.rawValue]

      return
        try conn
        .fetch(
          statement,
          with: params
        ) { rows in
          rows.first.flatMap { row -> Folder? in
            guard
              let id: Folder.ID = (row.id as String?).map(ListViewFolder.ID.init(rawValue:)),
              let name: String = row.name,
              let permission: Permission = row.permission.flatMap(Permission.init(rawValue:))
            else { return nil }
            return Folder(
              id: id,
              name: name,
              permission: permission,
              shared: row.shared ?? false,
              parentFolderID: (row.parentFolderID as String?).map(ListViewFolder.ID.init(rawValue:))
            )
          }
        }
    }
  }
}

public typealias FetchListViewFoldersOperation = DatabaseOperation<FoldersFilter, Array<ListViewFolder>>

extension FetchListViewFoldersOperation {

  static func using(
    _ connection: @escaping () async throws -> SQLiteConnection
  ) -> Self {
    withConnection(
      using: connection
    ) { conn, input in
      var statement: SQLiteStatement
      var params: Array<SQLiteBindable?>

      // note that current filters application is not optimal,
      // it should be more performant if applied on recursive
      // select but it might be less readable
      // unless there is any performance issue it is preferred
      // to be left in this way

      if input.flattenContent {
        statement = """
          WITH RECURSIVE
            flattenedFoldersListView(
              id,
              name,
              permission,
              parentFolderID,
              shared
            )
          AS
            (
              SELECT
                foldersListView.id,
                foldersListView.name,
                foldersListView.permission,
                foldersListView.parentFolderID,
                foldersListView.shared
              FROM
                foldersListView
              WHERE
                foldersListView.parentFolderID IS ?

              UNION ALL

              SELECT
                foldersListView.id,
                foldersListView.name,
                foldersListView.permission,
                foldersListView.parentFolderID,
                foldersListView.shared
              FROM
                foldersListView,
                flattenedFoldersListView
              WHERE
                foldersListView.parentFolderID = flattenedFoldersListView.id
            )
          SELECT DISTINCT
            flattenedFoldersListView.id AS id,
            flattenedFoldersListView.name AS name,
            flattenedFoldersListView.permission AS permission,
            flattenedFoldersListView.parentFolderID AS parentFolderID,
            flattenedFoldersListView.shared AS shared,
            (
              SELECT
              (
                (
                  SELECT
                    COUNT(*)
                  FROM
                    resources
                  WHERE
                    resources.parentFolderID IS flattenedFoldersListView.id
                )
              +
                (
                  SELECT
                    COUNT(*)
                  FROM
                    folders
                  WHERE
                    folders.parentFolderID IS flattenedFoldersListView.id
                )
              )
            ) AS contentCount
          FROM
            flattenedFoldersListView
          WHERE
            1 -- equivalent of true, used to simplify dynamic query building
          """
        params = [input.folderID?.rawValue]
      }
      else {
        statement = """
          SELECT
            foldersListView.id AS id,
            foldersListView.name AS name,
            foldersListView.permission AS permission,
            foldersListView.parentFolderID AS parentFolderID,
            foldersListView.shared AS shared,
            (
              SELECT
              (
                (
                  SELECT
                    COUNT(*)
                  FROM
                    resources
                  WHERE
                    resources.parentFolderID IS foldersListView.id
                )
              +
                (
                  SELECT
                    COUNT(*)
                  FROM
                    folders
                  WHERE
                    folders.parentFolderID IS foldersListView.id
                )
              )
            ) AS contentCount
          FROM
            foldersListView
          WHERE
            foldersListView.parentFolderID IS ?
          """
        params = [input.folderID?.rawValue]
      }

      if !input.text.isEmpty {
        statement
          .append(
            """
            AND name LIKE '%' || ? || '%'
            """
          )
        params.append(input.text)
      }
      else {
        /* NOP */
      }

      // since we cannot use array in query directly
      // we are preparing it manually as argument for each element
      if input.permissions.count > 1 {
        statement.append("AND permission IN (")
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
        statement.append("AND permission = ? ")
        params.append(permission.rawValue)
      }
      else {
        /* NOP */
      }

      switch input.sorting {
      case .nameAlphabetically:
        statement.append("ORDER BY name COLLATE NOCASE ASC")
      }

      // end query
      statement.append(";")

      return
        try conn
        .fetch(
          statement,
          with: params
        ) { rows in
          rows.compactMap { row -> ListViewFolder? in
            guard
              let id: ListViewFolder.ID = (row.id as String?).map(ListViewFolder.ID.init(rawValue:)),
              let name: String = row.name,
              let permission: Permission = row.permission.flatMap(Permission.init(rawValue:))
            else { return nil }
            return ListViewFolder(
              id: id,
              name: name,
              permission: permission,
              shared: row.shared ?? false,
              parentFolderID: (row.parentFolderID as String?).map(ListViewFolder.ID.init(rawValue:)),
              contentCount: row.contentCount ?? 0
            )
          }
        }
    }
  }
}

public typealias FetchListViewFolderResourcesOperation = DatabaseOperation<FoldersFilter, Array<ListViewFolderResource>>

extension FetchListViewFolderResourcesOperation {

  static func using(
    _ connection: @escaping () async throws -> SQLiteConnection
  ) -> Self {
    withConnection(
      using: connection
    ) { conn, input in
      var statement: SQLiteStatement
      var params: Array<SQLiteBindable?>

      // note that current filters application is not optimal,
      // it should be more performant if applied on recursive
      // select but it might be less readable
      // unless there is any performance issue it is preferred
      // to be left in this way
      if input.flattenContent {
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
                  foldersListView.parentFolderID IS ?

                UNION ALL

                SELECT
                  foldersListView.id,
                  foldersListView.parentFolderID
                FROM
                  foldersListView,
                  flattenedFoldersListView
                WHERE
                  foldersListView.parentFolderID = flattenedFoldersListView.id
              )
            SELECT DISTINCT
              folderResourcesListView.id AS id,
              folderResourcesListView.name AS name,
              folderResourcesListView.username AS username,
              folderResourcesListView.parentFolderID AS parentFolderID
            FROM
              folderResourcesListView
            INNER JOIN
              flattenedFoldersListView
            ON
              folderResourcesListView.parentFolderID IS ?
            OR
              folderResourcesListView.parentFolderID IS flattenedFoldersListView.id
            WHERE
              1 -- equivalent of true, used to simplify dynamic query building
          """
        params = [input.folderID?.rawValue, input.folderID?.rawValue]
      }
      else {
        statement = """
          SELECT
            id,
            name,
            username,
            parentFolderID
          FROM
            folderResourcesListView
          WHERE
            parentFolderID IS ?
          """
        params = [input.folderID?.rawValue]
      }

      if !input.text.isEmpty {
        statement
          .append(
            """
            AND name LIKE '%' || ? || '%'
            """
          )
        params.append(input.text)
      }
      else {
        /* NOP */
      }

      // since we cannot use array in query directly
      // we are preparing it manually as argument for each element
      if input.permissions.count > 1 {
        statement.append("AND permission IN (")
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
        statement.append("AND permission = ? ")
        params.append(permission.rawValue)
      }
      else {
        /* NOP */
      }

      switch input.sorting {
      case .nameAlphabetically:
        statement.append("ORDER BY name COLLATE NOCASE ASC")
      }

      // end query
      statement.append(";")

      return
        try conn
        .fetch(
          statement,
          with: params
        ) { rows in
          rows.compactMap { row -> ListViewFolderResource? in
            guard
              let id: ListViewFolderResource.ID = (row.id as String?).map(ListViewFolderResource.ID.init(rawValue:)),
              let name: String = row.name
            else { return nil }
            return ListViewFolderResource(
              id: id,
              name: name,
              username: row.username,
              parentFolderID: (row.parentFolderID as String?).map(Folder.ID.init(rawValue:))
            )
          }
        }
    }
  }
}
