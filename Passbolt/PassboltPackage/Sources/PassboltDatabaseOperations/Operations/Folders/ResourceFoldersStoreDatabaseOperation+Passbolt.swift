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

extension ResourceFoldersStoreDatabaseOperation {

  @Sendable fileprivate static func execute(
    _ input: Array<ResourceFolderDSO>,
    connection: SQLiteConnection
  ) throws {
    // We have to remove all previously stored data before updating
    // due to lack of ability to get information about deleted parts.
    // Until data diffing endpoint becomes implemented we are replacing
    // whole data set with the new one as an update.
    // We are getting all possible results anyway until diffing becomes implemented.
    // Please remove later on when diffing becomes available or other method of
    // deleting records selecively becomes implemented.
    //
    // Delete currently stored folders
    try connection
      .execute("DELETE FROM resourceFolders;")

    // Since Folders make tree like structure and
    // tree integrity is verified by database foreign
    // key constraints it has to be inserted in a valid
    // order for operation to succeed (from root to leaf)
    var inputReminder: Array<ResourceFolderDTO> = input
    var sortedFolders: Array<ResourceFolderDTO> = .init()

    func isValidFolder(_ folder: ResourceFolderDTO) -> Bool {
      folder.parentFolderID == nil
        || sortedFolders.contains(where: { $0.id == folder.parentFolderID })
    }

    while let index: Array<ResourceFolderDTO>.Index = inputReminder.firstIndex(where: isValidFolder(_:)) {
      sortedFolders.append(inputReminder.remove(at: index))
    }

    for folder in sortedFolders {
      try connection.execute(
        .statement(
          """
          INSERT INTO
            resourceFolders(
              id,
              name,
              permissionType,
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
            )
          ON CONFLICT
            (
              id
            )
          DO UPDATE SET
            name=?2,
            permissionType=?3,
            shared=?4,
            parentFolderID=?5
          ;
          """,
          arguments: folder.id,
          folder.name,
          folder.permissionType.rawValue,
          folder.shared,
          folder.parentFolderID
        )
      )

      for permission in folder.permissions {
        try connection.execute(permission.storeStatement)
      }
    }
  }
}

extension FeaturesRegistry {

  internal mutating func usePassboltResourceFoldersStoreDatabaseOperation() {
    self.use(
      FeatureLoader.databaseOperationWithTransaction(
        of: ResourceFoldersStoreDatabaseOperation.self,
        execute: ResourceFoldersStoreDatabaseOperation.execute(_:connection:)
      ),
      in: SessionScope.self
    )
  }
}
