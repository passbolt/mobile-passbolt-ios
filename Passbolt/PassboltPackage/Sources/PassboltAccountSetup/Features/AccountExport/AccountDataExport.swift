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

import AccountSetup
import Accounts
import FeatureScopes
import Session

// MARK: - Interface

/// Export local account data after authorization.
/// Valid and active session for required account
/// is required.
internal struct AccountDataExport {

  internal var exportAccountData: @Sendable (AccountExportAuthorizationMethod) async throws -> AccountTransferData
}

extension AccountDataExport: LoadableFeature {

  #if DEBUG
  nonisolated static var placeholder: Self {
    .init(
      exportAccountData: unimplemented1()
    )
  }
  #endif
}

// MARK: - Implementation

extension AccountDataExport {

  @MainActor fileprivate static func load(
    features: Features
  ) throws -> Self {
    try features.ensureScope(SessionScope.self)
    try features.ensureScope(AccountTransferScope.self)

    let account: Account = try features.sessionAccount()

    let session: Session = try features.instance()
    let accountDetails: AccountDetails = try features.instance()
    let accountsData: AccountsDataStore = try features.instance()

    @Sendable nonisolated func exportAccountData(
      authorizationMethod: AccountExportAuthorizationMethod
    ) async throws -> AccountTransferData {
      switch authorizationMethod {
      case .biometrics:
        try await session.authorize(.biometrics(account))

      case .passphrase(let passphrase):
        try await session.authorize(.passphrase(account, passphrase))
      }

      let accountWithProfile: AccountWithProfile = try accountDetails.profile()
      let accountPrivateKey: ArmoredPGPPrivateKey = try accountsData.loadAccountPrivateKey(account.localID)

      return .init(
        userID: accountWithProfile.userID,
        domain: accountWithProfile.domain,
        username: accountWithProfile.username,
        firstName: accountWithProfile.firstName,
        lastName: accountWithProfile.lastName,
        avatarImageURL: accountWithProfile.avatarImageURL,
        fingerprint: accountWithProfile.fingerprint,
        armoredKey: accountPrivateKey
      )
    }

    return .init(
      exportAccountData: exportAccountData(authorizationMethod:)
    )
  }
}

extension FeaturesRegistry {

  internal mutating func usePassboltAccountDataExport() {
    self.use(
      .disposable(
        AccountDataExport.self,
        load: AccountDataExport
          .load(features:)
      ),
      in: AccountTransferScope.self
    )
  }
}
