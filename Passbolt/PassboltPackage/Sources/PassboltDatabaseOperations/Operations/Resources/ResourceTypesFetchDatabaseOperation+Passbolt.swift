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

extension ResourceTypesFetchDatabaseOperation {

  @MainActor fileprivate static func load(
    features: FeatureFactory
  ) async throws -> Self {
    unowned let features: FeatureFactory = features

    let sessionDatabase: SessionDatabase = try await features.instance()

    nonisolated func execute(
      _ input: Void,
      connection: SQLiteConnection
    ) throws -> Array<ResourceTypeDSV> {
      try connection
        .fetch(
          using: """
            SELECT
              id,
              slug,
              name,
              fields
            FROM
              resourceTypesView;
            """
        ) { dataRow in
          guard
            let id: ResourceType.ID = dataRow.id.flatMap(ResourceType.ID.init(rawValue:)),
            let slug: ResourceType.Slug = dataRow.slug.flatMap(ResourceType.Slug.init(rawValue:)),
            let name: String = dataRow.name,
            let rawFields: String = dataRow.fields
          else {
            throw
              DatabaseIssue
              .error(
                underlyingError:
                  DatabaseDataInvalid
                  .error(for: ResourceTypeDSV.self)
              )
          }

          return ResourceTypeDSV(
            id: id,
            slug: slug,
            name: name,
            fields: ResourceFieldDSV.decodeArrayFrom(rawString: rawFields)
          )
        }
    }

    nonisolated func executeAsync(
      _ input: Void
    ) async throws -> Array<ResourceTypeDSV> {
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

  internal func usePassboltResourceTypesFetchDatabaseOperation() {
    self.use(
      .disposable(
        ResourceTypesFetchDatabaseOperation.self,
        load: ResourceTypesFetchDatabaseOperation
          .load(features:)
      )
    )
  }
}
