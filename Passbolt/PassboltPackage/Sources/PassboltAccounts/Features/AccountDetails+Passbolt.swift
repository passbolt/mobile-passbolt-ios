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

import struct Foundation.Data

// MARK: - Implementation

extension AccountDetails {

  @MainActor fileprivate static func load(
    features: FeatureFactory,
    context account: Account,
    cancellables: Cancellables
  ) async throws -> Self {
    unowned let features: FeatureFactory = features

    let diagnostics: OSDiagnostics = features.instance()
    let accountsDataStore: AccountsDataStore = try await features.instance()
    let accountData: AccountData = try await features.instance(context: account)
    let userDetailsFetchNetworkOperation: UserDetailsFetchNetworkOperation = try await features.instance()
    let mediaDownloadNetworkOperation: MediaDownloadNetworkOperation = try await features.instance()

    @Sendable nonisolated func profile() throws -> AccountWithProfile {
      try AccountWithProfile(
        account: account,
        profile:
          accountsDataStore
          .loadAccountProfile(account.localID)
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
      accountData.updatesSequenceSource.sendUpdate()
    }

    let avatarImageCache: AsyncCache<Data> = .init()
    @Sendable nonisolated func avatarImage() async throws -> Data? {
      do {
        return
          try await avatarImageCache
          .valueOrUpdate {
            let profile: AccountWithProfile = try profile()
            return
              try await mediaDownloadNetworkOperation
              .execute(profile.avatarImageURL)
          }
      }
      catch {
        diagnostics.log(error: error)
        return .none
      }
    }

    return Self(
      updates: accountData.updates,
      profile: profile,
      updateProfile: updateProfile,
      avatarImage: avatarImage
    )
  }
}

extension FeatureFactory {

  @MainActor internal func usePassboltAccountDetails() {
    self.use(
      .lazyLoaded(
        AccountDetails.self,
        load: AccountDetails.load(features:context:cancellables:)
      )
    )
  }
}
