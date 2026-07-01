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

import Commons
import DatabaseOperations
import FeatureScopes
import Session

// MARK: - Implementation

extension ResourcesStoreDatabaseOperation {

  @Sendable fileprivate static func execute(
    _ input: ResourcesStoreDatabaseOperationDescription.Input,
    connection: SQLiteConnection
  ) throws {

    // `changed` were decrypted → full metadata/tag/FTS store; `unchanged` keep `modified` → only
    // access/folder/favorite/state reconciled at the end.
    let changedResources: Array<ResourceDTO> = input.changed
    let unchangedResources: Array<ResourceDTO> = input.unchanged

    // Suppress the (expensive) resourceSearchIndex FTS triggers for the whole batch; we rebuild the
    // affected rows once at the end instead of letting every child insert re-index the resource.
    // (See Migration_30 for the guard flag and Migration_27 for the canonical FTS build query.)
    try connection.execute(.statement("UPDATE resourceSearchIndexSync SET enabled = 0;"))
    try connection.execute(
      .statement(
        "CREATE TEMP TABLE IF NOT EXISTS resourceSearchRebuildBatch (resourceID BLOB NOT NULL PRIMARY KEY);"
      )
    )
    try connection.execute(.statement("DELETE FROM resourceSearchRebuildBatch;"))

    // Permissions can change without bumping `modified`, so reconcile every seen resource: clear all
    // seen ids here, then re-insert current grants below (storeStatement's ON CONFLICT is only a guard).
    let allSeenResourceIDs: Array<Resource.ID> = changedResources.map(\.id) + unchangedResources.map(\.id)
    let permissionBatchSize: Int = 256
    for idsChunk: ArraySlice<Resource.ID> in allSeenResourceIDs.chunked(into: permissionBatchSize) {
      var removeUserPermissions: SQLiteStatement = "DELETE FROM usersResources WHERE resourceID"
      removeUserPermissions.append(.in(Set(idsChunk)))
      removeUserPermissions.append(";")
      try connection.execute(removeUserPermissions)

      var removeUserGroupPermissions: SQLiteStatement = "DELETE FROM userGroupsResources WHERE resourceID"
      removeUserGroupPermissions.append(.in(Set(idsChunk)))
      removeUserGroupPermissions.append(";")
      try connection.execute(removeUserGroupPermissions)
    }

    // Collect tag data while iterating resources so it can be written in a few batched statements
    // after the loop, instead of two row-by-row inserts per (resource, tag) pair.
    var uniqueTags: Dictionary<ResourceTag.ID, ResourceTag> = .init()
    var tagLinks: Array<(resourceID: Resource.ID, tagID: ResourceTag.ID)> = .init()

    // Insert or update all new resources. The same ~10 SQL statements run once per resource,
    // so reuse their compiled handles across the whole batch instead of recompiling each time.
    try connection.withPreparedStatements { prepared in
      for resource: ResourceDTO in changedResources {
        // Remember this resource for the single post-batch FTS rebuild (temp table has no triggers).
        try prepared.execute(
          .statement(
            "INSERT OR IGNORE INTO resourceSearchRebuildBatch (resourceID) VALUES (?1);",
            arguments: resource.id
          )
        )
        try prepared.execute(
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
                expired,
                metadata_key_id,
                metadata_key_type,
                state
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
                ?7,
                ?8,
                ?9,
                ?10
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
              expired=?7,
              metadata_key_id=?8,
              metadata_key_type=?9,
              state = ?10
            ;
            """,
            arguments: resource.id,
            resource.typeID,
            resource.parentFolderID,
            resource.favoriteID,
            resource.permission.rawValue,
            resource.modified,
            resource.expired,
            resource.metadataKeyId,
            resource.metadataKeyType?.rawValue,
            ResourceState.updated.rawValue
          )
        )
        if let metadata = resource.metadata {
          try prepared.execute(
            .statement(
              """
              INSERT INTO
                resourceMetadata(
                  resource_id,
                  data,
                  name,
                  username,
                  description,
                  icon_type,
                  icon_value,
                  icon_background_color
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
                  ?8
                )
              ON CONFLICT
                (
                  resource_id
                )
              DO UPDATE SET
                data=?2,
                name=?3,
                username=?4,
                description=?5,
                icon_type=?6,
                icon_value=?7,
                icon_background_color=?8
              ;
              """,
              arguments:
                metadata.resourceId,
              metadata.data,
              metadata.name,
              metadata.username,
              metadata.description,
              metadata.icon?.type.rawValue,
              metadata.icon?.value?.rawValue,
              metadata.icon?.backgroundColor
            )
          )
          let removeURIsStatement: SQLiteStatement = .statement(
            "DELETE FROM resourceURI WHERE resource_id = ?1",
            arguments: resource.id
          )
          try prepared.execute(removeURIsStatement)

          for uri in metadata.uris {
            try prepared.execute(
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
                  ON CONFLICT
                    (
                      resource_id,
                      uri
                    )
                  DO NOTHING
                """,
                arguments:
                  uri.resourceId,
                uri.uri
              )
            )
          }

          for customField in metadata.customFields {
            try prepared.execute(
              .statement(
                """
                  INSERT INTO
                    resourceCustomFields(
                      id,
                      resourceID,
                      key
                    )
                  VALUES (
                    ?1,
                    ?2,
                    ?3
                  )
                  ON CONFLICT
                    (
                      id
                    )
                  DO NOTHING
                """,
                arguments:
                  customField.id.rawValue.uuidString,
                resource.id,
                customField.metadataKey
              )
            )
          }
        }

