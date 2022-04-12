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

public typealias StoreFoldersOperation = DatabaseOperation<Array<Folder>, Void>

extension StoreFoldersOperation {

  internal static func using(
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
