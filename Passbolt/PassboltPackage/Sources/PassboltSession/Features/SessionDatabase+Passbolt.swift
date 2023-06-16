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

import CryptoKit
import DatabaseOperations
import OSFeatures
import Session

// MARK: - Implementation

extension SessionDatabase {

  @MainActor fileprivate static func load(
    features: Features,
    cancellables: Cancellables
  ) throws -> Self {

    let diagnostics: OSDiagnostics = features.instance()
    let session: Session = try features.instance()
    let sessionState: SessionState = try features.instance()
    let sessionStateEnsurance: SessionStateEnsurance = try features.instance()
    let databaseAccess: DatabaseAccess = try features.instance()

    @Sendable nonisolated func databaseKey(
      from passphrase: Passphrase
    ) throws -> DatabaseKey {
      let key: String? = passphrase
        .rawValue
        .data(using: .utf8)
        .map { data in
          SHA512
            .hash(data: data)
            .compactMap { String(format: "%02x", $0) }
            .joined()
        }
      if let databaseKey: DatabaseKey = key.map(DatabaseKey.init(rawValue:)) {
        return databaseKey
      }
      else {
        throw
          InternalInconsistency
          .error("Failed to prepare database key")
      }
    }

		@SessionActor @Sendable func openDatabaseConnectionIfAble() async -> SQLiteConnection? {
      guard let account: Account = sessionState.account()
      else { return .none }

      do {
        let passphrase: Passphrase = try await sessionStateEnsurance.passphrase(account)
        let key: DatabaseKey = try databaseKey(from: passphrase)

        return
          try databaseAccess
          .openConnection(account.localID, key)
      }
      catch {
        diagnostics.log(error: error)
        return .none
      }
    }

		let databaseConnection: ComputedVariable<SQLiteConnection?> = .init(
			using: session.updates,
			compute: { await openDatabaseConnectionIfAble() }
		)

    @Sendable nonisolated func currentConnection() async throws -> SQLiteConnection {
      if let connection: SQLiteConnection = try await databaseConnection.value {
        return connection
      }
      else {
        throw
          DatabaseConnectionClosed
          .error()
      }
    }

    return Self(
      connection: currentConnection
    )
  }
}

extension FeaturesRegistry {

  internal mutating func usePassboltSessionDatabase() {
    self.use(
      .lazyLoaded(
        SessionDatabase.self,
        load: SessionDatabase
          .load(features:cancellables:)
      )
    )
  }
}
