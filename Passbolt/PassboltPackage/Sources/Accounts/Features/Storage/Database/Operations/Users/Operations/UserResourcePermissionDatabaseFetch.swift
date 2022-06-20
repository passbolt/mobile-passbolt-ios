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

import CommonModels
import Environment

public struct UserResourcePermissionDatabaseFetch {

  public var execute:
    @StorageAccessActor ((userID: User.ID, resourceID: Resource.ID)) async throws -> PermissionTypeDSV?

  public init(
    execute: @escaping @StorageAccessActor (Input) async throws -> Output
  ) {
    self.execute = execute
  }
}

extension UserResourcePermissionDatabaseFetch: DatabaseOperationFeature {

  public static func using(
    _ connection: @escaping () async throws -> SQLiteConnection
  ) -> Self {
    withConnection(
      using: connection
    ) { conn, input in
      let statement: SQLiteStatement =
        .statement(
          """
          SELECT
            usersResources.permissionType AS permissionType
          FROM
            usersResources
          WHERE
            usersResources.userID == ?1
          AND
            usersResources.resourceID == ?2
          ;
          """,
          arguments: input.userID,
          input.resourceID
        )

      return
        try conn
        .fetchFirst(using: statement) { dataRow -> PermissionTypeDSV in
          guard
            let permissionType: PermissionTypeDSV = dataRow.permissionType.flatMap(PermissionTypeDSV.init(rawValue:))
          else {
            throw
              DatabaseIssue
              .error(
                underlyingError:
                  DatabaseDataInvalid
                  .error(for: PermissionTypeDSV.self)
              )
          }

          return permissionType
        }
    }
  }
}
