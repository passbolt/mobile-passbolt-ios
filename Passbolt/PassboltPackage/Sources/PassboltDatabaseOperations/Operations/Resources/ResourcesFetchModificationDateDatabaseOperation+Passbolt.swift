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
import FeatureScopes
import Session
import struct Foundation.Date

// MARK: - Implementation

extension ResourcesFetchModificationDateDatabaseOperation {

  @Sendable fileprivate static func execute(
    _ input: ResourcesFetchModificationDateDatabaseOperationDescription.Input,
    connection: SQLiteConnection
  ) throws -> ResourcesFetchModificationDateDatabaseOperation.Output {
    guard !input.isEmpty else {
      return .init()
    }
    let statement: SQLiteStatement =
      "SELECT id, modified FROM resources WHERE id" + .in(input)

    return try connection.fetch(using: statement) { (row: SQLiteRow) -> ResourceModificationDate in
      guard
        let id: Resource.ID = row.id,
        let modifiedTimestamp: Timestamp = row.modified
      else {
        throw DatabaseIssue.error(underlyingError: DatabaseDataInvalid.error(for: ResourceModificationDate.self))
      }

      return ResourceModificationDate(
        resourceId: id,
        modificationDate: modifiedTimestamp.asDate
      )
    }
  }
}

extension FeaturesRegistry {

  internal mutating func usePassboltResourcesFetchModificationDateDatabaseOperation() {
    self.use(
      FeatureLoader.databaseOperation(
        of: ResourcesFetchModificationDateDatabaseOperation.self,
        execute: ResourcesFetchModificationDateDatabaseOperation.execute(_:connection:)
      ),
      in: SessionScope.self
    )
  }
}
