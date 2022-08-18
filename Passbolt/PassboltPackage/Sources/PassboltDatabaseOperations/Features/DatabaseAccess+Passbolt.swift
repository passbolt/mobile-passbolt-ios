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
import OSFeatures

import struct Foundation.URL

// MARK: - Implementation

extension DatabaseAccess {

  @MainActor fileprivate static func load(
    features: FeatureFactory,
    cancellables: Cancellables
  ) async throws -> Self {
    unowned let features: FeatureFactory = features

    let diagnostics: Diagnostics = try await features.instance()
    let osFiles: OSFiles = features.instance()

    nonisolated func databaseLocation(
      for accountID: Account.LocalID
    ) throws -> URL {
      do {
        let databaseURL: URL =
          try osFiles
          .applicationDataDirectory()
          .appendingPathComponent(accountID.rawValue)
          .appendingPathExtension("sqlite")
        return databaseURL
      }
      catch {
        throw DatabaseIssue.error(
          underlyingError:
            error
            .asUnidentified()
            .pushing(.message("Cannot access database file"))
        )
      }
    }

    nonisolated func newConnection(
      _ location: URL,
      key: DatabaseKey
    ) throws -> SQLiteConnection {
      try SQLiteConnection
        .open(
          at: location.absoluteString,
          key: key.rawValue,
          options: SQLITE_OPEN_CREATE
            | SQLITE_OPEN_READWRITE
            | SQLITE_OPEN_WAL
            | SQLITE_OPEN_PRIVATECACHE,
          migrations: SQLiteMigration.allCases,
          openingOperations: SQLiteOpeningOperations.all
        )
    }

    nonisolated func openConnection(
      _ accountID: Account.LocalID,
      key: DatabaseKey
    ) throws -> SQLiteConnection {
      let location: URL = try databaseLocation(for: accountID)

      let databaseConnection: SQLiteConnection
      do {
        databaseConnection =
          try newConnection(
            location,
            key: key
          )
      }
      catch {
        diagnostics.log(error)
        diagnostics.diagnosticLog("Failed to open database, cleaning up...")
        try osFiles.deleteFile(location)
        // single retry after deleting previous database, fail if it fails
        databaseConnection =
          try newConnection(
            location,
            key: key
          )
      }

      return databaseConnection
    }

    nonisolated func delete(
      _ accountID: Account.LocalID
    ) throws {
      let location: URL = try databaseLocation(for: accountID)
      try osFiles.deleteFile(location)
    }

    return Self(
      openConnection: openConnection(_:key:),
      delete: delete(_:)
    )
  }
}

extension FeatureFactory {

  internal func usePassboltDatabaseAccess() {
    self.use(
      .lazyLoaded(
        DatabaseAccess.self,
        load: DatabaseAccess
          .load(features:cancellables:)
      )
    )
  }
}
