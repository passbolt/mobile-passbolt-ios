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

import CommonModels
import Crypto
import Features
import NetworkClient

import struct Foundation.Data
import class Foundation.JSONDecoder
import class Foundation.JSONEncoder

internal struct NetworkSession {

  // returns nonempty Array<MFAProvider> if MFA authorization is required
  // otherwise empty (including case when MFA is enabled but current token was valid)
  internal var createSession:
    @AccountSessionActor (
      _ account: Account,
      _ armoredKey: ArmoredPGPPrivateKey,
      _ passphrase: Passphrase
    ) async throws -> Array<MFAProvider>
  internal var createMFAToken:
    @AccountSessionActor (
      _ account: Account,
      _ authorization: AccountSession.MFAAuthorizationMethod,
      _ storeLocally: Bool
    ) async throws -> Void

  internal var refreshSessionIfNeeded: @AccountSessionActor (Account) async throws -> Void
  internal var closeSession: @AccountSessionActor () async -> Void
}

extension NetworkSession {

  fileprivate typealias ServerPublicKeys = (
    publicPGP: ArmoredPGPPublicKey, pgpFingerprint: Fingerprint, rsa: PEMRSAPublicKey
  )
  fileprivate typealias ServerPublicKeysWithSignInChallenge = (
    serverPublicKeys: ServerPublicKeys, signInChallenge: ArmoredPGPMessage
  )
  fileprivate typealias ServerPublicKeysWithSignInTokens = (serverPublicKeys: ServerPublicKeys, signInTokens: Tokens)
  fileprivate typealias SignInTokensWithMFAStatus = (signInTokens: Tokens, mfaTokenIsValid: Bool)
  fileprivate typealias ServerPublicKeysWithSignInTokensAndMFAStatus = (
    serverPublicKeys: ServerPublicKeys, signInTokens: Tokens, mfaTokenIsValid: Bool
  )
  fileprivate typealias SessionStateWithMFAProviders = (state: NetworkSessionState, mfaProviders: Array<MFAProvider>)
}

extension NetworkSession: LegacyFeature {

