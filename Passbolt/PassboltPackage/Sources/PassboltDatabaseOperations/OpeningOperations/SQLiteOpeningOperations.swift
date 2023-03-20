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

/// Operations executed on SQLite database opening.
/// Useful to define database views which won't be persisted
/// so editing it won't require migrations.
internal enum SQLiteOpeningOperations {

  public static var all: Array<SQLiteStatement> {
    [
      // - add resourceTypesView - //
      """
      CREATE TEMPORARY VIEW
        resourceTypesView
      AS
      SELECT
        resourceTypes.id AS id,
        resourceTypes.slug AS slug,
        resourceTypes.name AS name,
        (
          SELECT
            group_concat(
              resourceFields.name
              || ":"
              || resourceFields.valueType
              || ",required="
              || resourceFields.required
              || ",encrypted="
              || resourceFields.encrypted
              || ",minimum="
              || ifnull(resourceFields.minimum, "0")
              || ",maximum="
              || ifnull(resourceFields.maximum, "100000"),
              ";"
            )
          FROM
            resourceTypesFields
          LEFT JOIN
            resourceFields
          ON
            resourceTypesFields.resourceFieldID == resourceFields.id
          WHERE
            resourceTypesFields.resourceTypeID == resourceTypes.id
        )
        AS fields
      FROM
        resourceTypes;
      """,
      // - add resourceDetailsView - //
      """
      CREATE TEMPORARY VIEW
        resourcesView
      AS
      SELECT
        resources.id AS id,
        resources.name AS name,
        resources.favoriteID AS favoriteID,
        resources.permission AS permission,
        resources.uri AS uri,
        resources.username AS username,
        resources.description AS description,
        resources.modified AS modified,
        resourceTypesView.id AS typeID,
        resourceTypesView.name AS typeName,
        resourceTypesView.slug AS typeSlug,
        resourceTypesView.fields AS fields
      FROM
        resources
      JOIN
        resourceTypesView
      ON
        resources.typeID == resourceTypesView.id;
      """,
    ]
  }
}
