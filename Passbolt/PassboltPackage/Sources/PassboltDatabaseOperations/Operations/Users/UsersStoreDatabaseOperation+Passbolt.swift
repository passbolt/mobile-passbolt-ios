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

extension UsersStoreDatabaseOperation {

  @Sendable fileprivate static func execute(
    _ input: Array<UserDSO>,
    connection: SQLiteConnection
  ) throws {
    // The current (active, keyed) user always survives `asFilteredDSO`, so an empty input is a fetch
    // anomaly, not "no users" — skip rather than cascade-wipe every permission and membership.
    guard input.isEmpty == false
    else { return }

    // Delete only vanished users, then upsert the rest; truncating would cascade-drop every surviving
    // user's permissions and memberships. Incoming ids go via a temp table so "NOT IN" stays a sub-select.
    try connection.execute(
      .statement("CREATE TEMP TABLE IF NOT EXISTS incomingUserIDs ( id BLOB NOT NULL PRIMARY KEY );")
    )
    try connection.execute(.statement("DELETE FROM incomingUserIDs;"))
    let idBatchSize: Int = 256
    for idsChunk: ArraySlice<User.ID> in input.map(\.id).chunked(into: idBatchSize) {
      var insertIDsStatement: SQLiteStatement = "INSERT OR IGNORE INTO incomingUserIDs ( id ) VALUES "
      for (offset, userID): (Int, User.ID) in idsChunk.enumerated() {
        if offset > 0 { insertIDsStatement.append(", ") }
        insertIDsStatement.append("( ? )")
        insertIDsStatement.appendArgument(userID)
      }
      insertIDsStatement.append(";")
      try connection.execute(insertIDsStatement)
    }
    // Cascades remove vanished users' permissions and memberships; surviving users keep theirs.
    try connection.execute(.statement("DELETE FROM users WHERE id NOT IN ( SELECT id FROM incomingUserIDs );"))
    try connection.execute(.statement("DELETE FROM incomingUserIDs;"))

    // Upsert users in multi-row batches (8 columns/row, kept under the ~999 bound-parameter limit).
    for usersChunk: ArraySlice<UserDSO> in input.chunked(into: 100) {
      var upsertStatement: SQLiteStatement = """
        INSERT INTO users(
          id, username, firstName, lastName,
          publicPGPKeyFingerprint, armoredPublicPGPKey, avatarImageURL, isSuspended
        ) VALUES
        """
      for (offset, user): (Int, UserDSO) in usersChunk.enumerated() {
        if offset > 0 { upsertStatement.append(", ") }
        upsertStatement.append("( ?, ?, ?, ?, ?, ?, ?, ? )")
        upsertStatement.appendArguments(
          user.id,
          user.username,
          user.profile.firstName,
          user.profile.lastName,
          user.keyFingerprint,
          user.publicKey,
          user.profile.avatar.urlString,
          user.isSuspended
        )
      }
      upsertStatement.append(
        """
         ON CONFLICT( id ) DO UPDATE SET
          username = excluded.username,
          firstName = excluded.firstName,
          lastName = excluded.lastName,
          publicPGPKeyFingerprint = excluded.publicPGPKeyFingerprint,
          armoredPublicPGPKey = excluded.armoredPublicPGPKey,
          avatarImageURL = excluded.avatarImageURL,
          isSuspended = excluded.isSuspended;
        """
      )
      try connection.execute(upsertStatement)
    }
  }
}

extension FeaturesRegistry {

  internal mutating func usePassboltUsersStoreDatabaseOperation() {
    self.use(
      FeatureLoader.databaseOperationWithTransaction(
        of: UsersStoreDatabaseOperation.self,
        execute: UsersStoreDatabaseOperation.execute(_:connection:)
      ),
      in: SessionScope.self
    )
  }
}
