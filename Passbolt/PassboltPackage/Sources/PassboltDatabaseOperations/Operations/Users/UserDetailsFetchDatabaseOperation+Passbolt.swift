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
import Session

// MARK: - Implementation

extension UserDetailsFetchDatabaseOperation {

  @MainActor fileprivate static func load(
    features: FeatureFactory
  ) async throws -> Self {
    unowned let features: FeatureFactory = features

    let sessionDatabase: SessionDatabase = try await features.instance()

    nonisolated func execute(
      _ input: User.ID,
      connection: SQLiteConnection
    ) throws -> UserDetailsDSV {
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
        try connection
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
              .recording(dataRow, for: "dataRow")
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

    nonisolated func executeAsync(
      _ input: User.ID
    ) async throws -> UserDetailsDSV {
      try await execute(
        input,
        connection: sessionDatabase.connection()
      )
    }

    return Self(
      execute: executeAsync(_:)
    )
  }
}

extension FeatureFactory {

  internal func usePassboltUserDetailsFetchDatabaseOperation() {
    self.use(
      .disposable(
        UserDetailsFetchDatabaseOperation.self,
        load: UserDetailsFetchDatabaseOperation
          .load(features:)
      )
    )
  }
}
