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

extension UserGroupsStoreDatabaseOperation {

  @MainActor fileprivate static func load(
    features: FeatureFactory
  ) async throws -> Self {
    unowned let features: FeatureFactory = features

    let sessionDatabase: SessionDatabase = try await features.instance()

    nonisolated func execute(
      _ input: Array<UserGroupDSO>,
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
      // Delete currently stored userGroups
      // associations are removed by cascade triggers
      try connection.execute("DELETE FROM userGroups;")

      for userGroup in input {
        try connection.execute(
          .statement(
            """
            INSERT INTO
              userGroups(
                id,
                name
              )
            VALUES
              (
                ?1,
                ?2
              )
            ON CONFLICT
              (
                id
              )
            DO UPDATE SET
              name=?2
            ;
            """,
            arguments: userGroup.id,
            userGroup.name
          )
        )

        for userReference in userGroup.userReferences {
          try connection.execute(
            .statement(
              """
              INSERT INTO
                usersGroups(
                  userID,
                  userGroupID
                )
              VALUES
                (
                  ?1,
                  ?2
                )
              ;
              """,
              arguments: userReference.id,
              userGroup.id
            )
          )
        }
      }
    }

    nonisolated func executeAsync(
      _ input: Array<UserGroupDSO>
    ) async throws {
      try await sessionDatabase
        .connection()
        .withTransaction { connection in
          try execute(
            input,
            connection: connection
          )
        }
    }

    return Self(
      execute: executeAsync(_:)
    )
  }
}

extension FeatureFactory {

  internal func usePassboltUserGroupsStoreDatabaseOperation() {
    self.use(
      .disposable(
        UserGroupsStoreDatabaseOperation.self,
        load: UserGroupsStoreDatabaseOperation
          .load(features:)
      )
    )
  }
}
