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
import Features
import Session

// MARK: - Interface

/// Access session state ensuring authorization if needed.
internal struct SessionStateEnsurance {
  /// Get cached passphrase
  /// requesting authorization if needed.
  internal var passphrase: @SessionActor @Sendable (Account) async throws -> Passphrase
  /// Get current network access token
  /// requesting authorization if needed.
  internal var accessToken: @SessionActor @Sendable (Account) async throws -> SessionAccessToken
}

extension SessionStateEnsurance: LoadableContextlessFeature {

  #if DEBUG
  nonisolated internal static var placeholder: Self {
    Self(
      passphrase: unimplemented(),
      accessToken: unimplemented()
    )
  }
  #endif
}

// MARK: - Implementation

extension SessionStateEnsurance {

  @MainActor fileprivate static func load(
    features: FeatureFactory,
    cancellables: Cancellables
  ) async throws -> Self {
    unowned let features: FeatureFactory = features

    let sessionState: SessionState = try await features.instance()
    let sessionAuthorization: SessionAuthorization = try await features.instance()
    let sessionAuthorizationState: SessionAuthorizationState = try await features.instance()

    @SessionActor @Sendable func passphrase(
      _ account: Account
    ) async throws -> Passphrase {
      try await sessionAuthorizationState
        .waitForAuthorizationIfNeeded(
          .passphrase(account)
        )

      if let passphrase: Passphrase = sessionState.passphrase() {
        return passphrase
      }
      else {
        throw
          InternalInconsistency
          .error("Session state invalid after authorization")
      }
    }

    @SessionActor @Sendable func accessToken(
      _ account: Account
    ) async throws -> SessionAccessToken {
      try await sessionAuthorizationState
        .waitForAuthorizationIfNeeded(
          .passphrase(account)
        )

      if let token: SessionAccessToken = sessionState.validAccessToken() {
        return token
      }
      else if let passphrase: Passphrase = sessionState.passphrase() {
        try await sessionAuthorizationState
          .performAuthorization(account) {
            try await sessionAuthorization
              .refreshTokens(account, passphrase)
          }

        if let token: SessionAccessToken = sessionState.validAccessToken() {
          return token
        }  // else continue
      }  // else continue

      // if token and passphrase is missing after
      // authorization that is an error
      throw
        InternalInconsistency
        .error("Session state invalid after authorization")
    }

    return Self(
      passphrase: passphrase(_:),
      accessToken: accessToken(_:)
    )
  }
}

extension FeatureFactory {

  internal func usePassboltSessionStateEnsurance() {
    self.use(
      .lazyLoaded(
        SessionStateEnsurance.self,
        load: SessionStateEnsurance
          .load(features:cancellables:)
      )
    )
  }
}
