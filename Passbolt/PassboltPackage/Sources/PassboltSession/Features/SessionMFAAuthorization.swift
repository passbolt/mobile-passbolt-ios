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

import Features
import NFC
import NetworkOperations
import OSFeatures
import Session

// MARK: - Interface

internal struct SessionMFAAuthorization {

  internal var authorizeMFA: @SessionActor (SessionMFAAuthorizationMethod) async throws -> Void
}

extension SessionMFAAuthorization: LoadableFeature {

  #if DEBUG
  nonisolated internal static var placeholder: Self {
    Self(
      authorizeMFA: unimplemented1()
    )
  }
  #endif
}

// MARK: - Implementation

extension SessionMFAAuthorization {

  @MainActor fileprivate static func load(
    features: Features
  ) throws -> Self {

    let sessionState: SessionState = try features.instance()
    let accountsData: AccountsDataStore = try features.instance()
    let yubiKey: YubiKey = features.instance()
    let totpAuthorizationNetworkOperation: TOTPAuthorizationNetworkOperation = try features.instance()
    let yubiKeyAuthorizationNetworkOperation: YubiKeyAuthorizationNetworkOperation = try features.instance()

    @SessionActor func authorizeMFAWithYubiKey(
      saveLocally: Bool
    ) async throws -> SessionMFAToken {
      let otp: String =
        try await yubiKey
        .read()
        .asAsyncValue()
      return try await yubiKeyAuthorizationNetworkOperation(
        .init(
          otp: otp,
          remember: saveLocally
        )
      )
      .mfaToken
    }

    @SessionActor func authorizeMFAWithTOTP(
      _ totp: String,
      saveLocally: Bool
    ) async throws -> SessionMFAToken {
      try await totpAuthorizationNetworkOperation(
        .init(
          totp: totp,
          remember: saveLocally
        )
      )
      .mfaToken
    }

    @SessionActor func useMFAToken(
      _ mfaToken: SessionMFAToken,
      account: Account,
      saveLocally: Bool
    ) throws {
      try sessionState.mfaProvided(
        account,
        mfaToken
      )
      if saveLocally {
        try accountsData
          .storeAccountMFAToken(
            account.localID,
            mfaToken.rawValue
          )
      }  // else NOP
    }

    @SessionActor func authorizeMFA(
      _ method: SessionMFAAuthorizationMethod
    ) async throws {
      Diagnostics.log(diagnostic: "Starting MFA authorization...")
      do {
        let mfaToken: SessionMFAToken
        let account: Account
        let rememberDevice: Bool
        switch method {
        case let .totp(requestedAccount, totp, remember):
          guard requestedAccount == sessionState.account()
          else { throw SessionClosed.error(account: requestedAccount) }
          mfaToken = try await authorizeMFAWithTOTP(
            totp,
            saveLocally: remember
          )
          account = requestedAccount
          rememberDevice = remember

        case let .yubiKey(requestedAccount, remember):
          guard requestedAccount == sessionState.account()
          else { throw SessionClosed.error(account: requestedAccount) }

          mfaToken = try await authorizeMFAWithYubiKey(
            saveLocally: remember
          )
          account = requestedAccount
          rememberDevice = remember
        }

        try useMFAToken(
          mfaToken,
          account: account,
          saveLocally: rememberDevice
        )
        Diagnostics.log(diagnostic: "...MFA authorization succeeded!")
      }
      catch {
        Diagnostics.log(error: error)
        Diagnostics.log(diagnostic: "...MFA authorization failed!")
        throw error
      }
    }

    return Self(
      authorizeMFA: authorizeMFA(_:)
    )
  }
}

extension FeaturesRegistry {

  internal mutating func usePassboltSessionMFAAuthorization() {
    self.use(
      .disposable(
        SessionMFAAuthorization.self,
        load: SessionMFAAuthorization
          .load(features:)
      )
    )
  }
}