  internal static func load(
    in environment: AppEnvironment,
    using features: FeatureFactory,
    cancellables: Cancellables
  ) async throws -> Self {
    let uuidGenerator: UUIDGenerator = environment.uuidGenerator
    let time: Time = environment.time
    let pgp: PGP = environment.pgp
    let signatureVerification: SignatureVerfication = environment.signatureVerfication

    let diagnostics: Diagnostics = try await features.instance()
    let accountDataStore: AccountsDataStore = try await features.instance()
    let fingerprintStorage: FingerprintStorage = try await features.instance()
    let networkClient: NetworkClient = try await features.instance()

    let encoder: JSONEncoder = .init()
    let decoder: JSONDecoder = .init()

    // always access with AccountSessionActor
    var currentSessionState: NetworkSessionState? = nil
    let sessionRefreshTask: ManagedTask<Void> = .init()

    await networkClient
      .setAccessTokenInvalidation(
        { @AccountSessionActor () async throws -> Void in
          currentSessionState?.accessToken = nil
        }
      )

    await networkClient
      .setSessionStateSource(
        { @AccountSessionActor () async throws -> NetworkClient.SessionState? in
          guard
            let sessionState: NetworkSessionState = currentSessionState
          else { return nil }
          // we are giving the token 5 second leeway to avoid making network requests
          // with a token that is about to expire since it might result in unauthorized response
          guard
            let accessToken: NetworkSessionState.AccessToken = sessionState.accessToken,
            !accessToken.isExpired(timestamp: time.timestamp(), leeway: 5)
          else {
            do {
              try await refreshSessionIfNeeded(account: sessionState.account)
              // if refresh succeeds currentSessionState should be
              // valid so just returning whatever ther is or throw an error
              guard
                let refreshedSessionState: NetworkSessionState = currentSessionState
              else { throw SessionMissing.error() }
              return NetworkClient.SessionState(
                domain: refreshedSessionState.account.domain,
                accessToken: refreshedSessionState.accessToken?.rawValue,
                mfaToken: refreshedSessionState.mfaToken?.rawValue
              )
            }
            catch {
              return NetworkClient.SessionState(
                domain: sessionState.account.domain,
                accessToken: nil,
                mfaToken: nil  // there is no point of using MFA without access token
              )
            }
          }

          return NetworkClient.SessionState(
            domain: sessionState.account.domain,
            accessToken: accessToken.rawValue,
            mfaToken: sessionState.mfaToken?.rawValue
          )
        }
      )

    @AccountSessionActor @Sendable func fetchServerPublicPGPKey(
      domain: URLString
    ) async throws -> ArmoredPGPPublicKey {
      diagnostics.diagnosticLog("...fetching server public PGP key...")

      let response: ServerPGPPublicKeyResponse =
        try await networkClient
        .serverPGPPublicKeyRequest
        .makeAsync(using: .init(domain: domain))

      return ArmoredPGPPublicKey(rawValue: response.body.keyData)
    }

    @AccountSessionActor @Sendable func fetchServerPublicRSAKey(
      domain: URLString
    ) async throws -> PEMRSAPublicKey {
      diagnostics.diagnosticLog("...fetching server public RSA key...")

      let response: ServerRSAPublicKeyResponse =
        try await networkClient
        .serverRSAPublicKeyRequest
        .makeAsync(using: .init(domain: domain))

      return PEMRSAPublicKey(rawValue: response.body.keyData)
    }

    @AccountSessionActor @Sendable func fetchServerPublicKeys(
      account: Account,
      domain: URLString
    ) async throws -> ServerPublicKeys {
      async let serverPublicPGPKey: ArmoredPGPPublicKey = fetchServerPublicPGPKey(domain: domain)
      async let serverPublicRSAKey: PEMRSAPublicKey = fetchServerPublicRSAKey(domain: domain)
      async let storedServerFingerprint: Fingerprint? = { @StorageAccessActor in
        do {
          return
            try fingerprintStorage
            .loadServerFingerprint(account.localID)
            .get()
        }
        catch {
          diagnostics.diagnosticLog("...server public PGP key fingerprint loading failed!")
          throw
            ServerPGPFingeprintInvalid
            .error(
              account: account,
              fingerprint: nil
            )
            .recording(error, for: "underlying error")
        }
      }()

      let (
        publicPGPKey,
        publicRSAKey,
        storedFingerprint
      ):
        (
          ArmoredPGPPublicKey,
          PEMRSAPublicKey,
          Fingerprint?
        ) =
          (
            try await serverPublicPGPKey,
            try await serverPublicRSAKey,
            try await storedServerFingerprint
          )

      var serverFingerprint: Fingerprint

      switch pgp.extractFingerprint(publicPGPKey) {
      case let .success(fingerprint):
        serverFingerprint = fingerprint

      case let .failure(error):
        diagnostics.diagnosticLog("...server public PGP key fingerprint extraction failed!")
        throw error
      }

      if let fingerprint = storedFingerprint {
        switch pgp.verifyPublicKeyFingerprint(publicPGPKey, fingerprint) {
        case let .success(match):
          if match {
            diagnostics.diagnosticLog("...server public PGP key fingerprint verification succeeded...")

            return ServerPublicKeys(
              publicPGP: publicPGPKey,
              pgpFingerprint: serverFingerprint,
              rsa: publicRSAKey
            )
          }
          else {
            diagnostics.diagnosticLog("...server public PGP key fingerprint verification failed!")
            throw
              ServerPGPFingeprintInvalid
              .error(
                account: account,
                fingerprint: serverFingerprint
              )
          }

        case let .failure(error):
          diagnostics.diagnosticLog("...server public PGP key fingerprint verification failed!")
          throw error
        }
      }
      else {
        diagnostics.diagnosticLog("...server public PGP key fingerprint verification skipped...")
        do {
          try await fingerprintStorage
            .storeServerFingerprint(
              account.localID,
              serverFingerprint
            )
            .get()
        }
        catch {
          diagnostics.diagnosticLog("...server public PGP key fingerprint save failed!")
          throw error
        }

        diagnostics.diagnosticLog("...server public PGP key fingerprint saved...")

        return ServerPublicKeys(
          publicPGP: publicPGPKey,
          pgpFingerprint: serverFingerprint,
          rsa: publicRSAKey
        )
      }
    }

    @AccountSessionActor @Sendable func prepareSignInChallenge(
      account: Account,
      domain: URLString,
      verificationToken: String,
      challengeExpiration: Int,
      serverPublicPGPKey: ArmoredPGPPublicKey,
      armoredPrivateKey: ArmoredPGPPrivateKey,
      passphrase: Passphrase
    ) async throws -> ArmoredPGPMessage {
      let challenge: SignInRequestChallenge = .init(
        version: "1.0.0",  // Protocol version 1.0.0
        token: verificationToken,
        domain: domain.rawValue,
        expiration: challengeExpiration
      )

      let encodedChallenge: String
      do {
        let challengeData: Data = try encoder.encode(challenge)

        guard let encoded: String = .init(bytes: challengeData, encoding: .utf8)
        else {
          diagnostics.diagnosticLog("...sign in challenge encoding failed!")
          throw
            SessionAuthorizationFailure
            .error(
              "Failed to encode sign in challenge to string",
              account: account
            )
        }
        encodedChallenge = encoded
      }
      catch {
        diagnostics.diagnosticLog("...sign in challenge encoding failed!")
        throw
          SessionAuthorizationFailure
          .error(
            "Failed to encode sign in challenge",
            account: account
          )
          .recording(error, for: "underlyingError")
      }

      let encryptAndSignResult: Result<String, Error> = pgp.encryptAndSign(
        encodedChallenge,
        passphrase,
        armoredPrivateKey,
        serverPublicPGPKey
      )

      let encryptedAndSignedChallenge: String
      switch encryptAndSignResult {
      case let .success(result):
        encryptedAndSignedChallenge = result

      case let .failure(error):
        diagnostics.diagnosticLog("...sign in challenge encryption with signature failed!")
        throw
          error
          .pushing(.message("Failed to encrypt and sign challenge"))
      }

      return ArmoredPGPMessage(
        rawValue: encryptedAndSignedChallenge
      )
    }

    @AccountSessionActor @Sendable func signIn(
      domain: URLString,
      userID: Account.UserID,
      challenge: ArmoredPGPMessage,
      mfaToken: MFAToken?
    ) async throws -> (challenge: String, mfaTokenIsValid: Bool) {
      let response: SignInResponse =
        try await networkClient
        .signInRequest
        .makeAsync(
          using: .init(
            domain: domain,
            userID: userID.rawValue,
            challenge: challenge,
            mfaToken: mfaToken
          )
        )

      return (
        challenge: response.body.body.challenge,
        mfaTokenIsValid: response.mfaTokenIsValid
      )
    }

    @AccountSessionActor @Sendable func decryptVerifyResponse(
      account: Account,
      encryptedResponsePayload: String,
      serverPublicPGPKey: ArmoredPGPPublicKey,
      armoredPrivateKey: ArmoredPGPPrivateKey,
      passphrase: Passphrase
    ) async throws -> Tokens {
      let decryptedResponsePayloadResult: Result<String, Error> = pgp.decryptAndVerify(
        encryptedResponsePayload,
        passphrase,
        armoredPrivateKey,
        serverPublicPGPKey
      )

      let decryptedResponsePayload: String
      switch decryptedResponsePayloadResult {
      case let .success(result):
        decryptedResponsePayload = result

      case let .failure(error):
        diagnostics.diagnosticLog("...server response decryption failed!")
        throw
          error
          .pushing(.message("Unable to decrypt and verify response"))
      }

      let tokenData: Data = decryptedResponsePayload.data(using: .utf8) ?? Data()
      let tokens: Tokens

      do {
        tokens = try decoder.decode(Tokens.self, from: tokenData)
      }
      catch {
        diagnostics.diagnosticLog("...server response tokens decoding failed!")
        throw
          SessionAuthorizationFailure
          .error(
            "Failed to decode sign in tokens",
            account: account
          )
      }

      diagnostics.diagnosticLog("...received session tokens...")
      return tokens
    }

    @AccountSessionActor @Sendable func signInAndDecryptVerifyResponse(
      domain: URLString,
      account: Account,
      signInChallenge: ArmoredPGPMessage,
      mfaToken: MFAToken?,
      serverPublicPGPKey: ArmoredPGPPublicKey,
      armoredPrivateKey: ArmoredPGPPrivateKey,
      passphrase: Passphrase
    ) async throws -> SignInTokensWithMFAStatus {
      let (
        encryptedResponsePayload,
        mfaTokenIsValid
      ): (String, Bool) =
        try await signIn(
          domain: domain,
          userID: account.userID,
          challenge: signInChallenge,
          mfaToken: mfaToken
        )

      let tokens: Tokens = try await decryptVerifyResponse(
        account: account,
        encryptedResponsePayload: encryptedResponsePayload,
        serverPublicPGPKey: serverPublicPGPKey,
        armoredPrivateKey: armoredPrivateKey,
        passphrase: passphrase
      )

      return SignInTokensWithMFAStatus(
        signInTokens: tokens,
        mfaTokenIsValid: mfaTokenIsValid
      )
    }

    @AccountSessionActor @Sendable func decodeVerifySignInTokens(
      account: Account,
      signInTokens: Tokens,
      mfaToken: MFAToken?,
      serverPublicRSAKey: PEMRSAPublicKey,
      verificationToken: String,
      challengeExpiration: Int
    ) async throws -> SessionStateWithMFAProviders {
      let accessToken: JWT
      switch JWT.from(rawValue: signInTokens.accessToken) {
      case let .success(jwt):
        accessToken = jwt

      case let .failure(error):
        diagnostics.diagnosticLog("...session tokens decoding failed!")
        throw
          error
          .pushing(.message("Failed to prepare for signature verification"))
      }

      guard
        verificationToken == signInTokens.verificationToken,
        challengeExpiration > time.timestamp().rawValue,
        let signature: Data = accessToken.signature.base64DecodeFromURLEncoded(),
        let signedData: Data = accessToken.signedPayload.data(using: .utf8)
      else {
        diagnostics.diagnosticLog("...session tokens verification failed!")
        throw
          SessionAuthorizationFailure
          .error(
            "Failed to prepare sign in tokens signature verification",
            account: account
          )
      }

      switch signatureVerification.verify(signedData, signature, serverPublicRSAKey) {
      case .success:
        diagnostics.diagnosticLog("...session tokens signature verification succeeded...")
        return SessionStateWithMFAProviders(
          state: NetworkSessionState(
            account: account,
            accessToken: accessToken,
            refreshToken: NetworkSessionState.RefreshToken(rawValue: signInTokens.refreshToken),
            mfaToken: mfaToken
          ),
          mfaProviders: signInTokens.mfaProviders.map { mfaToken == .none ? $0 : [] } ?? []
        )

      case let .failure(error):
        diagnostics.diagnosticLog("...session tokens signature verification failed!")
        throw
          error
          .pushing(.message("Signature verification failed"))
      }
    }

    @AccountSessionActor func createSession(
      account: Account,
      armoredPrivateKey: ArmoredPGPPrivateKey,
      passphrase: Passphrase
    ) async throws -> Array<MFAProvider> {
      await sessionRefreshTask.cancel()
      currentSessionState = nil

      let verificationToken: String = uuidGenerator().uuidString
      // 120s is verification token's lifetime
      let challengeExpiration: Int = time.timestamp().rawValue + 120

      let mfaToken: MFAToken? =
        try? await accountDataStore
        .loadAccountMFAToken(account.localID)
        .get()

      let serverPublicKeys: ServerPublicKeys =
        try await fetchServerPublicKeys(
          account: account,
          domain: account.domain
        )

      let signInChallenge: ArmoredPGPMessage =
        try await prepareSignInChallenge(
          account: account,
          domain: account.domain,
          verificationToken: verificationToken,
          challengeExpiration: challengeExpiration,
          serverPublicPGPKey: serverPublicKeys.publicPGP,
          armoredPrivateKey: armoredPrivateKey,
          passphrase: passphrase
        )

      let (
        signInTokens,
        mfaTokenIsValid
      ): (Tokens, Bool) =
        try await signInAndDecryptVerifyResponse(
          domain: account.domain,
          account: account,
          signInChallenge: signInChallenge,
          mfaToken: mfaToken,
          serverPublicPGPKey: serverPublicKeys.publicPGP,
          armoredPrivateKey: armoredPrivateKey,
          passphrase: passphrase
        )

      let (
        newSessionState,
        mfaProviders
      ): (NetworkSessionState, Array<MFAProvider>) =
        try await decodeVerifySignInTokens(
          account: account,
          signInTokens: signInTokens,
          mfaToken: mfaTokenIsValid ? mfaToken : .none,
          serverPublicRSAKey: serverPublicKeys.rsa,
          verificationToken: verificationToken,
          challengeExpiration: challengeExpiration
        )

      currentSessionState = newSessionState

      if mfaToken != nil && !mfaTokenIsValid {
        _ = await accountDataStore.deleteAccountMFAToken(account.localID)  // ignoring result
      }
      else { /* NOP */
      }

      return mfaProviders
    }

    @AccountSessionActor func createMFAToken(
      account: Account,
      authorization: AccountSession.MFAAuthorizationMethod,
      storeLocally: Bool
    ) async throws {
      guard
        let sessionState: NetworkSessionState = currentSessionState,
        // there might be session refresh attempt here
        let accessToken: NetworkSessionState.AccessToken = sessionState.accessToken
      else {
        diagnostics.diagnosticLog("...missing session for mfa auth!")
        throw
          SessionMissing
          .error("Missing network session for MFA authorization")
      }

      guard sessionState.account == account
      else {
        diagnostics.diagnosticLog("...invalid account for mfa auth!")
        throw
          SessionClosed
          .error(
            "Closed session used for MFA authorization",
            account: account
          )
          .recording(sessionState, for: "currentAccount")
          .recording(account, for: "expectedAccount")
      }

      switch authorization {
      case let .totp(otp):
        diagnostics.diagnosticLog("...verifying otp...")
        let token: MFAToken =
          try await networkClient
          .totpAuthorizationRequest
          .makeAsync(
            using: .init(
              accessToken: accessToken.rawValue,
              totp: otp,
              remember: storeLocally
            )
          )
          .mfaToken

        guard currentSessionState?.account == account
        else {
          diagnostics.diagnosticLog("...invalid account for mfa auth!")
          throw
            SessionClosed
            .error(
              "Closed session used for MFA authorization",
              account: account
            )
            .recording(currentSessionState?.account as Any, for: "currentAccount")
            .recording(account, for: "expectedAccount")
        }
        if storeLocally {
          try await accountDataStore
            .storeAccountMFAToken(account.localID, token)
            .get()
        }
        else { /* NOP */
        }
        currentSessionState?.mfaToken = token

      case let .yubikeyOTP(otp):
        diagnostics.diagnosticLog("...verifying yubikey otp...")
        let token: MFAToken =
          try await networkClient
          .yubikeyAuthorizationRequest
          .makeAsync(
            using: .init(
              accessToken: accessToken.rawValue,
              otp: otp,
              remember: storeLocally
            )
          )
          .mfaToken

        guard currentSessionState?.account == account
        else {
          diagnostics.diagnosticLog("...invalid account for mfa auth!")
          throw
            SessionClosed
            .error(
              "Closed session used for MFA authorization",
              account: account
            )
            .recording(currentSessionState?.account as Any, for: "currentAccount")
            .recording(account, for: "expectedAccount")
        }
        if storeLocally {
          try await accountDataStore
            .storeAccountMFAToken(account.localID, token)
            .get()
        }
        else { /* NOP */
        }
        currentSessionState?.mfaToken = token
      }
    }

    @AccountSessionActor func refreshSessionIfNeeded(
      account: Account
    ) async throws {
      try await sessionRefreshTask.run { @AccountSessionActor in
        diagnostics.diagnosticLog("Refreshing session...")
        guard let sessionState: NetworkSessionState = currentSessionState
        else {
          diagnostics.diagnosticLog("...missing session for session refresh!")
          throw
            SessionMissing
            .error("Missing network session for session refresh.")
        }
        guard sessionState.account == account
        else {
          diagnostics.diagnosticLog("...invalid account for session refresh!")
          throw
            SessionClosed
            .error(
              "Closed session used for session refresh",
              account: account
            )
            .recording(sessionState.account, for: "currentAccount")
            .recording(account, for: "expectedAccount")
        }
        // we are giving the token 5 second leeway to avoid making network requests
        // with a token that is about to expire since it might result in unauthorized response
        guard sessionState.accessToken?.isExpired(timestamp: time.timestamp(), leeway: 5) ?? true
        else {
          diagnostics.diagnosticLog("... session refresh not required, reusing current session!")
          return  // if current access token is valid there is no need to refresh
        }

        guard let refreshToken: NetworkSessionState.RefreshToken = sessionState.refreshToken
        else {
          diagnostics.diagnosticLog("...missing refresh token for session refresh!")
          throw
            SessionMissing
            .error("Missing network session refresh token for session refresh.")
        }
        currentSessionState?.refreshToken = nil  // consume token

        diagnostics.diagnosticLog("...requesting token refresh...")
        let response: RefreshSessionResponse =
          try await networkClient
          .refreshSessionRequest
          .makeAsync(
            using: .init(
              domain: account.domain,
              userID: sessionState.account.userID.rawValue,
              refreshToken: refreshToken.rawValue,
              mfaToken: sessionState.mfaToken?.rawValue
            )
          )

        let accessToken: JWT
        switch JWT.from(rawValue: response.accessToken) {
        case let .success(jwt):
          accessToken = jwt

        case let .failure(error):
          diagnostics.diagnosticLog("...jwt access token decoding failed!")
          throw
            error
            .pushing(.message("JWT decoding failed"))
        }

        guard
          let signature: Data = accessToken.signature.base64DecodeFromURLEncoded(),
          let signedData: Data = accessToken.signedPayload.data(using: .utf8)
        else {
          diagnostics.diagnosticLog("...jwt access token verification not possible!")
          throw
            SessionAuthorizationFailure
            .error(
              "JWT token verification not possible",
              account: account
            )
        }

        let serverPublicRSAKey: PEMRSAPublicKey = try await fetchServerPublicRSAKey(domain: account.domain)

        switch signatureVerification.verify(signedData, signature, serverPublicRSAKey) {
        case .success:
          diagnostics.diagnosticLog("...jwt access token verification succeeded...")
          guard currentSessionState?.account == account
          else {
            diagnostics.diagnosticLog("...session refresh failed due to account switch!")
            throw
              SessionClosed
              .error(
                "Closed session used for session refresh",
                account: account
              )
              .recording(currentSessionState?.account as Any, for: "currentAccount")
              .recording(account, for: "expectedAccount")
          }
          currentSessionState = .init(
            account: account,
            accessToken: accessToken,
            refreshToken: .init(rawValue: response.refreshToken),
            mfaToken: currentSessionState?.mfaToken
          )
          diagnostics.diagnosticLog("...session refresh succeeded!")

        case let .failure(error):
          diagnostics.diagnosticLog("...jwt access token verification failed!")
          throw
            error
            .pushing(.message("JWT verification failed"))
        }
      }
    }

    @AccountSessionActor func closeSession() async {
      await sessionRefreshTask.cancel()
      if let domain: URLString = currentSessionState?.account.domain,
        let refreshToken: NetworkSessionState.RefreshToken = currentSessionState?.refreshToken
      {
        do {
          try await networkClient
            .signOutRequest
            .makeAsync(
              using: SignOutRequestVariable(
                domain: domain,
                refreshToken: refreshToken.rawValue
              )
            )
        }
        catch { /* NOP */  }
      }
      else { /* NOP */
      }
      currentSessionState = nil
    }

    return Self(
      createSession: createSession(account:armoredPrivateKey:passphrase:),
      createMFAToken: createMFAToken(account:authorization:storeLocally:),
      //      sessionRefreshAvailable: sessionRefreshAvailable,
      refreshSessionIfNeeded: refreshSessionIfNeeded,
      closeSession: closeSession
    )
  }
}

extension NetworkSession {

  public var featureUnload: @FeaturesActor () async throws -> Void { {} }
}

#if DEBUG
extension NetworkSession {

  internal static var placeholder: Self {
    Self(
      createSession: unimplemented("You have to provide mocks for used methods"),
      createMFAToken: unimplemented("You have to provide mocks for used methods"),
      refreshSessionIfNeeded: unimplemented("You have to provide mocks for used methods"),
      closeSession: unimplemented("You have to provide mocks for used methods")
    )
  }
}
#endif
