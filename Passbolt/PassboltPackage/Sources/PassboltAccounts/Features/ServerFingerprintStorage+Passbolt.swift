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

extension ServerFingerprintStorage {

  @MainActor fileprivate static func load(
    features: Features
  ) throws -> Self {
    let keychain: OSKeychain = features.instance()

    @Sendable func storeServerFingerprint(
      accountID: Account.LocalID,
      fingerprint: Fingerprint
    ) throws {
      try keychain
        .save(fingerprint, for: .serverFingerprintQuery(for: accountID))
        .get()
    }

    @Sendable func loadServerFingerprint(accountID: Account.LocalID) throws -> Fingerprint? {
      try keychain
        .loadFirst(Fingerprint.self, matching: .serverFingerprintQuery(for: accountID))
        .get()
    }

    return Self(
      storeServerFingerprint: storeServerFingerprint(accountID:fingerprint:),
      loadServerFingerprint: loadServerFingerprint(accountID:)
    )
  }
}

extension OSKeychainQuery {

  fileprivate static func serverFingerprintQuery(
    for identifier: Account.LocalID
  ) -> Self {
    assert(
      !identifier.rawValue.isEmpty,
      "Cannot use empty account identifiers for database operations"
    )
    return Self(
      key: "serverFingerprint",
      tag: .init(rawValue: identifier.rawValue),
      requiresBiometrics: false
    )
  }
}

extension FeaturesRegistry {

  public mutating func usePassboltServerFingerprintStorage() {
    self.use(
      .lazyLoaded(
        ServerFingerprintStorage.self,
        load: ServerFingerprintStorage.load(features:)
      )
    )
  }
}
