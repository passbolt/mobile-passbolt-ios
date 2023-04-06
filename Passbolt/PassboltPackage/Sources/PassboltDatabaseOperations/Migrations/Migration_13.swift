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

  internal static var migration_13: Self {
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
       id TEXT UNIQUE NOT NULL PRIMARY KEY,
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
       id TEXT UNIQUE NOT NULL PRIMARY KEY,
       name TEXT NOT NULL
      );
      """,
      // - add usersGroups table - //
      """
      CREATE TABLE
       usersGroups
      (
       userID TEXT NOT NULL,
       userGroupID TEXT NOT NULL,
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
       id TEXT UNIQUE NOT NULL PRIMARY KEY,
       name TEXT NOT NULL,
       -- permission is current user permission, one of:
       -- 1 - read
       -- 7 - write
       -- 15 - owner
       permission INTEGER NOT NULL,
       shared BOOL NOT NULL,
       parentFolderID TEXT,
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
       permissionID STRING NOT NULL,
       resourceFolderID TEXT NOT NULL,
       userID TEXT NOT NULL,
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
       permissionID STRING NOT NULL,
       resourceFolderID TEXT NOT NULL,
       userGroupID TEXT NOT NULL,
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
       id TEXT NOT NULL PRIMARY KEY,
       -- slug is used to identify items
       slug TEXT UNIQUE NOT NULL,
       name TEXT NOT NULL
      );
      """,
      // - add resourceFields table - //
      """
      CREATE TABLE
       resourceFields
      (
       id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
       -- name of a field, used to identify it
       name TEXT NOT NULL,
       -- valueType is a type of a field value
       -- it is one of: [string, totp]
       valueType TEXT NOT NULL,
       -- value of encrypted determines if
       -- field is part of a secret
       encrypted BOOL NOT NULL,
       required BOOL NOT NULL,
       -- maximum is optional, it is minimum:
       -- * number of characters for string values
       minimum INTEGER DEFAULT NULL,
       -- maximum is optional, it is maximum:
       -- * number of characters for string values
       maximum INTEGER DEFAULT NULL
      );
      """,
      // - add resourceTypesFields table - //
      """
      CREATE TABLE
       resourceTypesFields
      (
       resourceTypeID TEXT NOT NULL,
       resourceFieldID INTEGER NOT NULL,
       FOREIGN KEY(resourceTypeID)
       REFERENCES resourceTypes(id)
       ON UPDATE CASCADE
       ON DELETE CASCADE,
       FOREIGN KEY(resourceFieldID)
       REFERENCES resourceFields(id)
       ON UPDATE CASCADE
       ON DELETE CASCADE,
       UNIQUE(resourceTypeID, resourceFieldID)
      );
      """,
      // - add resources table - //
      """
      CREATE TABLE
       resources
      (
       id TEXT UNIQUE NOT NULL PRIMARY KEY,
       name TEXT NOT NULL,
       -- permission is current user permission, one of:
       -- 1 - read
       -- 7 - write
       -- 15 - owner
       permission INTEGER NOT NULL,
       uri TEXT,
       username TEXT,
       -- id referencing resourceType
       typeID TEXT NOT NULL,
       -- description can be NULL if
       -- description is encrypted as a part of the secret
       description TEXT,
       parentFolderID TEXT DEFAULT NULL,
       favoriteID STRING,
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
       id TEXT UNIQUE NOT NULL PRIMARY KEY,
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
       resourceID TEXT NOT NULL,
       resourceTagID TEXT NOT NULL,
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
       permissionID STRING NOT NULL,
       resourceID TEXT NOT NULL,
       userID TEXT NOT NULL,
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
       permissionID STRING NOT NULL,
       resourceID TEXT NOT NULL,
       userGroupID TEXT NOT NULL,
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
      PRAGMA user_version = 14; -- persistent, used to track schema version
      """,
    ]
  }
}
