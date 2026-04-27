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

  internal static var migration_27: Self {
    .init(
      steps:
        // -- Create FTS5 virtual table with unicode61 tokenizer for accent/case-insensitive prefix search -- //
        """
        CREATE VIRTUAL TABLE
          resourceSearchIndex
        USING fts5(
          resourceID UNINDEXED,
          name,
          username,
          uris,
          tags,
          customFieldKeys,
          tokenize='unicode61 remove_diacritics 2'
        ); -- create FTS5 unicode61 search index
        """,
      // -- Create FTS5 virtual table with trigram tokenizer for substring (infix/suffix) search -- //
      """
      CREATE VIRTUAL TABLE
        resourceSearchIndexSubstring
      USING fts5(
        resourceID UNINDEXED,
        name,
        username,
        uris,
        tags,
        customFieldKeys,
        tokenize='trigram'
      ); -- create FTS5 trigram search index
      """,
      // -- Populate unicode61 FTS index from existing data -- //
      """
      INSERT INTO resourceSearchIndex(resourceID, name, username, uris, tags, customFieldKeys)
      SELECT
        resources.id,
        COALESCE(resourceMetadata.name, ''),
        COALESCE(resourceMetadata.username, ''),
        COALESCE(
          (SELECT group_concat(resourceURI.uri, ' ')
           FROM resourceURI
           WHERE resourceURI.resource_id = resources.id),
          ''
        ),
        COALESCE(
          (SELECT group_concat(resourceTags.slug, ' ')
           FROM resourcesTags
           JOIN resourceTags ON resourcesTags.resourceTagID = resourceTags.id
           WHERE resourcesTags.resourceID = resources.id),
          ''
        ),
        COALESCE(
          (SELECT group_concat(resourceCustomFields.key, ' ')
           FROM resourceCustomFields
           WHERE resourceCustomFields.resourceID = resources.id),
          ''
        )
      FROM resources
      LEFT JOIN resourceMetadata ON resources.id = resourceMetadata.resource_id
      ; -- populate unicode61 FTS index
      """,
      // -- Populate trigram FTS index from existing data -- //
      """
      INSERT INTO resourceSearchIndexSubstring(resourceID, name, username, uris, tags, customFieldKeys)
      SELECT
        resources.id,
        COALESCE(resourceMetadata.name, ''),
        COALESCE(resourceMetadata.username, ''),
        COALESCE(
          (SELECT group_concat(resourceURI.uri, ' ')
           FROM resourceURI
           WHERE resourceURI.resource_id = resources.id),
          ''
        ),
        COALESCE(
          (SELECT group_concat(resourceTags.slug, ' ')
           FROM resourcesTags
           JOIN resourceTags ON resourcesTags.resourceTagID = resourceTags.id
           WHERE resourcesTags.resourceID = resources.id),
          ''
        ),
        COALESCE(
          (SELECT group_concat(resourceCustomFields.key, ' ')
           FROM resourceCustomFields
           WHERE resourceCustomFields.resourceID = resources.id),
          ''
        )
      FROM resources
      LEFT JOIN resourceMetadata ON resources.id = resourceMetadata.resource_id
      ; -- populate trigram FTS index
      """,
      // -- Trigger: resourceMetadata AFTER INSERT -- //
      """
      CREATE TRIGGER resourceSearchIndex_afterInsert_resourceMetadata
      AFTER INSERT ON resourceMetadata
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
      // -- Trigger: resourceMetadata AFTER UPDATE -- //
      """
      CREATE TRIGGER resourceSearchIndex_afterUpdate_resourceMetadata
      AFTER UPDATE ON resourceMetadata
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
      // -- Trigger: resourceMetadata AFTER DELETE -- //
      """
      CREATE TRIGGER resourceSearchIndex_afterDelete_resourceMetadata
      AFTER DELETE ON resourceMetadata
      BEGIN
        DELETE FROM resourceSearchIndex WHERE resourceID = OLD.resource_id;
        DELETE FROM resourceSearchIndexSubstring WHERE resourceID = OLD.resource_id;
      END; -- trigger: cleanup FTS on resourceMetadata delete
      """,
      // -- Trigger: resourceURI AFTER INSERT -- //
      """
      CREATE TRIGGER resourceSearchIndex_afterInsert_resourceURI
      AFTER INSERT ON resourceURI
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
      // -- Trigger: resourceURI AFTER DELETE -- //
      """
      CREATE TRIGGER resourceSearchIndex_afterDelete_resourceURI
      AFTER DELETE ON resourceURI
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
      // -- Trigger: resourcesTags AFTER INSERT -- //
      """
      CREATE TRIGGER resourceSearchIndex_afterInsert_resourcesTags
      AFTER INSERT ON resourcesTags
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
      // -- Trigger: resourcesTags AFTER DELETE -- //
      """
      CREATE TRIGGER resourceSearchIndex_afterDelete_resourcesTags
      AFTER DELETE ON resourcesTags
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
      // -- Trigger: resourceCustomFields AFTER INSERT -- //
      """
      CREATE TRIGGER resourceSearchIndex_afterInsert_resourceCustomFields
      AFTER INSERT ON resourceCustomFields
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
      // -- Trigger: resourceCustomFields AFTER DELETE -- //
      """
      CREATE TRIGGER resourceSearchIndex_afterDelete_resourceCustomFields
      AFTER DELETE ON resourceCustomFields
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
      // -- Trigger: resources AFTER DELETE (cleanup FTS) -- //
      """
      CREATE TRIGGER resourceSearchIndex_afterDelete_resources
      AFTER DELETE ON resources
      BEGIN
        DELETE FROM resourceSearchIndex WHERE resourceID = OLD.id;
        DELETE FROM resourceSearchIndexSubstring WHERE resourceID = OLD.id;
      END; -- trigger: cleanup FTS on resource delete
      """,
      // - version bump - //
      "PRAGMA user_version = 28; -- persistent, used to track schema version"
    )
  }
}
