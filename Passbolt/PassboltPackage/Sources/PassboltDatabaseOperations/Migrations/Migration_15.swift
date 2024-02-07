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

  internal static var migration_15: Self {
    [
      // - remove all existing schema tables if migrating from previous versions - //
      "DROP TABLE IF EXISTS userGroupsResources",
      "DROP TABLE IF EXISTS usersResources",
      "DROP TABLE IF EXISTS resourcesTags",
      "DROP TABLE IF EXISTS resourceTags",
      "DROP TABLE IF EXISTS resources",
      "DROP TABLE IF EXISTS resourceTypesFields",
      "DROP TABLE IF EXISTS resourceFields",
      "DROP TABLE IF EXISTS resourceTypes",
      "DROP TABLE IF EXISTS userGroupsResourceFolders",
      "DROP TABLE IF EXISTS usersResourceFolders;",
      "DROP TABLE IF EXISTS resourceFolders;",
      "DROP TABLE IF EXISTS usersGroups;",
      "DROP TABLE IF EXISTS userGroups;",
      "DROP TABLE IF EXISTS users;",
      "DROP TABLE IF EXISTS updates;",
      // - (re)create schema - //
      // - ################ - //
      // - add users table - //
      """
      CREATE TABLE
       users
      (
       id BLOB UNIQUE NOT NULL PRIMARY KEY,
       username TEXT NOT NULL,
       firstName TEXT NOT NULL,
       lastName TEXT NOT NULL,
       publicPGPKeyFingerprint TEXT NOT NULL,
       armoredPublicPGPKey TEXT NOT NULL,
       avatarImageURL TEXT
      );
      """,
      // - add userGroups table - //
      """
      CREATE TABLE
       userGroups
      (
       id BLOB UNIQUE NOT NULL PRIMARY KEY,
       name TEXT NOT NULL
      );
      """,
      // - add usersGroups table - //
      """
      CREATE TABLE
       usersGroups
      (
       userID BLOB NOT NULL,
       userGroupID BLOB NOT NULL,
       FOREIGN KEY(userID)
       REFERENCES users(id)
       ON UPDATE CASCADE
       ON DELETE CASCADE,
       FOREIGN KEY(userGroupID)
       REFERENCES userGroups(id)
       ON UPDATE CASCADE
       ON DELETE CASCADE,
       UNIQUE(userGroupID, userID)
      );
      """,
      // - add resourceFolders table - //
      """
      CREATE TABLE
       resourceFolders
      (
       id BLOB UNIQUE NOT NULL PRIMARY KEY,
       name TEXT NOT NULL,
       -- permission is current user permission, one of:
       -- 1 - read
       -- 7 - write
       -- 15 - owner
       permission INTEGER NOT NULL,
       shared BOOL NOT NULL,
       parentFolderID BLOB,
       FOREIGN KEY(parentFolderID)
       REFERENCES resourceFolders(id)
       ON UPDATE CASCADE
       ON DELETE CASCADE
      );
      """,
      // - add usersResourceFolders table - //
      """
      CREATE TABLE
       usersResourceFolders
      (
       permissionID BLOB NOT NULL,
       resourceFolderID BLOB NOT NULL,
       userID BLOB NOT NULL,
       -- permission is a user permission on a resource folder,
       -- it is one of:
       -- 1 - read
       -- 7 - write
       -- 15 - owner
       permission INTEGER NOT NULL,
       FOREIGN KEY(resourceFolderID)
       REFERENCES resourceFolders(id)
       ON UPDATE CASCADE
       ON DELETE CASCADE,
       FOREIGN KEY(userID)
       REFERENCES users(id)
       ON UPDATE CASCADE
       ON DELETE CASCADE,
       UNIQUE(resourceFolderID, userID)
      );
      """,
      // - add resourceFoldersUserGroups table - //
      """
      CREATE TABLE
       userGroupsResourceFolders
      (
       permissionID BLOB NOT NULL,
       resourceFolderID BLOB NOT NULL,
       userGroupID BLOB NOT NULL,
       -- permission is a user group permission on a resource folder,
       -- it is one of:
       -- 1 - read
       -- 7 - write
       -- 15 - owner
       permission INTEGER NOT NULL,
       FOREIGN KEY(resourceFolderID)
       REFERENCES resourceFolders(id)
       ON UPDATE CASCADE
       ON DELETE CASCADE,
       FOREIGN KEY(userGroupID)
       REFERENCES userGroups(id)
       ON UPDATE CASCADE
       ON DELETE CASCADE,
       UNIQUE(resourceFolderID, userGroupID)
      );
      """,
      // - add resourceTypes table - //
      """
      CREATE TABLE
       resourceTypes
      (
       id BLOB NOT NULL PRIMARY KEY,
       -- slug is used to identify items
       slug TEXT UNIQUE NOT NULL,
       name TEXT NOT NULL
      );
      """,
      // - add resources table - //
      """
      CREATE TABLE
       resources
      (
       id BLOB UNIQUE NOT NULL PRIMARY KEY,
       name TEXT NOT NULL,
       -- permission is current user permission, one of:
       -- 1 - read
       -- 7 - write
       -- 15 - owner
       permission INTEGER NOT NULL,
       uri TEXT,
       username TEXT,
       -- id referencing resourceType
       typeID BLOB NOT NULL,
       -- description can be NULL if
       -- description is encrypted as a part of the secret
       description TEXT,
       parentFolderID BLOB DEFAULT NULL,
       favoriteID BLOB,
       -- modified is a timestamp value as epoch seconds
       modified INTEGER NOT NULL DEFAULT 0,
       FOREIGN KEY(typeID)
       REFERENCES resourceTypes(id)
       ON UPDATE CASCADE
       ON DELETE CASCADE,
       FOREIGN KEY(parentFolderID)
       REFERENCES resourceFolders(id)
       ON UPDATE CASCADE
       ON DELETE SET NULL
      );
      """,
      // - add resourceTags table - //
      """
      CREATE TABLE
       resourceTags
      (
       id BLOB UNIQUE NOT NULL PRIMARY KEY,
       -- slug is used to identify items
       slug TEXT NOT NULL,
       shared BOOL NOT NULL
      );
      """,
      // - add resourcesTags table - //
      """
      CREATE TABLE
       resourcesTags
      (
       resourceID BLOB NOT NULL,
       resourceTagID BLOB NOT NULL,
       FOREIGN KEY(resourceID)
       REFERENCES resources(id)
       ON UPDATE CASCADE
       ON DELETE CASCADE,
       FOREIGN KEY(resourceTagID)
       REFERENCES resourceTags(id)
       ON UPDATE CASCADE
       ON DELETE CASCADE,
       UNIQUE(resourceID, resourceTagID)
      );
      """,
      // - add usersResources table - //
      """
      CREATE TABLE
       usersResources
      (
       permissionID BLOB NOT NULL,
       resourceID BLOB NOT NULL,
       userID BLOB NOT NULL,
       -- permission is a user permission on a resource,
       -- it is one of:
       -- 1 - read
       -- 7 - write
       -- 15 - owner
       permission INTEGER NOT NULL,
       FOREIGN KEY(resourceID)
       REFERENCES resources(id)
       ON UPDATE CASCADE
       ON DELETE CASCADE,
       FOREIGN KEY(userID)
       REFERENCES users(id)
       ON UPDATE CASCADE
       ON DELETE CASCADE,
       UNIQUE(resourceID, userID)
      );
      """,
      // - add userGroupsResources table - //
      """
      CREATE TABLE
       userGroupsResources
      (
       permissionID BLOB NOT NULL,
       resourceID BLOB NOT NULL,
       userGroupID BLOB NOT NULL,
       -- permission is a user group permission on a resource,
       -- it is one of:
       -- 1 - read
       -- 7 - write
       -- 15 - owner
       permission INTEGER NOT NULL,
       FOREIGN KEY(resourceID)
       REFERENCES resources(id)
       ON UPDATE CASCADE
       ON DELETE CASCADE,
       FOREIGN KEY(userGroupID)
       REFERENCES userGroups(id)
       ON UPDATE CASCADE
       ON DELETE CASCADE,
       UNIQUE(resourceID, userGroupID)
      );
      """,
      // - version bump - //
      """
      PRAGMA user_version = 16; -- persistent, used to track schema version
      """,
    ]
  }
}
