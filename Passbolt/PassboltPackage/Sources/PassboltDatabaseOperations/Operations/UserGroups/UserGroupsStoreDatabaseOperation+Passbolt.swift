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

extension UserGroupsStoreDatabaseOperation {

  @Sendable fileprivate static func execute(
    _ input: Array<UserGroupDSO>,
    connection: SQLiteConnection
  ) throws {
    // Delete only vanished groups, then upsert the rest; truncating would cascade-wipe every surviving
    // group's permissions and memberships. Incoming ids go via a temp table so "NOT IN" stays a sub-select.
    try connection.execute(
      .statement("CREATE TEMP TABLE IF NOT EXISTS incomingGroupIDs ( id BLOB NOT NULL PRIMARY KEY );")
    )
    try connection.execute(.statement("DELETE FROM incomingGroupIDs;"))
    let idBatchSize: Int = SQLiteBatch.maxRows(perRowBindings: 1)
    for idsChunk: ArraySlice<UserGroup.ID> in input.map(\.id).chunked(into: idBatchSize) {
      var insertIDsStatement: SQLiteStatement = "INSERT OR IGNORE INTO incomingGroupIDs ( id ) VALUES "
      for (offset, groupID): (Int, UserGroup.ID) in idsChunk.enumerated() {
        if offset > 0 { insertIDsStatement.append(", ") }
        insertIDsStatement.append("( ? )")
        insertIDsStatement.appendArgument(groupID)
      }
      insertIDsStatement.append(";")
      try connection.execute(insertIDsStatement)
    }
    // Cascades remove vanished groups' memberships and permissions; surviving groups keep theirs.
    try connection.execute(
      .statement("DELETE FROM userGroups WHERE id NOT IN ( SELECT id FROM incomingGroupIDs );")
    )

    // Memberships never bump any resource's `modified`, so reconcile every refresh: clear the incoming
    // groups' memberships here, re-insert them below.
    try connection.execute(
      .statement("DELETE FROM usersGroups WHERE userGroupID IN ( SELECT id FROM incomingGroupIDs );")
    )
    try connection.execute(.statement("DELETE FROM incomingGroupIDs;"))

    // Upsert the groups in multi-row batches (2 host parameters/row).
    for groupsChunk: ArraySlice<UserGroupDSO> in input.chunked(into: SQLiteBatch.maxRows(perRowBindings: 2)) {
      var upsertStatement: SQLiteStatement = "INSERT INTO userGroups( id, name ) VALUES "
      for (offset, userGroup): (Int, UserGroupDSO) in groupsChunk.enumerated() {
        if offset > 0 { upsertStatement.append(", ") }
        upsertStatement.append("( ?, ? )")
        upsertStatement.appendArguments(userGroup.id, userGroup.name)
      }
      upsertStatement.append("ON CONFLICT( id ) DO UPDATE SET name = excluded.name;")
      try connection.execute(upsertStatement)
    }

    // Re-insert memberships (cleared for the incoming groups above), deduped, in multi-row batches.
    let memberships: Array<(userID: User.ID, groupID: UserGroup.ID)> =
      input.flatMap { (userGroup: UserGroupDSO) in
        Set(userGroup.userReferences.map(\.id)).map { (userID: $0, groupID: userGroup.id) }
      }
    for membershipsChunk: ArraySlice<(userID: User.ID, groupID: UserGroup.ID)> in memberships.chunked(
      into: SQLiteBatch.maxRows(perRowBindings: 2)
    ) {
      var membershipStatement: SQLiteStatement = "INSERT INTO usersGroups( userID, userGroupID ) VALUES "
      for (offset, membership): (Int, (userID: User.ID, groupID: UserGroup.ID)) in membershipsChunk.enumerated() {
        if offset > 0 { membershipStatement.append(", ") }
        membershipStatement.append("( ?, ? )")
        membershipStatement.appendArguments(membership.userID, membership.groupID)
      }
      membershipStatement.append("ON CONFLICT( userGroupID, userID ) DO NOTHING;")
      try connection.execute(membershipStatement)
    }
  }
}

extension FeaturesRegistry {

  internal mutating func usePassboltUserGroupsStoreDatabaseOperation() {
    self.use(
      FeatureLoader.databaseOperationWithTransaction(
        of: UserGroupsStoreDatabaseOperation.self,
        execute: UserGroupsStoreDatabaseOperation.execute(_:connection:)
      ),
      in: SessionScope.self
    )
  }
}
