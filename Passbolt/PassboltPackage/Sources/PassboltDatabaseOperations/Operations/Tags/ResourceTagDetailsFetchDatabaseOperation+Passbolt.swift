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

// MARK: - Implementation

extension ResourceTagDetailsFetchDatabaseOperation {

  @Sendable fileprivate static func execute(
    _ input: ResourceTag.ID,
    connection: SQLiteConnection
  ) throws -> ResourceTag {
    let statement: SQLiteStatement = .statement(
      """
      SELECT
        id,
        slug,
        shared
      FROM
        resourceTags
      WHERE
        resourceTags.id == ?1;
      """,
      arguments: input
    )

    return
      try connection
      .fetchFirst(using: statement) { dataRow -> ResourceTag in
        guard
          let id: ResourceTag.ID = dataRow.id.flatMap(ResourceTag.ID.init(rawValue:)),
          let slug: ResourceTag.Slug = dataRow.slug.flatMap(ResourceTag.Slug.init(rawValue:)),
          let shared: Bool = dataRow.shared
        else {
          throw
            DatabaseDataInvalid
            .error(for: ResourceTag.self)
            .recording(dataRow, for: "dataRow")
        }

        return ResourceTag(
          id: id,
          slug: slug,
          shared: shared
        )
      }
  }
}

extension FeaturesRegistry {

  internal mutating func usePassboltResourceTagDetailsFetchDatabaseOperation() {
    self.use(
      FeatureLoader.databaseOperation(
        of: ResourceTagDetailsFetchDatabaseOperation.self,
        execute: ResourceTagDetailsFetchDatabaseOperation.execute(_:connection:)
      ),
      in: SessionScope.self
    )
  }
}
