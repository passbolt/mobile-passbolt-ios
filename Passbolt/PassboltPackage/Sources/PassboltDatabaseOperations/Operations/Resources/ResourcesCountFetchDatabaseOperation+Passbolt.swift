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

import DatabaseOperations
import FeatureScopes
import Session

// MARK: - Implementation

extension ResourcesCountFetchDatabaseOperation {

  @Sendable fileprivate static func execute(
    _ input: Set<ResourceSpecification.Slug>,
    connection: SQLiteConnection
  ) throws -> Int {
    var statement: SQLiteStatement = """
       SELECT
      	COUNT(*) as count
       FROM
      	resources
       JOIN
      	resourceTypes
       ON
      	resources.typeID = resourceTypes.id
       WHERE
      	1 -- equivalent of true, used to simplify dynamic query building
      """

    // since we cannot use array in query directly
    // we are preparing it manually as argument for each element
    if input.count > 1 {
      statement.append(
        """
        AND (
        		SELECT
        			1
        		FROM
        			resourceTypes
        		WHERE
        			resourceTypes.id == resources.typeID
        		AND
        			resourceTypes.slug IN (
        """
      )
      for index in input.indices {
        if index == input.startIndex {
          statement.append("?")
        }
        else {
          statement.append(", ? ")
        }
        statement.appendArgument(input[index].rawValue)
      }
      statement.append(") LIMIT 1 )")
    }
    else if let includedTypeSlug: ResourceSpecification.Slug = input.first {
      statement.append(
        """
        AND (
        	SELECT
        		1
        	FROM
        		resourceTypes
        	WHERE
        		resourceTypes.id == resources.typeID
        	AND
        		resourceTypes.slug == ?
        	LIMIT 1
        )
        """
      )
      statement.appendArgument(includedTypeSlug)
    }
    else {
      /* NOP */
    }

    // end query
    statement.append(" LIMIT 1;")

    return
      try connection
      .fetchFirst(using: statement) { dataRow -> Int in
        if let count: Int = dataRow.count {
          return count
        }
        else {
          throw
            DatabaseIssue
            .error(
              underlyingError:
                DatabaseDataInvalid
                .error(for: Int.self)
            )
            .recording(dataRow, for: "dataRow")
        }
      }
  }
}

extension FeaturesRegistry {

  internal mutating func usePassboltResourcesCountFetchDatabaseOperation() {
    self.use(
      FeatureLoader.databaseOperation(
        of: ResourcesCountFetchDatabaseOperation.self,
        execute: ResourcesCountFetchDatabaseOperation.execute(_:connection:)
      ),
      in: SessionScope.self
    )
  }
}
