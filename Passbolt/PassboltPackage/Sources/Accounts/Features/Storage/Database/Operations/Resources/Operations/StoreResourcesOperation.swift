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

public typealias StoreResourcesOperation = DatabaseOperation<Array<Resource>, Void>

extension StoreResourcesOperation {

  internal static func using(
    _ connection: @escaping () async throws -> SQLiteConnection
  ) -> Self {
    withConnectionInTransaction(
      using: connection
    ) { conn, input in
      // We have to remove all previously stored data before updating
      // due to lack of ability to get information about deleted parts.
      // Until data diffing endpoint becomes implemented we are replacing
      // whole data set with the new one as an update.
      // We are getting all possible results anyway until diffing becomes implemented.
      // Please remove later on when diffing becomes available or other method of
      // deleting records selecively becomes implemented.
      //
      //
      // Delete currently stored resources
      try conn.execute("DELETE FROM resources;")
      // Delete currently stored tags
      try conn.execute("DELETE FROM tags;")
      // Delete currently stored group associations
      try conn.execute("DELETE FROM resourcesUserGroups;")

      // Insert or update all new tags
      for tag in input.flatMap(\.tags) {
        try conn
          .execute(
            upsertTagStatement,
            with: tag.id.rawValue,
            tag.slug,
            tag.shared
          )
      }

      // Insert or update all new resource
      for resource in input {
        try conn
          .execute(
            upsertResourceStatement,
            with: resource.id.rawValue,
            resource.name,
            resource.permission.rawValue,
            resource.url,
            resource.username,
            resource.typeID.rawValue,
            resource.description,
            resource.parentFolderID?.rawValue,
            resource.favorite,
            resource.modified
          )

        for tag in resource.tags {
          try conn
            .execute(
              upsertResourceTagStatement,
              with: resource.id.rawValue,
              tag.id.rawValue
            )
        }

        for groupID in resource.groups {
          try conn
            .execute(
              upsertResourcesUserGroupStatement,
              with: resource.id.rawValue,
              groupID.rawValue
            )
        }
      }
    }
  }
}

private let upsertResourceStatement: SQLiteStatement = """
  INSERT OR REPLACE INTO
    resources(
      id,
      name,
      permission,
      url,
      username,
      resourceTypeID,
      description,
      parentFolderID,
      favorite,
      modified
    )
  VALUES
    (
      ?1,
      ?2,
      ?3,
      ?4,
      ?5,
      ?6,
      ?7,
      (SELECT id FROM folders WHERE id = ?8),
      ?9,
      ?10
    );
  """

private let upsertTagStatement: SQLiteStatement = """
  INSERT OR REPLACE INTO
    tags(
      id,
      slug,
      shared
    )
  VALUES
    (
      ?1,
      ?2,
      ?3
    );
  """

private let upsertResourceTagStatement: SQLiteStatement =
  """
    INSERT OR REPLACE INTO
      resourceTags(
        resourceID,
        tagID
      )
    SELECT
      id,
      ?2
    FROM
      resources
    WHERE
      resources.id IS ?1
    ;
  """

private let upsertResourcesUserGroupStatement: SQLiteStatement =
  """
    INSERT OR REPLACE INTO
      resourcesUserGroups(
        resourceID,
        userGroupID
      )
    SELECT
      resources.id,
      userGroups.id
    FROM
      resources,
      userGroups
    WHERE
      resources.id IS ?1
    AND
      userGroups.id IS ?2
    ;
  """
