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

extension AccountProfileStorage {

  @MainActor fileprivate static func load(
    features: Features
  ) throws -> Self {
    let keychain: OSKeychain = features.instance()
    let preferences: OSPreferences = features.instance()

    @Sendable func loadAccountProfile(
      for accountID: Account.LocalID
    ) throws -> AccountProfile {
      guard
        let profile: AccountProfile =
          try keychain
          .loadFirst(AccountProfile.self, matching: .accountProfileQuery(for: accountID))
          .get()
      else {
        throw
          AccountProfileDataMissing
          .error("Failed to load account profile")
          .recording(accountID, for: "accountID")
      }

      return profile
    }

    @Sendable func update(
      accountProfile: AccountProfile
    ) throws {
      let accountsList: Array<Account.LocalID> =
        preferences
        .load(Array<Account.LocalID>.self, for: .accountsList)
      guard accountsList.contains(accountProfile.accountID)
      else {
        throw
          AccountDataMissing
          .error("Failed to update account profile")
          .recording(accountProfile.accountID, for: "accountID")
      }
      try keychain
        .save(accountProfile, for: .accountProfileQuery(for: accountProfile.accountID))
        .get()
    }

    return Self(
      loadAccountProfile: loadAccountProfile(for:),
      updateAccountProfile: update(accountProfile:)
    )
  }
}

extension OSPreferences.Key {

  fileprivate static var accountsList: Self { "accountsList" }
}

extension OSKeychainQuery {

  fileprivate static func accountProfileQuery(
    for identifier: Account.LocalID
  ) -> Self {
    assert(
      !identifier.rawValue.isEmpty,
      "Cannot use empty account identifiers for account keychain operations"
    )
    return Self(
      key: "accountProfile",
      tag: .init(rawValue: identifier.rawValue),
      requiresBiometrics: false
    )
  }
}

extension FeaturesRegistry {

  public mutating func usePassboltAccountProfileStorage() {
    self.use(
      .lazyLoaded(
        AccountProfileStorage.self,
        load: AccountProfileStorage.load(features:)
      )
    )
  }
}
