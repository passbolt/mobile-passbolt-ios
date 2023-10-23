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
import NetworkOperations
import OSFeatures
import FeatureScopes

import struct Foundation.Data

// MARK: - Implementation

extension AccountDetails {

  @MainActor fileprivate static func load(
    features: Features
  ) throws -> Self {
		let account: Account = try features.accountContext()
    let accountsDataStore: AccountsDataStore = try features.instance()
    let accountData: AccountData = try features.instance()
    let userDetailsFetchNetworkOperation: UserDetailsFetchNetworkOperation = try features.instance()
    let mediaDownloadNetworkOperation: MediaDownloadNetworkOperation = try features.instance()

    @Sendable nonisolated func profile() throws -> AccountWithProfile {
      try AccountWithProfile(
        account: account,
        profile:
          accountsDataStore
          .loadAccountProfile(account.localID)
      )
    }

		@Sendable nonisolated func passphraseStored() -> Bool {
			accountsDataStore.isAccountPassphraseStored(account.localID)
		}

    let userDetailsCache: ComputedVariable<UserDTO> = .init {
      return try await userDetailsFetchNetworkOperation
        .execute(
          .init(
            userID: account.userID
          )
        )
    }

    @Sendable nonisolated func updateProfile() async throws {
      let storedProfile: AccountProfile =
        try accountsDataStore
        .loadAccountProfile(account.localID)

      let userDetails: UserDTO =
        try await userDetailsFetchNetworkOperation
        .execute(
          .init(
            userID: account.userID
          )
        )

      // current account should always have a profile
      // but it is possible to get inactive/deleted
      // user which can have no profile
      // in that case we reuse local data for the missing part
      let updatedProfile: AccountProfile = .init(
        accountID: account.localID,
        label: storedProfile.label,
        username: userDetails.username,
        firstName: userDetails.profile?.firstName ?? storedProfile.firstName,
        lastName: userDetails.profile?.lastName ?? storedProfile.lastName,
        avatarImageURL: userDetails.profile?.avatar.urlString ?? storedProfile.avatarImageURL
      )

      try accountsDataStore
        .updateAccountProfile(updatedProfile)
      accountData.updates.update()
    }

		let avatarImageCache: ComputedVariable<Data> = .init(
			transformed: accountData.updates) { _ in
				let profile: AccountWithProfile = try profile()
				return try await mediaDownloadNetworkOperation.execute(profile.avatarImageURL)
		}

		@Sendable nonisolated func keyDetails() async throws -> PGPKeyDetails {
			// this could be unified with profile update action
			// to avoid additional network request
      let key: PGPKeyDetails? = try await userDetailsCache.value.key
			if let key {
				return key
			}
			else {
				throw AccountDataMissing
					.error("Account key missing")
			}
		}
    
    @Sendable nonisolated func role() async throws -> String? {
      try await userDetailsCache.value.role
    }

    @Sendable nonisolated func avatarImage() async throws -> Data? {
      try? await avatarImageCache.value
    }

    return Self(
      updates: accountData.updates.asAnyUpdatable(),
      profile: profile,
			isPassphraseStored: passphraseStored,
      updateProfile: updateProfile,
      keyDetails: keyDetails, 
      role: role,
      avatarImage: avatarImage
    )
  }
}

extension FeaturesRegistry {

  internal mutating func usePassboltAccountDetails() {
    self.use(
      .lazyLoaded(
        AccountDetails.self,
        load: AccountDetails.load(features:)
      ),
			in: AccountScope.self
    )
  }
}
