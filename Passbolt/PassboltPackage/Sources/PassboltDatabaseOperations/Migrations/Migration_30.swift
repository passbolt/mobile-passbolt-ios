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

  /// Adds a guard so the (expensive) `resourceSearchIndex` FTS triggers from `migration_27` can be
  /// temporarily suppressed during a bulk resource store, which instead rebuilds the affected rows
  /// once (see `ResourcesStoreDatabaseOperation`). The triggers are otherwise unchanged, so normal
  /// single-row edits keep the search index up to date. This migration only creates one control
  /// table and re-creates triggers — it never drops or mutates stored data.
  internal static var migration_30: Self {
    .init(
      steps:
        // -- Control flag: when 0, the resourceSearchIndex triggers are suppressed (bulk mode) -- //
        """
        CREATE TABLE resourceSearchIndexSync (
          enabled INTEGER NOT NULL DEFAULT 1
        ); -- FTS trigger suppression flag
        """,
      """
      INSERT INTO resourceSearchIndexSync (enabled) VALUES (1); -- enabled by default
      """,
      // -- Re-create resourceMetadata AFTER INSERT (guarded) -- //
      "DROP TRIGGER IF EXISTS resourceSearchIndex_afterInsert_resourceMetadata;",
      """
      CREATE TRIGGER resourceSearchIndex_afterInsert_resourceMetadata
      AFTER INSERT ON resourceMetadata
      WHEN (SELECT enabled FROM resourceSearchIndexSync) = 1
      BEGIN
        DELETE FROM resourceSearchIndex WHERE resourceID = NEW.resource_id;
        INSERT INTO resourceSearchIndex(resourceID, name, username, uris, tags, customFieldKeys)
        SELECT
          NEW.resource_id,
          COALESCE(NEW.name, ''),
          COALESCE(NEW.username, ''),
          COALESCE(
            (SELECT group_concat(uri, ' ') FROM resourceURI WHERE resource_id = NEW.resource_id),
            ''
          ),
          COALESCE(
            (SELECT group_concat(rt.slug, ' ')
             FROM resourcesTags rst JOIN resourceTags rt ON rst.resourceTagID = rt.id
             WHERE rst.resourceID = NEW.resource_id),
            ''
          ),
          COALESCE(
            (SELECT group_concat(key, ' ') FROM resourceCustomFields WHERE resourceID = NEW.resource_id),
            ''
          );
        DELETE FROM resourceSearchIndexSubstring WHERE resourceID = NEW.resource_id;
        INSERT INTO resourceSearchIndexSubstring(resourceID, name, username, uris, tags, customFieldKeys)
        SELECT
          NEW.resource_id,
          COALESCE(NEW.name, ''),
          COALESCE(NEW.username, ''),
          COALESCE(
            (SELECT group_concat(uri, ' ') FROM resourceURI WHERE resource_id = NEW.resource_id),
            ''
          ),
          COALESCE(
            (SELECT group_concat(rt.slug, ' ')
             FROM resourcesTags rst JOIN resourceTags rt ON rst.resourceTagID = rt.id
             WHERE rst.resourceID = NEW.resource_id),
            ''
          ),
          COALESCE(
            (SELECT group_concat(key, ' ') FROM resourceCustomFields WHERE resourceID = NEW.resource_id),
            ''
          );
      END; -- trigger: rebuild FTS on resourceMetadata insert
      """,
      // -- Re-create resourceMetadata AFTER UPDATE (guarded) -- //
      "DROP TRIGGER IF EXISTS resourceSearchIndex_afterUpdate_resourceMetadata;",
      """
      CREATE TRIGGER resourceSearchIndex_afterUpdate_resourceMetadata
      AFTER UPDATE ON resourceMetadata
      WHEN (SELECT enabled FROM resourceSearchIndexSync) = 1
      BEGIN
        DELETE FROM resourceSearchIndex WHERE resourceID = NEW.resource_id;
        INSERT INTO resourceSearchIndex(resourceID, name, username, uris, tags, customFieldKeys)
        SELECT
          NEW.resource_id,
          COALESCE(NEW.name, ''),
          COALESCE(NEW.username, ''),
          COALESCE(
            (SELECT group_concat(uri, ' ') FROM resourceURI WHERE resource_id = NEW.resource_id),
            ''
          ),
          COALESCE(
            (SELECT group_concat(rt.slug, ' ')
             FROM resourcesTags rst JOIN resourceTags rt ON rst.resourceTagID = rt.id
             WHERE rst.resourceID = NEW.resource_id),
            ''
          ),
          COALESCE(
            (SELECT group_concat(key, ' ') FROM resourceCustomFields WHERE resourceID = NEW.resource_id),
            ''
          );
        DELETE FROM resourceSearchIndexSubstring WHERE resourceID = NEW.resource_id;
        INSERT INTO resourceSearchIndexSubstring(resourceID, name, username, uris, tags, customFieldKeys)
        SELECT
          NEW.resource_id,
          COALESCE(NEW.name, ''),
          COALESCE(NEW.username, ''),
          COALESCE(
            (SELECT group_concat(uri, ' ') FROM resourceURI WHERE resource_id = NEW.resource_id),
            ''
          ),
          COALESCE(
            (SELECT group_concat(rt.slug, ' ')
             FROM resourcesTags rst JOIN resourceTags rt ON rst.resourceTagID = rt.id
             WHERE rst.resourceID = NEW.resource_id),
            ''
          ),
          COALESCE(
            (SELECT group_concat(key, ' ') FROM resourceCustomFields WHERE resourceID = NEW.resource_id),
            ''
          );
      END; -- trigger: rebuild FTS on resourceMetadata update
      """,
      // -- Re-create resourceMetadata AFTER DELETE (guarded) -- //
      "DROP TRIGGER IF EXISTS resourceSearchIndex_afterDelete_resourceMetadata;",
      """
      CREATE TRIGGER resourceSearchIndex_afterDelete_resourceMetadata
      AFTER DELETE ON resourceMetadata
      WHEN (SELECT enabled FROM resourceSearchIndexSync) = 1
      BEGIN
        DELETE FROM resourceSearchIndex WHERE resourceID = OLD.resource_id;
        DELETE FROM resourceSearchIndexSubstring WHERE resourceID = OLD.resource_id;
      END; -- trigger: cleanup FTS on resourceMetadata delete
      """,
      // -- Re-create resourceURI AFTER INSERT (guarded) -- //
      "DROP TRIGGER IF EXISTS resourceSearchIndex_afterInsert_resourceURI;",
      """
      CREATE TRIGGER resourceSearchIndex_afterInsert_resourceURI
      AFTER INSERT ON resourceURI
      WHEN (SELECT enabled FROM resourceSearchIndexSync) = 1
      BEGIN
        DELETE FROM resourceSearchIndex WHERE resourceID = NEW.resource_id;
        INSERT INTO resourceSearchIndex(resourceID, name, username, uris, tags, customFieldKeys)
        SELECT
          NEW.resource_id,
          COALESCE(rm.name, ''),
          COALESCE(rm.username, ''),
          COALESCE(
            (SELECT group_concat(uri, ' ') FROM resourceURI WHERE resource_id = NEW.resource_id),
            ''
          ),
          COALESCE(
            (SELECT group_concat(rt.slug, ' ')
             FROM resourcesTags rst JOIN resourceTags rt ON rst.resourceTagID = rt.id
             WHERE rst.resourceID = NEW.resource_id),
            ''
          ),
          COALESCE(
            (SELECT group_concat(key, ' ') FROM resourceCustomFields WHERE resourceID = NEW.resource_id),
            ''
          )
        FROM resourceMetadata rm
        WHERE rm.resource_id = NEW.resource_id;
        DELETE FROM resourceSearchIndexSubstring WHERE resourceID = NEW.resource_id;
        INSERT INTO resourceSearchIndexSubstring(resourceID, name, username, uris, tags, customFieldKeys)
        SELECT
          NEW.resource_id,
          COALESCE(rm.name, ''),
          COALESCE(rm.username, ''),
          COALESCE(
            (SELECT group_concat(uri, ' ') FROM resourceURI WHERE resource_id = NEW.resource_id),
            ''
          ),
          COALESCE(
            (SELECT group_concat(rt.slug, ' ')
             FROM resourcesTags rst JOIN resourceTags rt ON rst.resourceTagID = rt.id
             WHERE rst.resourceID = NEW.resource_id),
            ''
          ),
          COALESCE(
            (SELECT group_concat(key, ' ') FROM resourceCustomFields WHERE resourceID = NEW.resource_id),
            ''
          )
        FROM resourceMetadata rm
        WHERE rm.resource_id = NEW.resource_id;
      END; -- trigger: rebuild FTS on resourceURI insert
      """,
      // -- Re-create resourceURI AFTER DELETE (guarded) -- //
      "DROP TRIGGER IF EXISTS resourceSearchIndex_afterDelete_resourceURI;",
      """
      CREATE TRIGGER resourceSearchIndex_afterDelete_resourceURI
      AFTER DELETE ON resourceURI
      WHEN (SELECT enabled FROM resourceSearchIndexSync) = 1
      BEGIN
        DELETE FROM resourceSearchIndex WHERE resourceID = OLD.resource_id;
        INSERT INTO resourceSearchIndex(resourceID, name, username, uris, tags, customFieldKeys)
        SELECT
          OLD.resource_id,
          COALESCE(rm.name, ''),
          COALESCE(rm.username, ''),
          COALESCE(
            (SELECT group_concat(uri, ' ') FROM resourceURI WHERE resource_id = OLD.resource_id),
            ''
          ),
          COALESCE(
            (SELECT group_concat(rt.slug, ' ')
             FROM resourcesTags rst JOIN resourceTags rt ON rst.resourceTagID = rt.id
             WHERE rst.resourceID = OLD.resource_id),
            ''
          ),
          COALESCE(
            (SELECT group_concat(key, ' ') FROM resourceCustomFields WHERE resourceID = OLD.resource_id),
            ''
          )
        FROM resourceMetadata rm
        WHERE rm.resource_id = OLD.resource_id;
        DELETE FROM resourceSearchIndexSubstring WHERE resourceID = OLD.resource_id;
        INSERT INTO resourceSearchIndexSubstring(resourceID, name, username, uris, tags, customFieldKeys)
        SELECT
          OLD.resource_id,
          COALESCE(rm.name, ''),
          COALESCE(rm.username, ''),
          COALESCE(
            (SELECT group_concat(uri, ' ') FROM resourceURI WHERE resource_id = OLD.resource_id),
            ''
          ),
          COALESCE(
            (SELECT group_concat(rt.slug, ' ')
             FROM resourcesTags rst JOIN resourceTags rt ON rst.resourceTagID = rt.id
             WHERE rst.resourceID = OLD.resource_id),
            ''
          ),
          COALESCE(
            (SELECT group_concat(key, ' ') FROM resourceCustomFields WHERE resourceID = OLD.resource_id),
            ''
          )
        FROM resourceMetadata rm
        WHERE rm.resource_id = OLD.resource_id;
      END; -- trigger: rebuild FTS on resourceURI delete
      """,
      // -- Re-create resourcesTags AFTER INSERT (guarded) -- //
      "DROP TRIGGER IF EXISTS resourceSearchIndex_afterInsert_resourcesTags;",
      """
      CREATE TRIGGER resourceSearchIndex_afterInsert_resourcesTags
      AFTER INSERT ON resourcesTags
      WHEN (SELECT enabled FROM resourceSearchIndexSync) = 1
      BEGIN
        DELETE FROM resourceSearchIndex WHERE resourceID = NEW.resourceID;
        INSERT INTO resourceSearchIndex(resourceID, name, username, uris, tags, customFieldKeys)
        SELECT
          NEW.resourceID,
          COALESCE(rm.name, ''),
          COALESCE(rm.username, ''),
          COALESCE(
            (SELECT group_concat(uri, ' ') FROM resourceURI WHERE resource_id = NEW.resourceID),
            ''
          ),
          COALESCE(
            (SELECT group_concat(rt.slug, ' ')
             FROM resourcesTags rst JOIN resourceTags rt ON rst.resourceTagID = rt.id
             WHERE rst.resourceID = NEW.resourceID),
            ''
          ),
          COALESCE(
            (SELECT group_concat(key, ' ') FROM resourceCustomFields WHERE resourceID = NEW.resourceID),
            ''
          )
        FROM resourceMetadata rm
        WHERE rm.resource_id = NEW.resourceID;
        DELETE FROM resourceSearchIndexSubstring WHERE resourceID = NEW.resourceID;
        INSERT INTO resourceSearchIndexSubstring(resourceID, name, username, uris, tags, customFieldKeys)
        SELECT
          NEW.resourceID,
          COALESCE(rm.name, ''),
          COALESCE(rm.username, ''),
          COALESCE(
            (SELECT group_concat(uri, ' ') FROM resourceURI WHERE resource_id = NEW.resourceID),
            ''
          ),
          COALESCE(
            (SELECT group_concat(rt.slug, ' ')
             FROM resourcesTags rst JOIN resourceTags rt ON rst.resourceTagID = rt.id
             WHERE rst.resourceID = NEW.resourceID),
            ''
          ),
          COALESCE(
            (SELECT group_concat(key, ' ') FROM resourceCustomFields WHERE resourceID = NEW.resourceID),
            ''
          )
        FROM resourceMetadata rm
        WHERE rm.resource_id = NEW.resourceID;
      END; -- trigger: rebuild FTS on resourcesTags insert
      """,
      // -- Re-create resourcesTags AFTER DELETE (guarded) -- //
      "DROP TRIGGER IF EXISTS resourceSearchIndex_afterDelete_resourcesTags;",
      """
      CREATE TRIGGER resourceSearchIndex_afterDelete_resourcesTags
      AFTER DELETE ON resourcesTags
      WHEN (SELECT enabled FROM resourceSearchIndexSync) = 1
      BEGIN
        DELETE FROM resourceSearchIndex WHERE resourceID = OLD.resourceID;
        INSERT INTO resourceSearchIndex(resourceID, name, username, uris, tags, customFieldKeys)
        SELECT
          OLD.resourceID,
          COALESCE(rm.name, ''),
          COALESCE(rm.username, ''),
          COALESCE(
            (SELECT group_concat(uri, ' ') FROM resourceURI WHERE resource_id = OLD.resourceID),
            ''
          ),
          COALESCE(
            (SELECT group_concat(rt.slug, ' ')
             FROM resourcesTags rst JOIN resourceTags rt ON rst.resourceTagID = rt.id
             WHERE rst.resourceID = OLD.resourceID),
            ''
          ),
          COALESCE(
            (SELECT group_concat(key, ' ') FROM resourceCustomFields WHERE resourceID = OLD.resourceID),
            ''
          )
        FROM resourceMetadata rm
        WHERE rm.resource_id = OLD.resourceID;
        DELETE FROM resourceSearchIndexSubstring WHERE resourceID = OLD.resourceID;
        INSERT INTO resourceSearchIndexSubstring(resourceID, name, username, uris, tags, customFieldKeys)
        SELECT
          OLD.resourceID,
          COALESCE(rm.name, ''),
          COALESCE(rm.username, ''),
          COALESCE(
            (SELECT group_concat(uri, ' ') FROM resourceURI WHERE resource_id = OLD.resourceID),
            ''
          ),
          COALESCE(
            (SELECT group_concat(rt.slug, ' ')
             FROM resourcesTags rst JOIN resourceTags rt ON rst.resourceTagID = rt.id
             WHERE rst.resourceID = OLD.resourceID),
            ''
          ),
          COALESCE(
            (SELECT group_concat(key, ' ') FROM resourceCustomFields WHERE resourceID = OLD.resourceID),
            ''
          )
        FROM resourceMetadata rm
        WHERE rm.resource_id = OLD.resourceID;
      END; -- trigger: rebuild FTS on resourcesTags delete
      """,
      // -- Re-create resourceCustomFields AFTER INSERT (guarded) -- //
      "DROP TRIGGER IF EXISTS resourceSearchIndex_afterInsert_resourceCustomFields;",
      """
      CREATE TRIGGER resourceSearchIndex_afterInsert_resourceCustomFields
      AFTER INSERT ON resourceCustomFields
      WHEN (SELECT enabled FROM resourceSearchIndexSync) = 1
      BEGIN
        DELETE FROM resourceSearchIndex WHERE resourceID = NEW.resourceID;
        INSERT INTO resourceSearchIndex(resourceID, name, username, uris, tags, customFieldKeys)
        SELECT
          NEW.resourceID,
          COALESCE(rm.name, ''),
          COALESCE(rm.username, ''),
          COALESCE(
            (SELECT group_concat(uri, ' ') FROM resourceURI WHERE resource_id = NEW.resourceID),
            ''
          ),
          COALESCE(
            (SELECT group_concat(rt.slug, ' ')
             FROM resourcesTags rst JOIN resourceTags rt ON rst.resourceTagID = rt.id
             WHERE rst.resourceID = NEW.resourceID),
            ''
          ),
          COALESCE(
            (SELECT group_concat(key, ' ') FROM resourceCustomFields WHERE resourceID = NEW.resourceID),
            ''
          )
        FROM resourceMetadata rm
        WHERE rm.resource_id = NEW.resourceID;
        DELETE FROM resourceSearchIndexSubstring WHERE resourceID = NEW.resourceID;
        INSERT INTO resourceSearchIndexSubstring(resourceID, name, username, uris, tags, customFieldKeys)
        SELECT
          NEW.resourceID,
          COALESCE(rm.name, ''),
          COALESCE(rm.username, ''),
          COALESCE(
            (SELECT group_concat(uri, ' ') FROM resourceURI WHERE resource_id = NEW.resourceID),
            ''
          ),
          COALESCE(
            (SELECT group_concat(rt.slug, ' ')
             FROM resourcesTags rst JOIN resourceTags rt ON rst.resourceTagID = rt.id
             WHERE rst.resourceID = NEW.resourceID),
            ''
          ),
          COALESCE(
            (SELECT group_concat(key, ' ') FROM resourceCustomFields WHERE resourceID = NEW.resourceID),
            ''
          )
        FROM resourceMetadata rm
        WHERE rm.resource_id = NEW.resourceID;
      END; -- trigger: rebuild FTS on resourceCustomFields insert
      """,
      // -- Re-create resourceCustomFields AFTER DELETE (guarded) -- //
      "DROP TRIGGER IF EXISTS resourceSearchIndex_afterDelete_resourceCustomFields;",
      """
      CREATE TRIGGER resourceSearchIndex_afterDelete_resourceCustomFields
      AFTER DELETE ON resourceCustomFields
      WHEN (SELECT enabled FROM resourceSearchIndexSync) = 1
      BEGIN
        DELETE FROM resourceSearchIndex WHERE resourceID = OLD.resourceID;
        INSERT INTO resourceSearchIndex(resourceID, name, username, uris, tags, customFieldKeys)
        SELECT
          OLD.resourceID,
          COALESCE(rm.name, ''),
          COALESCE(rm.username, ''),
          COALESCE(
            (SELECT group_concat(uri, ' ') FROM resourceURI WHERE resource_id = OLD.resourceID),
            ''
          ),
          COALESCE(
            (SELECT group_concat(rt.slug, ' ')
             FROM resourcesTags rst JOIN resourceTags rt ON rst.resourceTagID = rt.id
             WHERE rst.resourceID = OLD.resourceID),
            ''
          ),
          COALESCE(
            (SELECT group_concat(key, ' ') FROM resourceCustomFields WHERE resourceID = OLD.resourceID),
            ''
          )
        FROM resourceMetadata rm
        WHERE rm.resource_id = OLD.resourceID;
        DELETE FROM resourceSearchIndexSubstring WHERE resourceID = OLD.resourceID;
        INSERT INTO resourceSearchIndexSubstring(resourceID, name, username, uris, tags, customFieldKeys)
        SELECT
          OLD.resourceID,
          COALESCE(rm.name, ''),
          COALESCE(rm.username, ''),
          COALESCE(
            (SELECT group_concat(uri, ' ') FROM resourceURI WHERE resource_id = OLD.resourceID),
            ''
          ),
          COALESCE(
            (SELECT group_concat(rt.slug, ' ')
             FROM resourcesTags rst JOIN resourceTags rt ON rst.resourceTagID = rt.id
             WHERE rst.resourceID = OLD.resourceID),
            ''
          ),
          COALESCE(
            (SELECT group_concat(key, ' ') FROM resourceCustomFields WHERE resourceID = OLD.resourceID),
            ''
          )
        FROM resourceMetadata rm
        WHERE rm.resource_id = OLD.resourceID;
      END; -- trigger: rebuild FTS on resourceCustomFields delete
      """,
      // -- Re-create resources AFTER DELETE (guarded cleanup) -- //
      "DROP TRIGGER IF EXISTS resourceSearchIndex_afterDelete_resources;",
      """
      CREATE TRIGGER resourceSearchIndex_afterDelete_resources
      AFTER DELETE ON resources
      WHEN (SELECT enabled FROM resourceSearchIndexSync) = 1
      BEGIN
        DELETE FROM resourceSearchIndex WHERE resourceID = OLD.id;
        DELETE FROM resourceSearchIndexSubstring WHERE resourceID = OLD.id;
      END; -- trigger: cleanup FTS on resource delete
      """,
      // - version bump - //
      "PRAGMA user_version = 31; -- persistent, used to track schema version"
    )
  }
}
