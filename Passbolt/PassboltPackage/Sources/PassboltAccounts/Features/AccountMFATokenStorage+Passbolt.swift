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

extension AccountMFATokenStorage {

  @MainActor fileprivate static func load(
    features: Features
  ) throws -> Self {
    let keychain: OSKeychain = features.instance()

    @Sendable func storeAccountMFAToken(
      accountID: Account.LocalID,
      token: String
    ) throws {
      try keychain
        .save(token, for: .accountMFATokenQuery(for: accountID))
        .get()
    }

    @Sendable func loadAccountMFAToken(
      accountID: Account.LocalID
    ) throws -> String? {
      try keychain
        .loadFirst(matching: .accountMFATokenQuery(for: accountID))
        .get()
    }

    @Sendable func deleteAccountMFAToken(
      accountID: Account.LocalID
    ) throws {
      try keychain
        .delete(matching: .accountMFATokenQuery(for: accountID))
        .get()
    }

    return Self(
      storeAccountMFAToken: storeAccountMFAToken(accountID:token:),
      loadAccountMFAToken: loadAccountMFAToken(accountID:),
      deleteAccountMFAToken: deleteAccountMFAToken(accountID:)
    )
  }
}

extension OSKeychainQuery {

  fileprivate static func accountMFATokenQuery(
    for identifier: Account.LocalID
  ) -> Self {
    assert(
      !identifier.rawValue.isEmpty,
      "Cannot use empty account identifiers for database operations"
    )
    return Self(
      key: "accountMFAToken",
      tag: .init(rawValue: identifier.rawValue),
      requiresBiometrics: false
    )
  }
}

extension FeaturesRegistry {

  public mutating func usePassboltAccountMFATokenStorage() {
    self.use(
      .lazyLoaded(
        AccountMFATokenStorage.self,
        load: AccountMFATokenStorage.load(features:)
      )
    )
  }
}
