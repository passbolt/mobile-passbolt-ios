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

  internal static var migration_9: Self {
    [
      // - add userGroups table - //
      """
      CREATE TABLE
        userGroups
      (
        id TEXT UNIQUE NOT NULL PRIMARY KEY,
        name TEXT NOT NULL
      ); -- create user groups table
      """,
      // - add resourcesUserGroups table - //
      """
      CREATE TABLE
        resourcesUserGroups
      (
        resourceID TEXT NOT NULL,
        userGroupID TEXT NOT NULL,
        FOREIGN KEY(resourceID) REFERENCES resources(id) ON DELETE CASCADE,
        FOREIGN KEY(userGroupID) REFERENCES userGroups(id) ON DELETE CASCADE,
        UNIQUE(resourceID, userGroupID)
      ); -- create resources user groups table
      """,
      // - version bump - //
      """
      PRAGMA user_version = 10; -- persistent, used to track schema version
      """,
    ]
  }
}
