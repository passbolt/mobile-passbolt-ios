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

extension ResourceTagsListFetchDatabaseOperation {

  @MainActor fileprivate static func load(
    features: FeatureFactory
  ) async throws -> Self {
    unowned let features: FeatureFactory = features

    let sessionDatabase: SessionDatabase = try await features.instance()

    nonisolated func execute(
      _ input: String,
      connection: SQLiteConnection
    ) throws -> Array<ResourceTagListItemDSV> {
      var statement: SQLiteStatement = """
        SELECT
          id,
          slug,
          shared,
          (
            SELECT
              count(*)
            FROM
              resourcesTags
            WHERE
              resourceTagID IS id
          ) AS contentCount
        FROM
          resourceTags
        WHERE
          1 -- equivalent of true, used to simplify dynamic query building
        """

      if !input.isEmpty {
        statement
          .append(
            """
            AND
              slug LIKE '%' || ? || '%'
            """
          )
        statement.appendArgument(input)
      }
      else {
        /* NOP */
      }

      statement.append("ORDER BY slug COLLATE NOCASE ASC;")

      return
        try connection
        .fetch(using: statement) { dataRow -> ResourceTagListItemDSV in
          guard
            let id: ResourceTag.ID = dataRow.id.flatMap(ResourceTag.ID.init(rawValue:)),
            let slug: ResourceTag.Slug = dataRow.slug.flatMap(ResourceTag.Slug.init(rawValue:)),
            let shared: Bool = dataRow.shared,
            let contentCount: Int = dataRow.contentCount
          else {
            throw
              DatabaseIssue
              .error(
                underlyingError:
                  DatabaseDataInvalid
                  .error(for: ResourceTagListItemDSV.self)
              )
              .recording(dataRow, for: "dataRow")
          }

          return ResourceTagListItemDSV(
            id: id,
            slug: slug,
            shared: shared,
            contentCount: contentCount
          )
        }
    }

    nonisolated func executeAsync(
      _ input: String
    ) async throws -> Array<ResourceTagListItemDSV> {
      try await execute(
        input,
        connection: sessionDatabase.connection()
      )
    }

    return Self(
      execute: executeAsync(_:)
    )
  }
}

extension FeatureFactory {

  internal func usePassboltResourceTagsListFetchDatabaseOperation() {
    self.use(
      .disposable(
        ResourceTagsListFetchDatabaseOperation.self,
        load: ResourceTagsListFetchDatabaseOperation
          .load(features:)
      )
    )
  }
}
