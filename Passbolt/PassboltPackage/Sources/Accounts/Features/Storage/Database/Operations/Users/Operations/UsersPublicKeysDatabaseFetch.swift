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

public struct UsersPublicKeysDatabaseFetch {

  public var execute: @StorageAccessActor (Array<User.ID>) async throws -> Array<UserPublicKeyDSV>

  public init(
    execute: @escaping @StorageAccessActor (Input) async throws -> Output
  ) {
    self.execute = execute
  }
}

extension UsersPublicKeysDatabaseFetch: DatabaseOperationFeature {

  public static func using(
    _ connection: @escaping () async throws -> SQLiteConnection
  ) -> Self {
    withConnection(
      using: connection
    ) { conn, input in
      var statement: SQLiteStatement =
        .statement(
          """
          SELECT
            id AS id,
            armoredPublicPGPKey AS publicKey
          FROM
            users
          """
        )

      // since we cannot use array in query directly
      // we are preparing it manually as argument for each element
      if input.count > 1 {
        statement.append(
          """
          WHERE
            users.id
          IN (
          """
        )
        for index in input.indices {
          if index == input.startIndex {
            statement.append("?")
          }
          else {
            statement.append(", ?")
          }
          statement.appendArgument(input[index])
        }
        statement.append(")")
      }
      else if let userID: User.ID = input.first {
        statement.append(
          """
          WHERE
            users.id == ?
          """
        )
        statement.appendArgument(userID)
      }
      else {
        /* NOP */
      }

      statement.append(";")

      return
        try conn
        .fetch(using: statement) { dataRow -> UserPublicKeyDSV in
          guard
            let id: User.ID = dataRow.id.flatMap(User.ID.init(rawValue:)),
            let publicKey: ArmoredPGPPublicKey = dataRow.publicKey.flatMap(ArmoredPGPPublicKey.init(rawValue:))
          else {
            throw
              DatabaseIssue
              .error(
                underlyingError:
                  DatabaseDataInvalid
                  .error(for: ResourceUserGroupListItemDSV.self)
              )
          }

          return UserPublicKeyDSV(
            userID: id,
            publicKey: publicKey
          )
        }
    }
  }
}
