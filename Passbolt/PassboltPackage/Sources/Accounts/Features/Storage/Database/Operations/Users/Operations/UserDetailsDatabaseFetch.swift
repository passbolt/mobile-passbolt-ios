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

public struct UserDetailsDatabaseFetch {

  public var execute: @StorageAccessActor (User.ID) async throws -> UserDetailsDSV

  public init(
    execute: @escaping @StorageAccessActor (Input) async throws -> Output
  ) {
    self.execute = execute
  }
}

extension UserDetailsDatabaseFetch: DatabaseOperationFeature {

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
            id AS id,
            username AS username,
            firstName AS firstName,
            lastName AS lastName,
            publicPGPKeyFingerprint AS fingerprint,
            avatarImageURL AS avatarImageURL
          FROM
            users
          WHERE
            users.id == ?1
          LIMIT 1;
          """,
          arguments: input
        )

      return
        try conn
        .fetchFirst(using: statement) { dataRow -> UserDetailsDSV in
          guard
            let id: User.ID = dataRow.id.flatMap(User.ID.init(rawValue:)),
            let username: String = dataRow.username,
            let firstName: String = dataRow.firstName,
            let lastName: String = dataRow.lastName,
            let fingerprint: Fingerprint = dataRow.fingerprint.flatMap(Fingerprint.init(rawValue:)),
            let avatarImageURL: URLString = dataRow.avatarImageURL.flatMap(URLString.init(rawValue:))
          else {
            throw
              DatabaseIssue
              .error(
                underlyingError:
                  DatabaseDataInvalid
                  .error(for: ResourceUserGroupListItemDSV.self)
              )
          }

          return UserDetailsDSV(
            id: id,
            username: username,
            firstName: firstName,
            lastName: lastName,
            fingerprint: fingerprint,
            avatarImageURL: avatarImageURL
          )
        }
    }
  }
}
