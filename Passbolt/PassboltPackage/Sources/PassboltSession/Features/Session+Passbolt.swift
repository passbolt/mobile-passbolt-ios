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

import NetworkOperations
import Session

// MARK: - Implementation

extension Session {

  @MainActor fileprivate static func load(
    features: FeatureFactory,
    cancellables: Cancellables
  ) async throws -> Self {
    unowned let features: FeatureFactory = features

    let diagnostics: Diagnostics = features.instance()
    let sessionState: SessionState = try await features.instance()
    let sessionAuthorizationState: SessionAuthorizationState = try await features.instance()
    let sessionAuthorization: SessionAuthorization = try await features.instance()
    let sessionMFAAuthorization: SessionMFAAuthorization = try await features.instance()
    let sessionNetworkAuthorization: SessionNetworkAuthorization = try await features.instance()

    @SessionActor func pendingAuthorization() -> SessionAuthorizationRequest? {
      switch sessionState.pendingAuthorization() {
      case .none:
        return .none

      case .passphrase(let account), .passphraseWithMFA(let account, _):
        // passphrase + mfa makes priority for passphrase
        return .passphrase(account)

      case .mfa(let account, let providers):
        return .mfa(account, providers: providers)
      }
    }

    @SessionActor func currentAccount() async throws -> Account {
      if let account: Account = sessionState.account() {
        return account
      }
      else {
        throw
          SessionMissing
          .error()
      }
    }

    @SessionActor func authorize(
      _ method: SessionAuthorizationMethod
    ) async throws {
      try await sessionAuthorizationState
        .performAuthorization(
          method.account,
          { @SessionActor in
            try await sessionAuthorization
              .authorize(method)
          }
        )
    }

    @SessionActor func authorizeMFA(
      _ method: SessionMFAAuthorizationMethod
    ) async throws {
      try await sessionAuthorizationState
        .performAuthorization(
          method.account,
          { @SessionActor in
            try await sessionMFAAuthorization
              .authorizeMFA(method)
          }
        )
    }

    @SessionActor func close(
      _ account: Account?
    ) async {
      guard  // we have to have some account to close session
        let currentAccount: Account = sessionState.account(),
        currentAccount == account || account == .none
      else { return }
      // cancel any ongoing or pending authorization
      sessionAuthorizationState.cancelAuthorization()
      // if we have refresh token, invalidate session
      if let refreshToken: SessionRefreshToken = sessionState.refreshToken() {
        Task.detached {  // don't wait for the result
          do {
            try await sessionNetworkAuthorization
              .invalidateSessionTokens(
                currentAccount,
                refreshToken
              )
          }
          catch {
            // ignore errors it won't be able to retry anyway
            diagnostics.log(error: error)
          }
        }
      }  // else NOP
      // clear all session data
      sessionState.closedSession()
      // clear features scope
      // executed last to postpone any corutine suspend
      await features.clearScope()
    }

    return Self(
      updatesSequence: sessionState.updatesSequence,
      pendingAuthorization: pendingAuthorization,
      currentAccount: currentAccount,
      authorize: authorize(_:),
      authorizeMFA: authorizeMFA(_:),
      close: close(_:)
    )
  }
}

extension FeatureFactory {

  internal func usePassboltSession() {
    self.use(
      .lazyLoaded(
        Session.self,
        load: Session
          .load(features:cancellables:)
      )
    )
  }
}
