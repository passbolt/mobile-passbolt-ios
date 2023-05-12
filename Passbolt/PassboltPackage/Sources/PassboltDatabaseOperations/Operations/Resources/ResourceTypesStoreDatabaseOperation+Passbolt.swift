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

extension ResourceTypesStoreDatabaseOperation {

  @Sendable fileprivate static func execute(
    _ input: Array<ResourceType>,
    connection: SQLiteConnection
  ) throws {
    // cleanup existing types as preparation for update
    try connection.execute("DELETE FROM resourceTypes;")

    for resourceType in input {
      try connection.execute(
        .statement(
          """
          INSERT INTO
            resourceTypes(
              id,
              slug,
              name
            )
          VALUES
            (
              ?1,
              ?2,
              ?3
            )
          ON CONFLICT
            (
              id
            )
          DO UPDATE SET
            slug=?2,
            name=?3
          ;
          """,
          arguments: resourceType.id,
          resourceType.specification.slug,
          resourceType.name
        )
      )
    }
  }
}

extension FeaturesRegistry {

  internal mutating func usePassboltResourceTypesStoreDatabaseOperation() {
    self.use(
      FeatureLoader.databaseOperationWithTransaction(
        of: ResourceTypesStoreDatabaseOperation.self,
        execute: ResourceTypesStoreDatabaseOperation.execute(_:connection:)
      ),
      in: SessionScope.self
    )
  }
}
