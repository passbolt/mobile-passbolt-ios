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

public typealias FetchFolderOperation = DatabaseOperation<Folder.ID, Folder?>

extension FetchFolderOperation {

  internal static func using(
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
