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

import Database

// swift-format-ignore: AlwaysUseLowerCamelCase
extension SQLiteMigration {

  internal static var migration_6: Self {
    [
      // - modify resources and folders tables constraints - //
      """
      DROP TABLE
        resources
      ; -- SQLite does not support altering column constraints
      """,
      """
      DROP TABLE
        folders
      ; -- SQLite does not support altering column constraints
      """,
      """
      CREATE TABLE
        folders
      (
        id TEXT UNIQUE NOT NULL PRIMARY KEY,
        name TEXT NOT NULL,
        permission TEXT NOT NULL, -- one of [read, write, owner]
        parentFolderID TEXT,
        FOREIGN KEY(parentFolderID) REFERENCES folders(id) ON DELETE CASCADE
      ); -- recreate folders table
      """,
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
        parentFolderID TEXT DEFAULT NULL,
        favorite INTEGER NOT NULL DEFAULT 0, -- boolean value, 0 interpreted as false, true otherwise
        modified INTEGER NOT NULL DEFAULT 0, -- timestamp value as epoch seconds
        FOREIGN KEY(resourceTypeID) REFERENCES resourceTypes(id) ON DELETE RESTRICT,
        FOREIGN KEY(parentFolderID) REFERENCES folders(id) ON DELETE SET NULL
      ); -- recreate resources table
      """,
      // - version bump - //
      """
      PRAGMA user_version = 7; -- persistent, used to track schema version
      """,
    ]
  }
}
