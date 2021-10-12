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

// swift-format-ignore: AlwaysUseLowerCamelCase
extension SQLiteMigration {

  internal static var migration_0: Self {
    [
      // - resources - //
      """
      CREATE TABLE
        resources
      (
        id TEXT UNIQUE NOT NULL PRIMARY KEY,
        name TEXT NOT NULL,
        permission TEXT NOT NULL, -- one of [read, write, owner]
        url TEXT,
        username TEXT,
        resourceTypeID TEXT NOT NULL,
        description TEXT, -- might be NULL if secret type contains description
        parentFolderID TEXT,
        FOREIGN KEY(resourceTypeID) REFERENCES resourceTypes(id) ON DELETE RESTRICT,
        FOREIGN KEY(parentFolderID) REFERENCES folders(id) ON DELETE RESTRICT
      );
      """,
      // - secretTypes - //
      """
      CREATE TABLE
        resourceTypes
      (
        id TEXT NOT NULL PRIMARY KEY,
        name TEXT NOT NULL -- name of secret type
      );
      """,
      // - secretFields - //
      """
      CREATE TABLE
        resourceFields
      (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL, -- name of field
        type TEXT NOT NULL, -- type of field - one or more of [string, int] separated with pipe i.e. string|int
        required BOOL NOT NULL,
        encrypted BOOL NOT NULL, -- determines if field is part of secret
        maxLength INTEGER -- maximum number of characters for string
      );
      """,
      // - secretTypesFields - //
      """
      CREATE TABLE
        resourceTypesFields
      (
        resourceTypeID TEXT NOT NULL,
        resourceFieldID INTEGER NOT NULL,
        FOREIGN KEY(resourceTypeID) REFERENCES resourceTypes(id) ON DELETE CASCADE,
        FOREIGN KEY(resourceFieldID) REFERENCES resourceFields(id) ON DELETE CASCADE,
        UNIQUE(resourceTypeID, resourceFieldID)
      );
      """,
      // - folders - //
      """
      CREATE TABLE
        folders
      (
        id TEXT UNIQUE NOT NULL PRIMARY KEY,
        name TEXT NOT NULL,
        permission TEXT NOT NULL, -- one of [read, write, owner]
        parentFolderID TEXT,
        FOREIGN KEY(parentFolderID) REFERENCES folders(id) ON DELETE RESTRICT
      );
      """,
      // - updates - //
      """
      CREATE TABLE
        updates
      (
        lastUpdateTimestamp INTEGER UNIQUE NOT NULL -- epoch timestamp, intended to be a single record
      );
      """,
      """
      INSERT INTO
        updates
      (
        lastUpdateTimestamp
      )
      VALUES
      (
        0 -- initial value of last update which is 01/01/1970 as default
      );
      """,
      // - resourcesListView - //
      """
      CREATE VIEW
        resourcesListView
      AS
      SELECT
        id,
        name,
        permission,
        url,
        username
      FROM
        resources
      ORDER BY
        name ASC;
      """,
      // - resourceDetailsView - //
      """
      CREATE VIEW
        resourceDetailsView
      AS
      SELECT
        resources.id AS id,
        resources.name AS name,
        resources.permission AS permission,
        resources.url AS url,
        resources.username AS username,
        resources.description AS description,
        (
          SELECT
            group_concat(
              resourceFields.name
              || ":"
              || resourceFields.type
              || ";required="
              || resourceFields.required
              || ";encrypted="
              || resourceFields.encrypted
              || ";maxLength="
              || resourceFields.maxLength
            )
          FROM
            resourceFields
          JOIN
            resourceTypesFields
          ON
            resourceFields.id == resourceTypesFields.resourceFieldID
          JOIN
            resourceTypes
          ON
            resourceTypes.id == resourceTypesFields.resourceTypeID
          WHERE
            resources.resourceTypeID == resourceTypes.id
        )
        AS resourceFields
      FROM
        resources;
      """,
      // - version bump - //
      """
      PRAGMA user_version = 1; -- persistent, used to track schema version
      """,
    ]
  }
}
