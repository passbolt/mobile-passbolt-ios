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

// MARK: - Generic implementation

extension FeatureLoader {

  internal static func databaseOperation<Description>(
    of: DatabaseOperation<Description>.Type,
    execute: @escaping @Sendable (Description.Input, SQLiteConnection) throws -> Description.Output
  ) -> Self
  where Description: DatabaseOperationDescription {
    .disposable(
      DatabaseOperation<Description>.self,
      load: { (features: FeatureFactory) -> DatabaseOperation<Description> in
        unowned let features: FeatureFactory = features

        let sessionDatabase: SessionDatabase = try await features.instance()

        nonisolated func executeAsync(
          _ input: Description.Input
        ) async throws -> Description.Output {
          try await execute(
            input,
            sessionDatabase.connection()
          )
        }

        return .init(
          execute: executeAsync(_:)
        )
      }
    )
  }

  internal static func databaseOperationWithTransaction<Description>(
    of: DatabaseOperation<Description>.Type,
    execute: @escaping @Sendable (Description.Input, SQLiteConnection) throws -> Description.Output
  ) -> Self
  where Description: DatabaseOperationDescription {
    .disposable(
      DatabaseOperation<Description>.self,
      load: { (features: FeatureFactory) -> DatabaseOperation<Description> in
        unowned let features: FeatureFactory = features

        let sessionDatabase: SessionDatabase = try await features.instance()

        nonisolated func executeAsync(
          _ input: Description.Input
        ) async throws -> Description.Output {
          try await sessionDatabase
            .connection()
            .withTransaction { connection in
              try execute(
                input,
                connection
              )
            }
        }

        return .init(
          execute: executeAsync(_:)
        )
      }
    )
  }
}
