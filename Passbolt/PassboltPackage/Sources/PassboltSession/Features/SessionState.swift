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
  /// Source of the session updates sequence/
  internal var updatesSequenceSource: UpdatesSequenceSource
  /// Currently used account.
  internal var account: @SessionActor () -> Account?
  /// Set currently used account,
  /// clears all other data if different account used.
  internal var setAccount: @SessionActor (Account?) -> Void
  /// Get cached passphrase.
  /// Auto expires after given amout of time.
  internal var passphrase: @SessionActor () -> Passphrase?
  /// Set cached passphrase.
  internal var setPassphrase: @SessionActor (Passphrase?) -> Void
  /// Get current network access token if valid.
  internal var validAccessToken: @SessionActor () -> SessionAccessToken?
  /// Set current network access token.
  internal var setAccessToken: @SessionActor (SessionAccessToken?) -> Void
  /// Get current network refresh token.
  /// Accessing refresh token removes it.
  internal var refreshToken: @SessionActor () -> SessionRefreshToken?
  /// Set current network refresh token.
  internal var setRefreshToken: @SessionActor (SessionRefreshToken?) -> Void
  /// Get current network mfa token.
  internal var mfaToken: @SessionActor () -> SessionMFAToken?
  /// Set current network mfa token.
  internal var setMFAToken: @SessionActor (SessionMFAToken?) -> Void
}

extension SessionState: LoadableContextlessFeature {

  #if DEBUG
  nonisolated static var placeholder: Self {
    Self(
      updatesSequenceSource: .init(),
      account: unimplemented(),
      setAccount: unimplemented(),
      passphrase: unimplemented(),
      setPassphrase: unimplemented(),
      validAccessToken: unimplemented(),
      setAccessToken: unimplemented(),
      refreshToken: unimplemented(),
      setRefreshToken: unimplemented(),
      mfaToken: unimplemented(),
      setMFAToken: unimplemented()
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
    var accountStorage: Account? = .none

    @SessionActor func account() -> Account? {
      accountStorage
    }

    @SessionActor func setAccount(
      _ newAccount: Account?
    ) {
      guard accountStorage != newAccount
      else { return }
      accountStorage = newAccount
      setPassphrase(.none)
      setAccessToken(.none)
      setRefreshToken(.none)
      setMFAToken(.none)
    }

    // access only using SessionActor
    var passphraseStorage: Passphrase? = .none
    var passphraseTimestamp: Timestamp = 0
    let passphraseExpirationTime: Timestamp = 5 * 60  // 5 Minutes

    @SessionActor func passphrase() -> Passphrase? {
      if passphraseTimestamp + passphraseExpirationTime >= osTime.timestamp() {
        return passphraseStorage
      }
      else {
        passphraseStorage = .none
        return .none
      }
    }

    @SessionActor func setPassphrase(
      _ newPassphrase: Passphrase?
    ) {
      passphraseStorage = newPassphrase
      passphraseTimestamp = osTime.timestamp()
    }

    // access only using SessionActor
    var accessTokenStorage: SessionAccessToken? = .none

    @SessionActor func validAccessToken() -> SessionAccessToken? {
      if let token: SessionAccessToken = accessTokenStorage {
        if token.isExpired(timestamp: osTime.timestamp(), leeway: 10) {
          accessTokenStorage = .none
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

    @SessionActor func setAccessToken(
      _ newToken: SessionAccessToken?
    ) {
      accessTokenStorage = newToken
    }

    // access only using SessionActor
    var refreshTokenStorage: SessionRefreshToken? = .none

    @SessionActor func refreshToken() -> SessionRefreshToken? {
      defer { refreshTokenStorage = .none }
      return refreshTokenStorage
    }

    @SessionActor func setRefreshToken(
      _ newToken: SessionRefreshToken?
    ) {
      refreshTokenStorage = newToken
    }

    // access only using SessionActor
    var mfaTokenStorage: SessionMFAToken? = .none

    @SessionActor func mfaToken() -> SessionMFAToken? {
      mfaTokenStorage
    }

    @SessionActor func setMFAToken(
      _ newToken: SessionMFAToken?
    ) {
      mfaTokenStorage = newToken
    }

    return Self(
      updatesSequenceSource: updatesSequenceSource,
      account: account,
      setAccount: setAccount(_:),
      passphrase: passphrase,
      setPassphrase: setPassphrase(_:),
      validAccessToken: validAccessToken,
      setAccessToken: setAccessToken(_:),
      refreshToken: refreshToken,
      setRefreshToken: setRefreshToken(_:),
      mfaToken: mfaToken,
      setMFAToken: setMFAToken(_:)
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
