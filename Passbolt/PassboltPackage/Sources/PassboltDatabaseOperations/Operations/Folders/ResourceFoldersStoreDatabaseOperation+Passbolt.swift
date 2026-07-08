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

import Commons
import DatabaseOperations
import FeatureScopes
import Session

// MARK: - Implementation

extension ResourceFoldersStoreDatabaseOperation {

  @Sendable fileprivate static func execute(
    _ input: Array<ResourceFolderDTO>,
    connection: SQLiteConnection
  ) throws {
    // Delete only vanished folders, then upsert the rest; truncating would drop every folder permission
    // and null every resource's parentFolderID. Incoming ids go via a temp table so "NOT IN" stays a
    // sub-select; the cascade still cleans a removed folder's subtree/permissions and its own resources.
    try connection.execute(
      .statement("CREATE TEMP TABLE IF NOT EXISTS incomingFolderIDs ( id BLOB NOT NULL PRIMARY KEY );")
    )
    try connection.execute(.statement("DELETE FROM incomingFolderIDs;"))
    let idBatchSize: Int = 256
    for idsChunk: ArraySlice<ResourceFolder.ID> in input.map(\.id).chunked(into: idBatchSize) {
      var insertIDsStatement: SQLiteStatement = "INSERT OR IGNORE INTO incomingFolderIDs ( id ) VALUES "
      for (offset, folderID): (Int, ResourceFolder.ID) in idsChunk.enumerated() {
        if offset > 0 { insertIDsStatement.append(", ") }
        insertIDsStatement.append("( ? )")
        insertIDsStatement.appendArgument(folderID)
      }
      insertIDsStatement.append(";")
      try connection.execute(insertIDsStatement)
    }
    try connection.execute(
      .statement("DELETE FROM resourceFolders WHERE id NOT IN ( SELECT id FROM incomingFolderIDs );")
    )

    // Sharing never bumps a timestamp, so reconcile every refresh: clear the incoming folders'
    // permissions here; they are re-inserted per folder below.
    try connection.execute(
      .statement(
        "DELETE FROM usersResourceFolders WHERE resourceFolderID IN ( SELECT id FROM incomingFolderIDs );"
      )
    )
    try connection.execute(
      .statement(
        "DELETE FROM userGroupsResourceFolders WHERE resourceFolderID IN ( SELECT id FROM incomingFolderIDs );"
      )
    )
    try connection.execute(.statement("DELETE FROM incomingFolderIDs;"))

    // Folders form a tree whose integrity is enforced by the self-referential parentFolderID FK, so
    // they must be inserted root→leaf. topoSort gives that order and chunked() preserves it, so within
    // a multi-row batch (and across chunks) a parent is always inserted before its children.
    let sortedFolders: Array<ResourceFolderDTO> = input.topoSort(idPath: \.id, parentIdPath: \.parentID)
    for foldersChunk: ArraySlice<ResourceFolderDTO> in sortedFolders.chunked(into: 200) {
      var upsertStatement: SQLiteStatement =
        "INSERT INTO resourceFolders( id, name, permission, parentFolderID ) VALUES "
      for (offset, folder): (Int, ResourceFolderDTO) in foldersChunk.enumerated() {
        if offset > 0 { upsertStatement.append(", ") }
        upsertStatement.append("( ?, ?, ?, ? )")
        upsertStatement.appendArguments(folder.id, folder.name, folder.permission.rawValue, folder.parentID)
      }
      upsertStatement.append(
        """
         ON CONFLICT( id ) DO UPDATE SET
          name = excluded.name,
          permission = excluded.permission,
          parentFolderID = excluded.parentFolderID;
        """
      )
      try connection.execute(upsertStatement)
    }

    // Folder permissions stay per-row: `storeStatement` skips a grant for a missing user/group via an
    // indexed existence join, cheaper here than pre-fetching the whole users table (folders carry far
    // fewer permissions than there are users). Reuse the two compiled handles across the batch — the
    // only real per-row cost was recompilation. Rows were cleared for the incoming folders above.
    try connection.withPreparedStatements { prepared in
      for folder: ResourceFolderDTO in input {
        for permission: GenericPermissionDTO in folder.permissions {
          try prepared.execute(permission.storeStatement)
        }
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
