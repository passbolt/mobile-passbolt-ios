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

  internal static var migration_28: Self {
    .init(
      steps:
        // -- Tags: Create FTS5 virtual table with unicode61 tokenizer -- //
        """
        CREATE VIRTUAL TABLE
          tagSearchIndex
        USING fts5(
          tagID UNINDEXED,
          slug,
          tokenize='unicode61 remove_diacritics 2'
        ); -- create FTS5 unicode61 tag search index
        """,
      // -- Tags: Create FTS5 virtual table with trigram tokenizer -- //
      """
      CREATE VIRTUAL TABLE
        tagSearchIndexSubstring
      USING fts5(
        tagID UNINDEXED,
        slug,
        tokenize='trigram'
      ); -- create FTS5 trigram tag search index
      """,
      // -- Tags: Populate unicode61 FTS index from existing data -- //
      """
      INSERT INTO tagSearchIndex(tagID, slug)
      SELECT
        id,
        COALESCE(slug, '')
      FROM resourceTags
      ; -- populate unicode61 tag FTS index
      """,
      // -- Tags: Populate trigram FTS index from existing data -- //
      """
      INSERT INTO tagSearchIndexSubstring(tagID, slug)
      SELECT
        id,
        COALESCE(slug, '')
      FROM resourceTags
      ; -- populate trigram tag FTS index
      """,
      // -- Tags: Trigger AFTER INSERT -- //
      """
      CREATE TRIGGER tagSearchIndex_afterInsert_resourceTags
      AFTER INSERT ON resourceTags
      BEGIN
        DELETE FROM tagSearchIndex WHERE tagID = NEW.id;
        INSERT INTO tagSearchIndex(tagID, slug) VALUES (NEW.id, COALESCE(NEW.slug, ''));
        DELETE FROM tagSearchIndexSubstring WHERE tagID = NEW.id;
        INSERT INTO tagSearchIndexSubstring(tagID, slug) VALUES (NEW.id, COALESCE(NEW.slug, ''));
      END; -- trigger: rebuild tag FTS on resourceTags insert
      """,
      // -- Tags: Trigger AFTER UPDATE -- //
      """
      CREATE TRIGGER tagSearchIndex_afterUpdate_resourceTags
      AFTER UPDATE ON resourceTags
      BEGIN
        DELETE FROM tagSearchIndex WHERE tagID = OLD.id;
        INSERT INTO tagSearchIndex(tagID, slug) VALUES (NEW.id, COALESCE(NEW.slug, ''));
        DELETE FROM tagSearchIndexSubstring WHERE tagID = OLD.id;
        INSERT INTO tagSearchIndexSubstring(tagID, slug) VALUES (NEW.id, COALESCE(NEW.slug, ''));
      END; -- trigger: rebuild tag FTS on resourceTags update
      """,
      // -- Tags: Trigger AFTER DELETE -- //
      """
      CREATE TRIGGER tagSearchIndex_afterDelete_resourceTags
      AFTER DELETE ON resourceTags
      BEGIN
        DELETE FROM tagSearchIndex WHERE tagID = OLD.id;
        DELETE FROM tagSearchIndexSubstring WHERE tagID = OLD.id;
      END; -- trigger: cleanup tag FTS on resourceTags delete
      """,
      // -- Folders: Create FTS5 virtual table with unicode61 tokenizer -- //
      """
      CREATE VIRTUAL TABLE
        folderSearchIndex
      USING fts5(
        folderID UNINDEXED,
        name,
        tokenize='unicode61 remove_diacritics 2'
      ); -- create FTS5 unicode61 folder search index
      """,
      // -- Folders: Create FTS5 virtual table with trigram tokenizer -- //
      """
      CREATE VIRTUAL TABLE
        folderSearchIndexSubstring
      USING fts5(
        folderID UNINDEXED,
        name,
        tokenize='trigram'
      ); -- create FTS5 trigram folder search index
      """,
      // -- Folders: Populate unicode61 FTS index from existing data -- //
      """
      INSERT INTO folderSearchIndex(folderID, name)
      SELECT
        id,
        COALESCE(name, '')
      FROM resourceFolders
      ; -- populate unicode61 folder FTS index
      """,
      // -- Folders: Populate trigram FTS index from existing data -- //
      """
      INSERT INTO folderSearchIndexSubstring(folderID, name)
      SELECT
        id,
        COALESCE(name, '')
      FROM resourceFolders
      ; -- populate trigram folder FTS index
      """,
      // -- Folders: Trigger AFTER INSERT -- //
      """
      CREATE TRIGGER folderSearchIndex_afterInsert_resourceFolders
      AFTER INSERT ON resourceFolders
      BEGIN
        DELETE FROM folderSearchIndex WHERE folderID = NEW.id;
        INSERT INTO folderSearchIndex(folderID, name) VALUES (NEW.id, COALESCE(NEW.name, ''));
        DELETE FROM folderSearchIndexSubstring WHERE folderID = NEW.id;
        INSERT INTO folderSearchIndexSubstring(folderID, name) VALUES (NEW.id, COALESCE(NEW.name, ''));
      END; -- trigger: rebuild folder FTS on resourceFolders insert
      """,
      // -- Folders: Trigger AFTER UPDATE -- //
      """
      CREATE TRIGGER folderSearchIndex_afterUpdate_resourceFolders
      AFTER UPDATE ON resourceFolders
      BEGIN
        DELETE FROM folderSearchIndex WHERE folderID = OLD.id;
        INSERT INTO folderSearchIndex(folderID, name) VALUES (NEW.id, COALESCE(NEW.name, ''));
        DELETE FROM folderSearchIndexSubstring WHERE folderID = OLD.id;
        INSERT INTO folderSearchIndexSubstring(folderID, name) VALUES (NEW.id, COALESCE(NEW.name, ''));
      END; -- trigger: rebuild folder FTS on resourceFolders update
      """,
      // -- Folders: Trigger AFTER DELETE -- //
      """
      CREATE TRIGGER folderSearchIndex_afterDelete_resourceFolders
      AFTER DELETE ON resourceFolders
      BEGIN
        DELETE FROM folderSearchIndex WHERE folderID = OLD.id;
        DELETE FROM folderSearchIndexSubstring WHERE folderID = OLD.id;
      END; -- trigger: cleanup folder FTS on resourceFolders delete
      """,
      // -- User Groups: Create FTS5 virtual table with unicode61 tokenizer -- //
      """
      CREATE VIRTUAL TABLE
        userGroupSearchIndex
      USING fts5(
        userGroupID UNINDEXED,
        name,
        tokenize='unicode61 remove_diacritics 2'
      ); -- create FTS5 unicode61 user group search index
      """,
      // -- User Groups: Create FTS5 virtual table with trigram tokenizer -- //
      """
      CREATE VIRTUAL TABLE
        userGroupSearchIndexSubstring
      USING fts5(
        userGroupID UNINDEXED,
        name,
        tokenize='trigram'
      ); -- create FTS5 trigram user group search index
      """,
      // -- User Groups: Populate unicode61 FTS index from existing data -- //
      """
      INSERT INTO userGroupSearchIndex(userGroupID, name)
      SELECT
        id,
        COALESCE(name, '')
      FROM userGroups
      ; -- populate unicode61 user group FTS index
      """,
      // -- User Groups: Populate trigram FTS index from existing data -- //
      """
      INSERT INTO userGroupSearchIndexSubstring(userGroupID, name)
      SELECT
        id,
        COALESCE(name, '')
      FROM userGroups
      ; -- populate trigram user group FTS index
      """,
      // -- User Groups: Trigger AFTER INSERT -- //
      """
      CREATE TRIGGER userGroupSearchIndex_afterInsert_userGroups
      AFTER INSERT ON userGroups
      BEGIN
        DELETE FROM userGroupSearchIndex WHERE userGroupID = NEW.id;
        INSERT INTO userGroupSearchIndex(userGroupID, name) VALUES (NEW.id, COALESCE(NEW.name, ''));
        DELETE FROM userGroupSearchIndexSubstring WHERE userGroupID = NEW.id;
        INSERT INTO userGroupSearchIndexSubstring(userGroupID, name) VALUES (NEW.id, COALESCE(NEW.name, ''));
      END; -- trigger: rebuild user group FTS on userGroups insert
      """,
      // -- User Groups: Trigger AFTER UPDATE -- //
      """
      CREATE TRIGGER userGroupSearchIndex_afterUpdate_userGroups
      AFTER UPDATE ON userGroups
      BEGIN
        DELETE FROM userGroupSearchIndex WHERE userGroupID = OLD.id;
        INSERT INTO userGroupSearchIndex(userGroupID, name) VALUES (NEW.id, COALESCE(NEW.name, ''));
        DELETE FROM userGroupSearchIndexSubstring WHERE userGroupID = OLD.id;
        INSERT INTO userGroupSearchIndexSubstring(userGroupID, name) VALUES (NEW.id, COALESCE(NEW.name, ''));
      END; -- trigger: rebuild user group FTS on userGroups update
      """,
      // -- User Groups: Trigger AFTER DELETE -- //
      """
      CREATE TRIGGER userGroupSearchIndex_afterDelete_userGroups
      AFTER DELETE ON userGroups
      BEGIN
        DELETE FROM userGroupSearchIndex WHERE userGroupID = OLD.id;
        DELETE FROM userGroupSearchIndexSubstring WHERE userGroupID = OLD.id;
      END; -- trigger: cleanup user group FTS on userGroups delete
      """,
      // - version bump - //
      "PRAGMA user_version = 29; -- persistent, used to track schema version"
    )
  }
}
