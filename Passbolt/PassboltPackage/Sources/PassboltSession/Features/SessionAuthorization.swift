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

import Crypto
import Features
import NetworkOperations
import OSFeatures
import Session

// MARK: - Interface

internal struct SessionAuthorization {

  internal var authorize: @SessionActor (SessionAuthorizationMethod) async throws -> Void
  internal var refreshTokens: @SessionActor (Account, Passphrase) async throws -> Void
}

extension SessionAuthorization: LoadableContextlessFeature {

  #if DEBUG
  nonisolated internal static var placeholder: Self {
    Self(
      authorize: unimplemented(),
      refreshTokens: unimplemented()
    )
  }
  #endif
}

// MARK: - Implementation

extension SessionAuthorization {

  @MainActor fileprivate static func load(
    features: FeatureFactory
  ) async throws -> Self {
    unowned let features: FeatureFactory = features

    let diagnostics: OSDiagnostics = features.instance()
    let sessionState: SessionState = try await features.instance()
    let sessionNetworkAuthorization: SessionNetworkAuthorization = try await features.instance()
    let accountsData: AccountsDataStore = try await features.instance()
    let pgp: PGP = features.instance()
    let osTime: OSTime = features.instance()

    @Sendable nonisolated func validatedAuthorizationData(
      for method: SessionAuthorizationMethod
    ) throws -> AuthorizationData {
      switch method {
      case let .adHoc(account, passphrase, privateKey):
        guard verifyPassphrase(passphrase, forKey: privateKey)
        else { throw PassphraseInvalid.error() }

        return (
          account: account,
          passphrase: passphrase,
          privateKey: privateKey
        )

      case let .passphrase(account, passphrase):
        let privateKey: ArmoredPGPPrivateKey =
          try accountsData
          .loadAccountPrivateKey(account.localID)

        guard verifyPassphrase(passphrase, forKey: privateKey)
        else { throw PassphraseInvalid.error() }

        return (
          account: account,
          passphrase: passphrase,
          privateKey: privateKey
        )

      case let .biometrics(account):
        let passphrase: Passphrase =
          try accountsData
          .loadAccountPassphrase(account.localID)
        let privateKey: ArmoredPGPPrivateKey =
          try accountsData
          .loadAccountPrivateKey(account.localID)

        guard verifyPassphrase(passphrase, forKey: privateKey)
        else { throw PassphraseInvalid.error() }

        return (
          account: account,
          passphrase: passphrase,
          privateKey: privateKey
        )
      }
    }

    @Sendable nonisolated func verifyPassphrase(
      _ passphrase: Passphrase,
      forKey privateKey: ArmoredPGPPrivateKey
    ) -> Bool {
      do {
        try pgp.verifyPassphrase(
          privateKey,
          passphrase
        )
        .get()
        return true
      }
      catch {
        diagnostics.log(error: error)
        return false
      }
    }

    @SessionActor func isCurrentAccessTokenValid() -> Bool {
      // expiration time is checked on the SessionState side
      // but using greater leeway to refresh session more
      // eagerly when already performing authorization
      !(sessionState.validAccessToken()?
        .isExpired(timestamp: osTime.timestamp(), leeway: 30)
        ?? true)
    }

    @SessionActor func currentRefreshToken() -> SessionRefreshToken? {
      // refresh token is cleared on the SessionState side
      // right after accessing it, it can't be reused
      sessionState.refreshToken()
    }

    @SessionActor func currentMFAToken(
      for account: Account
    ) throws -> SessionMFAToken? {
      if case .mfa(account, let mfaProviders) = sessionState.pendingAuthorization() {
        throw
          SessionMFAAuthorizationRequired
          .error(
            account: account,
            mfaProviders: mfaProviders
          )
      }
      else if sessionState.account() == account {
        return sessionState.mfaToken()
      }
      else {
        return storedMFAToken(for: account)
      }
    }

    @SessionActor func storedMFAToken(
      for account: Account
    ) -> SessionMFAToken? {
      try? accountsData
        .loadAccountMFAToken(account.localID)
        .map(SessionMFAToken.init(rawValue:))
    }

    @SessionActor func createSessionTokens(
      _ authorizationData: AuthorizationData,
      mfaToken: SessionMFAToken?
    ) async throws -> (tokens: SessionTokens, requiredMFAProviders: Array<SessionMFAProvider>) {
      try await sessionNetworkAuthorization
        .createSessionTokens(
          authorizationData,
          mfaToken
        )
    }

    @SessionActor @Sendable func refreshSessionTokens(
      _ authorizationData: AuthorizationData,
      refreshToken: SessionRefreshToken,
      mfaToken: SessionMFAToken?
    ) async throws -> SessionTokens {
      try await sessionNetworkAuthorization
        .refreshSessionTokens(
          authorizationData,
          refreshToken,
          mfaToken
        )
    }

    @SessionActor @Sendable func handleAuthorization(
      account: Account,
      passphrase: Passphrase,
      sessionTokens: SessionTokens,
      mfaToken: SessionMFAToken?,
      mfaRequiredWithProviders mfaProviders: Array<SessionMFAProvider>
    ) async {
      await features
        .ensureScope(identifier: account)
      accountsData
        .storeLastUsedAccount(account.localID)
      sessionState.createdSession(
        account,
        passphrase,
        sessionTokens.accessToken,
        sessionTokens.refreshToken,
        mfaToken,
        mfaProviders
      )

      do {
        try await features
          .instance(of: SessionLocking.self, context: account)
          .ensureAutolock()
      }
      catch {
        // ignore errors,
        // it can fail only if feature fails to load
        error
          .asTheError()
          .asAssertionFailure()
      }
    }

    @SessionActor func handleRefresh(
      account: Account,
      passphrase: Passphrase?,
      sessionTokens: SessionTokens,
      mfaToken: SessionMFAToken?
    ) throws {
      guard account == sessionState.account()
      else {
        InternalInconsistency
          .error("Invalid account session refreshed")
          .recording(account, for: "account")
          .asFatalError()
      }

      try sessionState
        .refreshedSession(
          account,
          passphrase,
          sessionTokens.accessToken,
          sessionTokens.refreshToken,
          mfaToken
        )
    }

    @SessionActor @Sendable func authorize(
      _ method: SessionAuthorizationMethod
    ) async throws {
      diagnostics.log(diagnostic: "Beginning authorization...")
      do {
        // prepare and validate authorization data
        let authorizationData: AuthorizationData = try validatedAuthorizationData(
          for: method
        )

        // perform same account authorization
        if authorizationData.account == sessionState.account() {
          // get mfa token earlier to ensure
          // mfa authorization was not requested
          // and to avoid refresh token clearing
          let mfaToken: SessionMFAToken? = try currentMFAToken(for: authorizationData.account)

          // check current token expiration
          if isCurrentAccessTokenValid() {
            diagnostics
              .log(diagnostic: "...reusing access token...")
            // extend passphrase cache expire time
            try sessionState
              .passphraseProvided(
                authorizationData.account,
                authorizationData.passphrase
              )
            diagnostics
              .log(diagnostic: "...authorization succeeded!")
            return  // nothing more to do...
          }
          // refresh session using refresh token
          else if let refreshToken: SessionRefreshToken = currentRefreshToken() {
            diagnostics
              .log(diagnostic: "...refreshing access token...")
            do {
              let sessionTokens: SessionTokens = try await refreshSessionTokens(
                authorizationData,
                refreshToken: refreshToken,
                mfaToken: mfaToken
              )

              try handleRefresh(
                account: authorizationData.account,
                passphrase: authorizationData.passphrase,
                sessionTokens: sessionTokens,
                mfaToken: mfaToken
              )
              diagnostics
                .log(diagnostic: "...authorization succeeded!")
              return  // nothing more to do...
            }
            catch {
              diagnostics.log(error: error)
              // ignore refresh error and fallback to regular
              // authorization  / create new tokens
              diagnostics
                .log(diagnostic: "...refreshing access token failed, fallback to token creation...")
            }
          }  // else / catch - continue

          diagnostics
            .log(diagnostic: "...creating new access token...")

          let (sessionTokens, requiredMFAProviders): (SessionTokens, Array<SessionMFAProvider>) =
            try await createSessionTokens(
              authorizationData,
              mfaToken: mfaToken
            )

          await handleAuthorization(
            account: authorizationData.account,
            passphrase: authorizationData.passphrase,
            sessionTokens: sessionTokens,
            mfaToken: requiredMFAProviders.isEmpty
              ? mfaToken
              : .none,
            mfaRequiredWithProviders: requiredMFAProviders
          )

          if requiredMFAProviders.isEmpty {
            diagnostics
              .log(diagnostic: "...authorization succeeded!")
            return  // nothing more to do...
          }
          else {
            diagnostics
              .log(diagnostic: "...authorization finished, mfa required!")
            throw
              SessionMFAAuthorizationRequired
              .error(
                account: authorizationData.account,
                mfaProviders: requiredMFAProviders
              )
          }
        }
        // diffrent or new account authorization
        else {
          diagnostics
            .log(diagnostic: "...creating new access token...")
          let mfaToken: SessionMFAToken? = storedMFAToken(
            for: authorizationData.account
          )

          let (sessionTokens, requiredMFAProviders): (SessionTokens, Array<SessionMFAProvider>) =
            try await createSessionTokens(
              authorizationData,
              mfaToken: mfaToken
            )

          await handleAuthorization(
            account: authorizationData.account,
            passphrase: authorizationData.passphrase,
            sessionTokens: sessionTokens,
            mfaToken: requiredMFAProviders.isEmpty
              ? mfaToken
              : .none,
            mfaRequiredWithProviders: requiredMFAProviders
          )

          if requiredMFAProviders.isEmpty {
            diagnostics
              .log(diagnostic: "...authorization succeeded!")
            return  // nothing more to do...
          }
          else {
            diagnostics
              .log(diagnostic: "...authorization finished, mfa required!")
            throw
              SessionMFAAuthorizationRequired
              .error(
                account: authorizationData.account,
                mfaProviders: requiredMFAProviders
              )
          }
        }
      }
      catch let error as SessionMFAAuthorizationRequired {
        // ignoring error
        try? accountsData
          .deleteAccountMFAToken(error.account.localID)
        throw error
      }
      catch {
        diagnostics
          .log(error: error)
        diagnostics
          .log(diagnostic: "...authorization failed!")
        throw error
      }
    }

    @SessionActor @Sendable func refreshTokens(
      _ account: Account,
      passphrase: Passphrase
    ) async throws {
      guard account == sessionState.account()
      else { throw SessionClosed.error(account: account) }

      diagnostics
        .log(diagnostic: "Refreshing session...")

      do {
        let authorizationData: AuthorizationData = try validatedAuthorizationData(
          for: .passphrase(account, passphrase)
        )

        // getting mfa token earlier to ensure
        // mfa authorization was not requested
        // and to avoid refresh token clear
        let mfaToken: SessionMFAToken? = try currentMFAToken(for: authorizationData.account)

        if let refreshToken: SessionRefreshToken = currentRefreshToken() {
          do {
            let sessionTokens: SessionTokens = try await refreshSessionTokens(
              authorizationData,
              refreshToken: refreshToken,
              mfaToken: mfaToken
            )

            try handleRefresh(
              account: authorizationData.account,
              passphrase: authorizationData.passphrase,
              sessionTokens: sessionTokens,
              mfaToken: mfaToken
            )
            diagnostics
              .log(diagnostic: "...session refresh succeeded!")
            return  // nothing more to do...
          }
          catch {
            diagnostics.log(error: error)
            // ignore refresh error and fallback to regular
            // authorization  / create new tokens
          }
        }  // else / catch - continue

        let (sessionTokens, requiredMFAProviders): (SessionTokens, Array<SessionMFAProvider>) =
          try await createSessionTokens(
            authorizationData,
            mfaToken: mfaToken
          )

        await handleAuthorization(
          account: authorizationData.account,
          passphrase: authorizationData.passphrase,
          sessionTokens: sessionTokens,
          mfaToken: requiredMFAProviders.isEmpty
            ? mfaToken
            : .none,
          mfaRequiredWithProviders: requiredMFAProviders
        )

        if requiredMFAProviders.isEmpty {
          diagnostics
            .log(diagnostic: "...session refresh succeeded!")
          return  // nothing more to do...
        }
        else {
          diagnostics
            .log(diagnostic: "...session refresh finished, mfa required!")
          throw
            SessionMFAAuthorizationRequired
            .error(
              account: authorizationData.account,
              mfaProviders: requiredMFAProviders
            )
        }
      }
      catch let error as SessionMFAAuthorizationRequired {
        // ignoring error
        try? accountsData
          .deleteAccountMFAToken(error.account.localID)
        sessionState.mfaTokenInvalidate()
        throw error
      }
      catch {
        diagnostics
          .log(error: error)
        diagnostics
          .log(diagnostic: "...session refresh failed!")
        throw error
      }
    }

    return Self(
      authorize: authorize(_:),
      refreshTokens: refreshTokens(_:passphrase:)
    )
  }
}

extension FeatureFactory {

  internal func usePassboltSessionAuthorization() {
    self.use(
      .disposable(
        SessionAuthorization.self,
        load: SessionAuthorization
          .load(features:)
      )
    )
  }
}
