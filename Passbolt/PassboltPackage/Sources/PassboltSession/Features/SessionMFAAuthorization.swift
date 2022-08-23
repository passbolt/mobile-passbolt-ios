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
import NetworkOperations
import Session

// MARK: - Interface

internal struct SessionMFAAuthorization {

  internal var authorizeMFA: @SessionActor @Sendable (SessionMFAAuthorizationMethod) async throws -> Void
}

extension SessionMFAAuthorization: LoadableContextlessFeature {

  #if DEBUG
  nonisolated internal static var placeholder: Self {
    Self(
      authorizeMFA: unimplemented()
    )
  }
  #endif
}

// MARK: - Implementation

extension SessionMFAAuthorization {

  @MainActor fileprivate static func load(
    features: FeatureFactory
  ) async throws -> Self {
    unowned let features: FeatureFactory = features

    let diagnostics: Diagnostics = features.instance()
    let sessionState: SessionState = try await features.instance()
    let accountsData: AccountsDataStore = try await features.instance()
    let yubiKey: YubiKey = try await features.instance(of: EnvironmentLegacyBridge.self).environment.yubiKey
    let totpAuthorizationNetworkOperation: TOTPAuthorizationNetworkOperation = try await features.instance()
    let yubiKeyAuthorizationNetworkOperation: YubiKeyAuthorizationNetworkOperation = try await features.instance()

    @SessionActor @Sendable func authorizeMFAWithYubiKey(
      saveLocally: Bool
    ) async throws -> SessionMFAToken {
      let otp: String =
        try await yubiKey
        .readNFC()
        .asAsyncValue()
      return try await yubiKeyAuthorizationNetworkOperation(
        .init(
          otp: otp,
          remember: saveLocally
        )
      )
      .mfaToken
    }

    @SessionActor @Sendable func authorizeMFAWithTOTP(
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

    @SessionActor @Sendable func useMFAToken(
      _ mfaToken: SessionMFAToken,
      account: Account,
      saveLocally: Bool
    ) throws {
      sessionState.setMFAToken(mfaToken)
      if saveLocally {
        try accountsData
          .storeAccountMFAToken(
            account.localID,
            mfaToken.rawValue
          )
      }  // else NOP
    }

    @SessionActor @Sendable func authorizeMFA(
      _ method: SessionMFAAuthorizationMethod
    ) async throws {
      diagnostics.log(diagnostic: "Starting MFA authorization...")
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
        diagnostics.log(diagnostic: "...MFA authorization succeeded!")
      }
      catch {
        diagnostics.log(error: error)
        diagnostics.log(diagnostic: "...MFA authorization failed!")
        throw error
      }
    }

    return Self(
      authorizeMFA: authorizeMFA(_:)
    )
  }
}

extension FeatureFactory {

  internal func usePassboltSessionMFAAuthorization() {
    self.use(
      .disposable(
        SessionMFAAuthorization.self,
        load: SessionMFAAuthorization
          .load(features:)
      )
    )
  }
}