        // Tag associations are stored in batched statements after this loop (see below).
        for resourceTag: ResourceTag in resource.tags {
          uniqueTags[resourceTag.id] = resourceTag
          tagLinks.append((resourceID: resource.id, tagID: resourceTag.id))
        }

        for permission in resource.permissions {
          try prepared.execute(
            permission.storeStatement
          )
        }
      }
    }

    // Replace tag associations for the stored resources in a few batched statements (chunked to stay
    // under SQLite's bound-parameter limit): clear existing links, upsert the unique tags, then insert
    // the resource-tag links. Tags are upserted before links (FK), and links land before the FTS
    // rebuild below reads them.
    let tagBatchSize: Int = 256
    let storedResourceIDs: Array<Resource.ID> = changedResources.map(\.id)
    for resourceIDsChunk: ArraySlice<Resource.ID> in storedResourceIDs.chunked(into: tagBatchSize) {
      var deleteStatement: SQLiteStatement = "DELETE FROM resourcesTags WHERE resourceID"
      deleteStatement.append(.in(Set(resourceIDsChunk)))
      deleteStatement.append(";")
      try connection.execute(deleteStatement)
    }

    let uniqueTagList: Array<ResourceTag> = Array(uniqueTags.values)
    for tagsChunk: ArraySlice<ResourceTag> in uniqueTagList.chunked(into: tagBatchSize) {
      var upsertStatement: SQLiteStatement = "INSERT INTO resourceTags( id, slug, shared ) VALUES "
      for (offset, resourceTag): (Int, ResourceTag) in tagsChunk.enumerated() {
        if offset > 0 { upsertStatement.append(", ") }
        upsertStatement.append("( ?, ?, ? )")
        upsertStatement.appendArguments(resourceTag.id, resourceTag.slug, resourceTag.shared)
      }
      upsertStatement.append("ON CONFLICT( id ) DO UPDATE SET slug = excluded.slug, shared = excluded.shared;")
      try connection.execute(upsertStatement)
    }

    for tagLinksChunk: ArraySlice<(resourceID: Resource.ID, tagID: ResourceTag.ID)> in tagLinks
      .chunked(into: tagBatchSize)
    {
      var linkStatement: SQLiteStatement = "INSERT INTO resourcesTags( resourceID, resourceTagID ) VALUES "
      for (offset, tagLink): (Int, (resourceID: Resource.ID, tagID: ResourceTag.ID)) in tagLinksChunk
        .enumerated()
      {
        if offset > 0 { linkStatement.append(", ") }
        linkStatement.append("( ?, ? )")
        linkStatement.appendArguments(tagLink.resourceID, tagLink.tagID)
      }
      linkStatement.append(";")
      try connection.execute(linkStatement)
    }

    // Rebuild both FTS indexes once, for exactly the resources stored above, then re-enable the
    // triggers. The SELECT mirrors Migration_27's populate query, scoped to this batch. All of this
    // runs inside the operation's transaction, so a failure rolls the flag and index back together.
    try connection.execute(
      .statement(
        """
        DELETE FROM resourceSearchIndex
        WHERE resourceID IN (SELECT resourceID FROM resourceSearchRebuildBatch);
        """
      )
    )
    try connection.execute(
      .statement(
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
        WHERE resources.id IN (SELECT resourceID FROM resourceSearchRebuildBatch);
        """
      )
    )
    try connection.execute(
      .statement(
        """
        DELETE FROM resourceSearchIndexSubstring
        WHERE resourceID IN (SELECT resourceID FROM resourceSearchRebuildBatch);
        """
      )
    )
    try connection.execute(
      .statement(
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
        WHERE resources.id IN (SELECT resourceID FROM resourceSearchRebuildBatch);
        """
      )
    )
    try connection.execute(.statement("DELETE FROM resourceSearchRebuildBatch;"))
    try connection.execute(.statement("UPDATE resourceSearchIndexSync SET enabled = 1;"))

    // Reconcile unchanged resources' access/folder/favorite (all mutable without bumping `modified`).
    // No FTS work — none of these columns are indexed.
    guard unchangedResources.isEmpty == false
    else { return }

    // Re-insert current grants (cleared for these ids above). Reuse compiled handles across the batch.
    try connection.withPreparedStatements { prepared in
      for resource: ResourceDTO in unchangedResources {
        for permission: GenericPermissionDTO in resource.permissions {
          try prepared.execute(permission.storeStatement)
        }
      }
    }

    // Apply folder + favorite + state as one set-based UPDATE via a temp table; the parentFolderID
    // existence guard mirrors the resource upsert so a deleted folder resolves to NULL.
    try connection.execute(
      .statement(
        """
        CREATE TEMP TABLE IF NOT EXISTS unchangedResourceReconcile (
          resourceID BLOB NOT NULL PRIMARY KEY,
          parentFolderID BLOB,
          favoriteID BLOB
        );
        """
      )
    )
    try connection.execute(.statement("DELETE FROM unchangedResourceReconcile;"))
    let reconcileBatchSize: Int = 256
    for resourcesChunk: ArraySlice<ResourceDTO> in unchangedResources.chunked(into: reconcileBatchSize) {
      var reconcileStatement: SQLiteStatement =
        "INSERT OR REPLACE INTO unchangedResourceReconcile ( resourceID, parentFolderID, favoriteID ) VALUES "
      for (offset, resource): (Int, ResourceDTO) in resourcesChunk.enumerated() {
        if offset > 0 { reconcileStatement.append(", ") }
        reconcileStatement.append("( ?, ?, ? )")
        reconcileStatement.appendArgument(resource.id)
        reconcileStatement.appendArgument(resource.parentFolderID)
        reconcileStatement.appendArgument(resource.favoriteID)
      }
      reconcileStatement.append(";")
      try connection.execute(reconcileStatement)
    }
    try connection.execute(
      .statement(
        """
        UPDATE resources
        SET
          parentFolderID = (
            SELECT resourceFolders.id
            FROM resourceFolders
            WHERE resourceFolders.id = (
              SELECT unchangedResourceReconcile.parentFolderID
              FROM unchangedResourceReconcile
              WHERE unchangedResourceReconcile.resourceID = resources.id
            )
          ),
          favoriteID = (
            SELECT unchangedResourceReconcile.favoriteID
            FROM unchangedResourceReconcile
            WHERE unchangedResourceReconcile.resourceID = resources.id
          ),
          state = NULL
        WHERE id IN ( SELECT resourceID FROM unchangedResourceReconcile );
        """
      )
    )
    try connection.execute(.statement("DELETE FROM unchangedResourceReconcile;"))
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
