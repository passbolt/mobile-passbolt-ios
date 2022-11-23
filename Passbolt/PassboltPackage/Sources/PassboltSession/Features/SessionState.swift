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
import OSFeatures

// MARK: - Interface

/// In-memory storage for current session data.
/// For internal use only.
internal struct SessionState {
  /// Session updates sequence.
  internal var updatesSequence: UpdatesSequence
  /// Currently used account.
  internal var account: @SessionActor () -> Account?
  /// Get cached passphrase.
  /// Auto expires after given amout of time.
  internal var passphrase: @SessionActor () -> Passphrase?
  /// Get current network access token if valid.
  internal var validAccessToken: @SessionActor () -> SessionAccessToken?
  /// Get current network refresh token.
  /// Accessing refresh token removes it.
  internal var refreshToken: @SessionActor () -> SessionRefreshToken?
  /// Get current network mfa token.
  internal var mfaToken: @SessionActor () -> SessionMFAToken?
  /// Current pending authorization state.
  internal var pendingAuthorization: @SessionActor () -> PendingAuthorization?

  /// Update with new session data.
  internal var createdSession:
    @SessionActor (
      Account,
      Passphrase,
      SessionAccessToken,
      SessionRefreshToken,
      SessionMFAToken?,
      Array<SessionMFAProvider>  // if not empty MFA is required
    ) -> Void
  /// Update with refreshed session data.
  internal var refreshedSession:
    @SessionActor (
      Account,
      Passphrase?,  // extend expire time if provided, ignore otherwise
      SessionAccessToken,
      SessionRefreshToken,
      SessionMFAToken?
    ) throws -> Void
  /// Update with refreshed session data.
  internal var passphraseProvided:
    @SessionActor (
      Account,
      Passphrase
    ) throws -> Void
  /// Update with refreshed session data.
  internal var mfaProvided:
    @SessionActor (
      Account,
      SessionMFAToken
    ) throws -> Void
  /// Update with authorization request.
  internal var authorizationRequested: @SessionActor (SessionAuthorizationRequest) throws -> Void
  /// Clear current passphrase data if any.
  internal var passphraseWipe: @SessionActor () -> Void
  /// Clear current access token data if any.
  internal var accessTokenInvalidate: @SessionActor () -> Void
  /// Clear current mfa token data if any.
  internal var mfaTokenInvalidate: @SessionActor () -> Void
  /// Clear current session data if any.
  internal var closedSession: @SessionActor () -> Void
}

extension SessionState {

  internal enum PendingAuthorization: Equatable {

    case passphrase(for: Account)
    case mfa(for: Account, providers: Array<SessionMFAProvider>)
    case passphraseWithMFA(for: Account, providers: Array<SessionMFAProvider>)
  }
}

extension SessionState: LoadableContextlessFeature {

  #if DEBUG
  nonisolated static var placeholder: Self {
    Self(
      updatesSequence: .placeholder,
      account: unimplemented(),
      passphrase: unimplemented(),
      validAccessToken: unimplemented(),
      refreshToken: unimplemented(),
      mfaToken: unimplemented(),
      pendingAuthorization: unimplemented(),
      createdSession: unimplemented(),
      refreshedSession: unimplemented(),
      passphraseProvided: unimplemented(),
      mfaProvided: unimplemented(),
      authorizationRequested: unimplemented(),
      passphraseWipe: unimplemented(),
      accessTokenInvalidate: unimplemented(),
      mfaTokenInvalidate: unimplemented(),
      closedSession: unimplemented()
    )
  }
  #endif
}

// MARK: - Implementation

extension SessionState {

