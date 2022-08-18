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

  internal var authorize: @SessionActor @Sendable (SessionAuthorizationMethod) async throws -> Void
  internal var refreshTokens: @SessionActor @Sendable (Account, Passphrase) async throws -> Void
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

    let diagnostics: Diagnostics = try await features.instance()
    let sessionState: SessionState = try await features.instance()
    let sessionAuthorizationState: SessionAuthorizationState = try await features.instance()
    let sessionNetworkAuthorization: SessionNetworkAuthorization = try await features.instance()
    let accountsData: AccountsDataStore = try await features.instance()
    let pgp: PGP = try features.instance(of: EnvironmentLegacyBridge.self).environment.pgp
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
        diagnostics.log(error)
        return false
      }
    }

    @SessionActor @Sendable func isCurrentAccessTokenValid() -> Bool {
      // expiration time is checked on the SessionState side
      // but using greater leeway to refresh session more
      // eagerly when already performing authorization
      !(sessionState.validAccessToken()?
        .isExpired(timestamp: osTime.timestamp(), leeway: 30)
        ?? true)
    }

    @SessionActor @Sendable func currentRefreshToken() -> SessionRefreshToken? {
      // refresh token is cleared on the SessionState side
      // right after accessing it, it can't be reused
      sessionState.refreshToken()
    }

    @SessionActor @Sendable func currentMFAToken() throws -> SessionMFAToken? {
      // TODO: FIXME!
      if case let .mfa(account, mfaProviders) = sessionAuthorizationState.pendingAuthorization() {
        throw
          SessionMFAAuthorizationRequired
          .error(
            account: account,
            mfaProviders: mfaProviders
          )
      }
      else {
        return sessionState.mfaToken()
      }
    }

    @SessionActor @Sendable func storedMFAToken(
      for account: Account
    ) -> SessionMFAToken? {
      try? accountsData
        .loadAccountMFAToken(account.localID)
        .map(SessionMFAToken.init(rawValue:))
    }

    @SessionActor @Sendable func createSessionTokens(
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
      mfaToken: SessionMFAToken?
    ) async {
      await features
        .ensureScope(identifier: account)
      accountsData
        .storeLastUsedAccount(account.localID)
      sessionState
        .setAccount(account)
      sessionState
        .setPassphrase(passphrase)
      sessionState
        .setAccessToken(sessionTokens.accessToken)
      sessionState
        .setRefreshToken(sessionTokens.refreshToken)
      sessionState
        .setMFAToken(mfaToken)
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
      sessionState.updatesSequenceSource.sendUpdate()
    }

    @SessionActor @Sendable func handleRefresh(
      account: Account,
      passphrase: Passphrase?,
      sessionTokens: SessionTokens,
      mfaToken: SessionMFAToken?
    ) async {
      guard account == sessionState.account()
      else {
        InternalInconsistency
          .error("Invalid account session refreshed")
          .recording(account, for: "account")
          .asFatalError()
      }

      if let passphrase: Passphrase = passphrase {
        // extend passphrase cache expire time
        sessionState
          .setPassphrase(passphrase)
      }  // else NOP
      sessionState
        .setAccessToken(sessionTokens.accessToken)
      sessionState
        .setRefreshToken(sessionTokens.refreshToken)
      sessionState
        .setMFAToken(mfaToken)
    }

    @SessionActor @Sendable func authorize(
      _ method: SessionAuthorizationMethod
    ) async throws {
      diagnostics.diagnosticLog("Beginning authorization...")
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
          let mfaToken: SessionMFAToken? = try currentMFAToken()

          // check current token expiration
          if isCurrentAccessTokenValid() {
            diagnostics
              .diagnosticLog("...reusing access token...")
            // extend passphrase cache expire time
            sessionState
              .setPassphrase(authorizationData.passphrase)
            diagnostics
              .diagnosticLog("...authorization succeeded!")
            return  // nothing more to do...
          }
          // refresh session using refresh token
          else if let refreshToken: SessionRefreshToken = currentRefreshToken() {
            diagnostics
              .diagnosticLog("...refreshing access token...")
            do {
              let sessionTokens: SessionTokens = try await refreshSessionTokens(
                authorizationData,
                refreshToken: refreshToken,
                mfaToken: mfaToken
              )

              await handleRefresh(
                account: authorizationData.account,
                passphrase: authorizationData.passphrase,
                sessionTokens: sessionTokens,
                mfaToken: mfaToken
              )
              diagnostics
                .diagnosticLog("...authorization succeeded!")
              return  // nothing more to do...
            }
            catch {
              diagnostics.log(error)
              // ignore refresh error and fallback to regular
              // authorization  / create new tokens
              diagnostics
                .diagnosticLog("...refreshing access token failed, fallback to token creation...")
            }
          }  // else / catch - continue

          diagnostics
            .diagnosticLog("...creating new access token...")

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
              : .none
          )

          if requiredMFAProviders.isEmpty {
            diagnostics
              .diagnosticLog("...authorization succeeded!")
            return  // nothing more to do...
          }
          else {
            diagnostics
              .diagnosticLog("...authorization finished, mfa required!")
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
            .diagnosticLog("...creating new access token...")
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
              : .none
          )

          if requiredMFAProviders.isEmpty {
            diagnostics
              .diagnosticLog("...authorization succeeded!")
            return  // nothing more to do...
          }
          else {
            diagnostics
              .diagnosticLog("...authorization finished, mfa required!")
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
          .log(error)
        diagnostics
          .diagnosticLog("...authorization failed!")
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
        .diagnosticLog("Refreshing session...")

      do {
        let authorizationData: AuthorizationData = try validatedAuthorizationData(
          for: .passphrase(account, passphrase)
        )

        // getting mfa token earlier to ensure
        // mfa authorization was not requested
        // and to avoid refresh token clear
        let mfaToken: SessionMFAToken? = try currentMFAToken()

        if let refreshToken: SessionRefreshToken = currentRefreshToken() {
          do {
            let sessionTokens: SessionTokens = try await refreshSessionTokens(
              authorizationData,
              refreshToken: refreshToken,
              mfaToken: mfaToken
            )

            await handleRefresh(
              account: authorizationData.account,
              passphrase: authorizationData.passphrase,
              sessionTokens: sessionTokens,
              mfaToken: mfaToken
            )
            diagnostics
              .diagnosticLog("...session refresh succeeded!")
            return  // nothing more to do...
          }
          catch {
            diagnostics.log(error)
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
            : .none
        )

        if requiredMFAProviders.isEmpty {
          diagnostics
            .diagnosticLog("...session refresh succeeded!")
          return  // nothing more to do...
        }
        else {
          diagnostics
            .diagnosticLog("...session refresh finished, mfa required!")
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
        sessionState.setMFAToken(.none)
        throw error
      }
      catch {
        diagnostics
          .log(error)
        diagnostics
          .diagnosticLog("...session refresh failed!")
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
