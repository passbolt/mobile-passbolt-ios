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

extension ResourceEditDetailsFetchDatabaseOperation {

  @MainActor fileprivate static func load(
    features: FeatureFactory
  ) async throws -> Self {
    unowned let features: FeatureFactory = features

    let sessionDatabase: SessionDatabase = try await features.instance()

    nonisolated func execute(
      _ input: Resource.ID,
      connection: SQLiteConnection
    ) throws -> ResourceEditDetailsDSV {
      var statement: SQLiteStatement = """
        SELECT
          resourceEditView.id AS id,
          resourceEditView.name AS name,
          resourceEditView.url AS url,
          resourceEditView.username AS username,
          resourceEditView.description AS description,
          resourceEditView.typeID AS typeID,
          resourceEditView.typeSlug AS typeSlug,
          resourceEditView.typeName AS typeName,
          resourceEditView.fields AS fields
        FROM
          resourceEditView
        WHERE
          resourceEditView.id == ?1
        LIMIT
          1;
        """
      statement.appendArgument(input)

      return
        try connection
        .fetchFirst(using: statement) { dataRow -> ResourceEditDetailsDSV in
          guard
            let id: Resource.ID = dataRow.id.flatMap(Resource.ID.init(rawValue:)),
            let name: String = dataRow.name,
            let resourceTypeID: ResourceType.ID = dataRow.typeID.flatMap(ResourceType.ID.init(rawValue:)),
            let resourceTypeSlug: ResourceType.Slug = dataRow.typeSlug.flatMap(
              ResourceType.Slug.init(rawValue:)
            ),
            let resourceTypeName: String = dataRow.typeName,
            let rawFields: String = dataRow.fields
          else {
            throw
              DatabaseIssue
              .error(
                underlyingError:
                  DatabaseDataInvalid
                  .error(for: ResourceEditDetailsDSV.self)
              )
              .recording(dataRow, for: "dataRow")
          }

          return ResourceEditDetailsDSV(
            id: id,
            type: .init(
              id: resourceTypeID,
              slug: resourceTypeSlug,
              name: resourceTypeName,
              fields: ResourceFieldDSV.decodeArrayFrom(rawString: rawFields)
            ),
            parentFolderID: dataRow.parentFolderID.map(ResourceFolder.ID.init(rawValue:)),
            name: name,
            url: dataRow.url,
            username: dataRow.username,
            description: dataRow.description
          )
        }
    }

    nonisolated func executeAsync(
      _ input: Resource.ID
    ) async throws -> ResourceEditDetailsDSV {
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

  internal func usePassboltResourceEditDetailsFetchDatabaseOperation() {
    self.use(
      .disposable(
        ResourceEditDetailsFetchDatabaseOperation.self,
        load: ResourceEditDetailsFetchDatabaseOperation
          .load(features:)
      )
    )
  }
}
