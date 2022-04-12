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

import Environment

public typealias StoreResourcesTypesOperation = DatabaseOperation<Array<ResourceType>, Void>

extension StoreResourcesTypesOperation {

  static func using(
    _ connection: @escaping () async throws -> SQLiteConnection
  ) -> Self {
    withConnectionInTransaction(
      using: connection
    ) { conn, input in
      // iterate over resources types to insert or update
      for resourceType in input {
        // cleanup existing types as preparation for update
        try conn
          .execute(
            cleanFieldsStatement,
            with: resourceType.id.rawValue
          )
        try conn
          .execute(
            upsertTypeStatement,
            with: resourceType.id.rawValue,
            resourceType.slug.rawValue,
            resourceType.name
          )

        // iterate over fields for given resource type
        for field in resourceType.properties {
          // insert fields for type (previous were deleted, no need for update)
          try conn
            .execute(
              insertFieldStatement,
              with: field.field.rawValue,
              field.type.rawValue,
              field.required,
              field.encrypted,
              field.maxLength
            )

          let fieldID: Int =
            try conn
            .fetch(
              fetchLastInsertedFieldStatement
            ) { rows in
              if let id: Int = rows.first?.id {
                return id
              }
              else {
                throw DatabaseIssue.error(
                  underlyingError:
                    DatabaseStatementExecutionFailure
                    .error("Failed to insert resource type field to the database")
                )
              }
            }

          // insert association between type and newly added field
          try conn
            .execute(
              insertTypeFieldStatement,
              with: resourceType.id.rawValue,
              fieldID
            )
        }
        // if nothing failed we have succeeded
      }
    }
  }
}

// remove all existing fields for given type
private let cleanFieldsStatement: SQLiteStatement = """
  DELETE FROM
    resourceFields
  WHERE
    id
  IN
    (
      SELECT
        resourceFieldID
      FROM
        resourceTypesFields
      WHERE
        resourceTypeID=?1
    )
  ;

  DELETE FROM
    resourceTypesFields
  WHERE
    resourceTypeID=?1
  ;
  """

// insert or update type
private let upsertTypeStatement: SQLiteStatement = """
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
  """

// insert single field
private let insertFieldStatement: SQLiteStatement = """
  INSERT INTO
    resourceFields(
      name,
      type,
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
  ;
  """

// select last inserted field id
// RETURNING syntax is available from SQLite 3.35
private let fetchLastInsertedFieldStatement: SQLiteStatement = """
  SELECT
    MAX(id) as id
  FROM
    resourceFields
  ;
  """

// insert association between type and field
private let insertTypeFieldStatement: SQLiteStatement = """
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
  """
