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

import Session

// MARK: - Implementation

extension SessionPassphrase {

  @MainActor fileprivate static func load(
    features: FeatureFactory,
    context account: Account
  ) async throws -> Self {
    unowned let features: FeatureFactory = features

    let sessionState: SessionState = try await features.instance()
    let sessionStateEnsurance: SessionStateEnsurance = try await features.instance()
    let accountsDataStore: AccountsDataStore = try await features.instance()

    @SessionActor @Sendable func storeWithBiometry(
      _ store: Bool
    ) async throws {
      guard let currentAccount: Account = sessionState.account()
      else { throw SessionMissing.error() }

      guard currentAccount == account
      else { throw SessionClosed.error(account: account) }

      if store {
        let passphrase: Passphrase = try await sessionStateEnsurance.passphrase(account)

        return try accountsDataStore.storeAccountPassphrase(account.localID, passphrase)
      }
      else {
        return try accountsDataStore.deleteAccountPassphrase(account.localID)
      }
    }

    return Self(
      storeWithBiometry: storeWithBiometry(_:)
    )
  }
}

extension FeatureFactory {

  internal func usePassboltSessionPassphrase() {
    self.use(
      .disposable(
        SessionPassphrase.self,
        load: SessionPassphrase
          .load(features:context:)
      )
    )
  }
}