  @MainActor fileprivate static func load(
    features: FeatureFactory,
    cancellables: Cancellables
  ) async throws -> Self {
    unowned let features: FeatureFactory = features

    let osTime: OSTime = features.instance()

    let updatesSequenceSource: UpdatesSequenceSource = .init()

    // access only using SessionActor
    var currentAccount: Account? = .none

    @SessionActor func account() -> Account? {
      currentAccount
    }

    // access only using SessionActor
    var currentPassphrase: Passphrase? = .none
    var currentPassphraseExpiration: Timestamp = 0
    let passphraseExpirationTime: Timestamp = 5 * 60  // 5 Minutes

    @SessionActor func passphrase() -> Passphrase? {
      if currentPassphraseExpiration >= osTime.timestamp() {
        return currentPassphrase
      }
      else {
        currentPassphrase = .none
        return .none
      }
    }

    // access only using SessionActor
    var currentAccessToken: SessionAccessToken? = .none

    @SessionActor func validAccessToken() -> SessionAccessToken? {
      if let token: SessionAccessToken = currentAccessToken {
        if token.isExpired(timestamp: osTime.timestamp(), leeway: 10) {
          currentAccessToken = .none
          return .none
        }
        else {
          return token
        }
      }
      else {
        return .none
      }
    }

    // access only using SessionActor
    var currentRefreshToken: SessionRefreshToken? = .none

    @SessionActor func refreshToken() -> SessionRefreshToken? {
      defer { currentRefreshToken = .none }
      return currentRefreshToken
    }

    // access only using SessionActor
    var currentMFAToken: SessionMFAToken? = .none

    @SessionActor func mfaToken() -> SessionMFAToken? {
      currentMFAToken
    }

    // access only using SessionActor
    var currentPendingAuthorization: PendingAuthorization? = .none

    @SessionActor func pendingAuthorization() -> PendingAuthorization? {
      currentPendingAuthorization
    }

    @SessionActor func createdSession(
      account: Account,
      passphrase: Passphrase,
      accessToken: SessionAccessToken,
      refreshToken: SessionRefreshToken,
      mfaToken: SessionMFAToken?,
      mfaRequiredWithProviders mfaProviders: Array<SessionMFAProvider>
    ) {
      currentAccount = account
      currentPassphrase = passphrase
      currentPassphraseExpiration = osTime.timestamp() + passphraseExpirationTime
      currentAccessToken = accessToken
      currentRefreshToken = refreshToken
      currentMFAToken = mfaToken
      if mfaProviders.isEmpty {
        currentPendingAuthorization = .none
      }
      else {
        currentPendingAuthorization = .mfa(
          for: account,
          providers: mfaProviders
        )
      }
      updatesSequenceSource.sendUpdate()
    }

    @SessionActor func refreshedSession(
      account: Account,
      passphrase: Passphrase?,
      accessToken: SessionAccessToken,
      refreshToken: SessionRefreshToken,
      mfaToken: SessionMFAToken?
    ) throws {
      guard currentAccount == account
      else {
        throw
          SessionClosed
          .error(account: account)
      }
      if let passphrase: Passphrase = passphrase {
        // extend passphrase cache expire time if provided
        currentPassphrase = passphrase
        currentPassphraseExpiration = osTime.timestamp() + passphraseExpirationTime
      }  // else NOP - ignore
      currentAccessToken = accessToken
      currentRefreshToken = refreshToken
      currentMFAToken = mfaToken

      switch currentPendingAuthorization {
      case .none, .mfa:
        return  // NOP - ignore

      case .passphrase:
        currentPendingAuthorization = .none
        updatesSequenceSource.sendUpdate()

      case .passphraseWithMFA(_, let mfaProviders):
        currentPendingAuthorization = .mfa(for: account, providers: mfaProviders)
        updatesSequenceSource.sendUpdate()
      }
    }

    @SessionActor func passphraseProvided(
      account: Account,
      passphrase: Passphrase
    ) throws {
      guard currentAccount == account
      else {
        throw
          SessionClosed
          .error(account: account)
      }
      currentPassphrase = passphrase
      currentPassphraseExpiration = osTime.timestamp() + passphraseExpirationTime
      switch currentPendingAuthorization {
      case .none, .mfa:
        return  // NOP - ignore

      case .passphrase:
        currentPendingAuthorization = .none
        updatesSequenceSource.sendUpdate()

      case .passphraseWithMFA(_, let mfaProviders):
        currentPendingAuthorization = .mfa(for: account, providers: mfaProviders)
        updatesSequenceSource.sendUpdate()
      }
    }

    @SessionActor func mfaProvided(
      account: Account,
      mfaToken: SessionMFAToken
    ) throws {
      guard currentAccount == account
      else {
        throw
          SessionClosed
          .error(account: account)
      }
      currentMFAToken = mfaToken
      switch currentPendingAuthorization {
      case .none, .passphrase:
        return  // NOP - ignore

      case .mfa:
        currentPendingAuthorization = .none
        updatesSequenceSource.sendUpdate()

      case .passphraseWithMFA(let account, _):
        currentPendingAuthorization = .passphrase(for: account)
        updatesSequenceSource.sendUpdate()
      }
    }

    @SessionActor func authorizationRequested(
      _ request: SessionAuthorizationRequest
    ) throws {
      guard let currentAccount: Account = currentAccount
      else {
        throw
          SessionClosed
          .error(account: request.account)
      }

      switch currentPendingAuthorization {
      // new request when there is none
      case .none:
        switch request {
        case .passphrase(currentAccount):
          currentPassphrase = .none
          currentPassphraseExpiration = 0
          currentPendingAuthorization = .passphrase(for: currentAccount)
          updatesSequenceSource.sendUpdate()

        case .mfa(currentAccount, let mfaProviders):
          currentMFAToken = .none
          currentPendingAuthorization = .mfa(for: currentAccount, providers: mfaProviders)
          updatesSequenceSource.sendUpdate()

        case .passphrase, .mfa:
          throw
            SessionClosed
            .error(account: request.account)
        }

      // already requested passphrase
      case .passphrase(currentAccount):
        switch request {
        case .passphrase(currentAccount):
          return  // NOP - ignore

        case let .mfa(account, mfaProviders)
        where account == currentAccount:
          currentMFAToken = .none
          currentPendingAuthorization = .passphraseWithMFA(for: account, providers: mfaProviders)
          updatesSequenceSource.sendUpdate()

        case .passphrase, .mfa:
          throw
            SessionClosed
            .error(account: request.account)
        }

      // already requested mfa
      case .mfa(currentAccount, let mfaProviders):
        switch request {
        case let .passphrase(account)
        where account == currentAccount:
          currentPassphrase = .none
          currentPassphraseExpiration = 0
          currentPendingAuthorization = .passphraseWithMFA(for: account, providers: mfaProviders)
          updatesSequenceSource.sendUpdate()

        case .mfa(currentAccount, mfaProviders):
          return  // NOP - ignore (refined providers?)

        case .passphrase, .mfa:
          throw
            SessionClosed
            .error(account: request.account)
        }

      // already requested passphrase and MFA
      case .passphraseWithMFA(currentAccount, _):
        return  // NOP - ignore (refined providers?)

      case .passphrase, .mfa, .passphraseWithMFA:
        throw
          SessionClosed
          .error(account: request.account)
      }
    }

    @SessionActor func passphraseWipe() {
      currentPassphrase = .none
      currentPassphraseExpiration = 0
    }

    @SessionActor func accessTokenInvalidate() {
      currentAccessToken = .none
    }

    @SessionActor func mfaTokenInvalidate() {
      currentMFAToken = .none
    }

    @SessionActor func closedSession() {
      guard case .some = currentAccount
      else { return }
      currentAccount = .none
      currentPassphrase = .none
      currentPassphraseExpiration = 0
      currentAccessToken = .none
      currentRefreshToken = .none
      currentMFAToken = .none
      currentPendingAuthorization = .none
      updatesSequenceSource.sendUpdate()
    }

    return Self(
      updatesSequence: updatesSequenceSource.updatesSequence,
      account: account,
      passphrase: passphrase,
      validAccessToken: validAccessToken,
      refreshToken: refreshToken,
      mfaToken: mfaToken,
      pendingAuthorization: pendingAuthorization,
      createdSession: createdSession(account:passphrase:accessToken:refreshToken:mfaToken:mfaRequiredWithProviders:),
      refreshedSession: refreshedSession(account:passphrase:accessToken:refreshToken:mfaToken:),
      passphraseProvided: passphraseProvided(account:passphrase:),
      mfaProvided: mfaProvided(account:mfaToken:),
      authorizationRequested: authorizationRequested(_:),
      passphraseWipe: passphraseWipe,
      accessTokenInvalidate: accessTokenInvalidate,
      mfaTokenInvalidate: mfaTokenInvalidate,
      closedSession: closedSession
    )
  }
}

extension FeatureFactory {

  internal func usePassboltSessionState() {
    self.use(
      .lazyLoaded(
        SessionState.self,
        load: SessionState
          .load(features:cancellables:)
      )
    )
  }
}
