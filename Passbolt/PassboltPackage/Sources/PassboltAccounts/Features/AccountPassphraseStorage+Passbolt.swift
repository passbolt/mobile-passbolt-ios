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

import Accounts
import OSFeatures

// MARK: - Implementation

extension AccountPassphraseStorage {

  @MainActor fileprivate static func load(
    features: Features
  ) throws -> Self {
    let keychain: OSKeychain = features.instance()

    @Sendable nonisolated func isPassphraseStored(
      for accountID: Account.LocalID
    ) -> Bool {
      keychain
        .checkIfExists(
          matching: .accountPassphraseQuery(for: accountID)
        )
    }

    @Sendable nonisolated func storePassphrase(
      for accountID: Account.LocalID,
      passphrase: Passphrase
    ) throws {
      try keychain
        .save(
          passphrase,
          for: .accountPassphraseQuery(for: accountID)
        )
        .get()
    }

    @Sendable nonisolated func loadPassphrase(
      for accountID: Account.LocalID
    ) throws -> Passphrase {
      // in case of failure we should change flag biometricsEnabled to false and propagate change
      do {
        guard
          let passphrase: Passphrase =
            try keychain
            .loadFirst(
              Passphrase.self,
              matching: .accountPassphraseQuery(for: accountID)
            )
            .get()
        else {
          throw
            AccountBiometryDataChanged
            .error()
            .pushing(.message("Failed to load account passphrase"))
            .recording(accountID, for: "accountID")
        }
        return passphrase
      }
      catch let error as AccountBiometryDataChanged {
        throw error
      }
      catch {
        throw
          error
          .asTheError()
          .pushing(.message("Failed to load account passphrase"))
          .recording(accountID, for: "accountID")
      }
    }

    @Sendable nonisolated func deletePassphrase(
      for accountID: Account.LocalID
    ) throws {
      try keychain
        .delete(matching: .accountPassphraseDeleteQuery(for: accountID))
        .get()
    }

    return Self(
      isAccountPassphraseStored: isPassphraseStored(for:),
      storeAccountPassphrase: storePassphrase(for:passphrase:),
      loadAccountPassphrase: loadPassphrase(for:),
      deleteAccountPassphrase: deletePassphrase(for:)
    )
  }
}

extension OSKeychainQuery {

  fileprivate static func accountPassphraseQuery(
    for identifier: Account.LocalID
  ) -> Self {
    assert(
      !identifier.rawValue.isEmpty,
      "Cannot use empty account identifiers for passphrase keychain operations"
    )
    return Self(
      key: "accountPassphrase",
      tag: .init(rawValue: identifier.rawValue),
      requiresBiometrics: true
    )
  }

  fileprivate static func accountPassphraseDeleteQuery(
    for identifier: Account.LocalID
  ) -> Self {
    assert(
      !identifier.rawValue.isEmpty,
      "Cannot use empty account identifiers for passphrase keychain operations"
    )
    return Self(
      key: "accountPassphrase",
      tag: .init(rawValue: identifier.rawValue),
      requiresBiometrics: false
    )
  }
}

extension FeaturesRegistry {

  public mutating func usePassboltAccountPassphraseStorage() {
    self.use(
      .lazyLoaded(
        AccountPassphraseStorage.self,
        load: AccountPassphraseStorage.load(features:)
      )
    )
  }
}
