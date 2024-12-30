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

extension ResourcesStoreDatabaseOperation {

  @Sendable fileprivate static func execute(
    _ input: Array<ResourceDTO>,
    connection: SQLiteConnection
  ) throws {
    // We have to remove all previously stored data before updating
    // due to lack of ability to get information about deleted parts.
    // Until data diffing endpoint becomes implemented we are replacing
    // whole data set with the new one as an update.
    // We are getting all possible results anyway until diffing becomes implemented.
    // Please remove later on when diffing becomes available or other method of
    // deleting records selecively becomes implemented.

    // Delete currently stored resources
    try connection.execute("DELETE FROM resources;")
    // Delete currently stored resource tags
    try connection.execute("DELETE FROM resourceTags;")

    // Insert or update all new resource
    for resource in input {
      try connection.execute(
        .statement(
          """
          INSERT INTO
            resources(
              id,
              typeID,
              parentFolderID,
              favoriteID,
              permission,
              modified,
              expired
            )
          VALUES
            (
              ?1,
              ?2,
              (
                SELECT
                  id
                FROM
                  resourceFolders
                WHERE
                  id == ?3
                LIMIT 1
              ),
              ?4,
              ?5,
              ?6,
              ?7
            )
          ON CONFLICT
            (
              id
            )
          DO UPDATE SET
            typeID=?2,
            parentFolderID=(
              SELECT
                id
              FROM
                resourceFolders
              WHERE
                id == ?3
              LIMIT 1
            ),
            favoriteID=?4,
            permission=?5,
            modified=?6,
            expired=?7
          ;
          """,
          arguments: resource.id,
          resource.typeID,
          resource.parentFolderID,
          resource.favoriteID,
          resource.permission.rawValue,
          resource.modified,
          resource.expired
        )
      )
      if let metadata = resource.metadata {
        try connection.execute(
          .statement(
          """
          INSERT INTO
            resourceMetadata(
              resource_id,
              data,
              name,
              username,
              description
            )
          VALUES
            (
              ?1,
              ?2,
              ?3,
              ?4,
              ?5
            )
          """,
          arguments:
            metadata.resourceId,
            metadata.data,
            metadata.name,
            metadata.username,
            metadata.description
          )
        )
        
        for uri in metadata.uris {
          try connection.execute(
            .statement(
            """
              INSERT INTO
                resourceURI(
                  resource_id,
                  uri
                )
              VALUES (
                ?1,
                ?2
              )
            """,
            arguments:
              uri.resourceId,
              uri.uri
            )
          )
        }
      }
      for resourceTag in resource.tags {
        try connection
          .execute(
            .statement(
              """
              INSERT INTO
                resourceTags(
                  id,
                  slug,
                  shared
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
                shared=?3
              ;
              """,
              arguments: resourceTag.id,
              resourceTag.slug,
              resourceTag.shared
            )
          )

        try connection
          .execute(
            .statement(
              """
              INSERT INTO
                resourcesTags(
                  resourceID,
                  resourceTagID
                )
              SELECT
                resources.id,
                resourceTags.id
              FROM
                resources,
                resourceTags
              WHERE
                resources.id == ?1
              AND
                resourceTags.id == ?2
              ;
              """,
              arguments: resource.id,
              resourceTag.id
            )
          )
      }

      for permission in resource.permissions {
        try connection.execute(
          permission.storeStatement
        )
      }
    }
  }
}

extension FeaturesRegistry {

  internal mutating func usePassboltResourcesStoreDatabaseOperation() {
    self.use(
      FeatureLoader.databaseOperationWithTransaction(
        of: ResourcesStoreDatabaseOperation.self,
        execute: ResourcesStoreDatabaseOperation.execute(_:connection:)
      ),
      in: SessionScope.self
    )
  }
}
