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

  @MainActor fileprivate static func load(
    features: FeatureFactory
  ) async throws -> Self {
    unowned let features: FeatureFactory = features

    let sessionDatabase: SessionDatabase = try await features.instance()

    nonisolated func execute(
      _ input: Array<ResourceTypeDSO>,
      connection: SQLiteConnection
    ) throws {
      // cleanup existing types as preparation for update
      try connection.execute("DELETE FROM resourceFields;")

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
            resourceType.slug,
            resourceType.name
          )
        )

        for field in resourceType.fields {
          let resourceFieldID: Int? =
            try connection.fetchFirst(
              using: .statement(
                """
                INSERT INTO
                  resourceFields(
                    name,
                    valueType,
                    required,
                    encrypted,
                    maxLength
                  )
                VALUES
                  (
                    ?1,
                    ?2,
                    ?3,
                    ?4,
                    ?5
                  )
                RETURNING
                  id AS id
                ;
                """,
                arguments: field.name.rawValue,
                field.valueType.rawValue,
                field.required,
                field.encrypted,
                field.maxLength
              )
            )?
            .id

          guard let resourceFieldID: Int = resourceFieldID
          else {
            throw
              DatabaseIssue
              .error(
                underlyingError:
                  DatabaseResultInvalid
                  .error("Failed to get inserted resource field id")
              )
          }
          try connection.execute(
            .statement(
              """
              INSERT INTO
                resourceTypesFields(
                  resourceTypeID,
                  resourceFieldID
                )
              VALUES
                (
                  ?1,
                  ?2
                )
              ;
              """,
              arguments: resourceType.id,
              resourceFieldID
            )
          )
        }
      }
    }

    nonisolated func executeAsync(
      _ input: Array<ResourceTypeDSO>
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

  internal func usePassboltResourceTypesStoreDatabaseOperation() {
    self.use(
      .disposable(
        ResourceTypesStoreDatabaseOperation.self,
        load: ResourceTypesStoreDatabaseOperation
          .load(features:)
      )
    )
  }
}
