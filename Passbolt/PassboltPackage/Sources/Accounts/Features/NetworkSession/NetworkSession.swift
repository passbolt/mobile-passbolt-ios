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

import CommonDataModels
import Commons
import Crypto
import Features
import NetworkClient

import struct Foundation.Data
import class Foundation.JSONDecoder
import class Foundation.JSONEncoder
import class Foundation.NSRecursiveLock

internal struct NetworkSession {

  // returns nonempty Array<MFAProvider> if MFA authorization is required
  // otherwise empty (including case when MFA is enabled but current token was valid)
  internal var createSession:
    (
      _ account: Account,
      _ armoredKey: ArmoredPGPPrivateKey,
      _ passphrase: Passphrase
    ) -> AnyPublisher<Array<MFAProvider>, TheErrorLegacy>

  internal var createMFAToken:
    (
      _ account: Account,
      _ authorization: AccountSession.MFAAuthorizationMethod,
      _ storeLocally: Bool
    ) -> AnyPublisher<Void, TheErrorLegacy>
  internal var sessionRefreshAvailable: (Account) -> Bool
  internal var refreshSessionIfNeeded: (Account) -> AnyPublisher<Void, TheErrorLegacy>
  internal var closeSession: () -> AnyPublisher<Void, TheErrorLegacy>
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

extension NetworkSession: Feature {

  internal static func load(
    in environment: Environment,
    using features: FeatureFactory,
    cancellables: Cancellables
  ) -> Self {
    let encoder: JSONEncoder = .init()
    let decoder: JSONDecoder = .init()

    let uuidGenerator: UUIDGenerator = environment.uuidGenerator
    let time: Time = environment.time
    let pgp: PGP = environment.pgp
    let signatureVerification: SignatureVerfication = environment.signatureVerfication

    let diagnostics: Diagnostics = features.instance()
    let accountDataStore: AccountsDataStore = features.instance()
    let fingerprintStorage: FingerprintStorage = features.instance()
    let networkClient: NetworkClient = features.instance()

    let sessionAccessLock: NSRecursiveLock = .init()
    let sessionStateSubject: CurrentValueSubject<NetworkSessionState?, Never> = .init(nil)
    // synchonizing access to session tokens due to possible race conditions
    // CurrentValueSubject is thread safe but in some cases
    // we have to ensure state changes happen in sync with previous value
    // while other threads might try to access it in the mean time
    var sessionState: NetworkSessionState? {
      get {
        sessionAccessLock.lock()
        defer { sessionAccessLock.unlock() }
        return sessionStateSubject.value
      }
      set {
        sessionAccessLock.lock()
        sessionStateSubject.value = newValue
        sessionAccessLock.unlock()
      }
    }
    func withSessionState<Returned>(
      _ access: (inout NetworkSessionState?) -> Returned
    ) -> Returned {
      sessionAccessLock.lock()
      defer { sessionAccessLock.unlock() }
      var value: NetworkSessionState? = sessionStateSubject.value
      defer { sessionStateSubject.send(value) }
      return access(&value)
    }

    // swift-format-ignore: NoLeadingUnderscores
    var _ongoingSessionRefresh: (resultPublisher: AnyPublisher<Void, TheErrorLegacy>, cancellable: AnyCancellable)?
    var ongoingSessionRefresh: (resultPublisher: AnyPublisher<Void, TheErrorLegacy>, cancellable: AnyCancellable)? {
      get {
        sessionAccessLock.lock()
        defer { sessionAccessLock.unlock() }
        return _ongoingSessionRefresh
      }
      set {
        sessionAccessLock.lock()
        _ongoingSessionRefresh = newValue
        sessionAccessLock.unlock()
      }
    }

    networkClient
      .setAccessTokenInvalidation(
        {
          withSessionState { session in
            session?.accessToken = nil
          }
        }
      )

    networkClient
      .setSessionStatePublisher(
        sessionStateSubject
          .removeDuplicates()
          .map { (sessionState: NetworkSessionState?) -> AnyPublisher<NetworkClient.SessionState?, Never> in
            guard
              let sessionState: NetworkSessionState = sessionState
            else {
              return Just(nil)
                .eraseToAnyPublisher()
            }
            // we are giving the token 5 second leeway to avoid making network requests
            // with a token that is about to expire since it might result in unauthorized response
            guard
              let accessToken: NetworkSessionState.AccessToken = sessionState.accessToken,
              !accessToken.isExpired(timestamp: time.timestamp(), leeway: 5)
            else {
              return refreshSessionIfNeeded(account: sessionState.account)
                .ignoreOutput()  // on success it should recompute whole map and result should not be needed
                .map { _ -> NetworkClient.SessionState? in /* NOP */ }
                .replaceError(  // in case of error treat it as no access token
                  with: NetworkClient.SessionState(
                    domain: sessionState.account.domain,
                    accessToken: nil,
                    mfaToken: nil  // there is no point of using MFA without access token
                  )
                )
                .eraseToAnyPublisher()
            }

            return Just(
              NetworkClient.SessionState(
                domain: sessionState.account.domain,
                accessToken: accessToken.rawValue,
                mfaToken: sessionState.mfaToken?.rawValue
              )
            )
            .eraseToAnyPublisher()
          }
          .switchToLatest()
          .eraseToAnyPublisher()
      )

    func fetchServerPublicPGPKey(
      domain: URLString
    ) -> AnyPublisher<ArmoredPGPPublicKey, TheErrorLegacy> {
      networkClient
        .serverPGPPublicKeyRequest
        .make(using: .init(domain: domain))
        .handleEvents(receiveSubscription: { _ in
          diagnostics.diagnosticLog("...fetching server public PGP key...")
        })
        .map { response in
          ArmoredPGPPublicKey(rawValue: response.body.keyData)
        }
        .eraseToAnyPublisher()
    }

    func fetchServerPublicRSAKey(
      domain: URLString
    ) -> AnyPublisher<PEMRSAPublicKey, TheErrorLegacy> {
      networkClient
        .serverRSAPublicKeyRequest
        .make(using: .init(domain: domain))
        .handleEvents(receiveSubscription: { _ in
          diagnostics.diagnosticLog("...fetching server public RSA key...")
        })
        .map { response in
          PEMRSAPublicKey(rawValue: response.body.keyData)
        }
        .eraseToAnyPublisher()
    }

    func fetchServerPublicKeys(
      accountID: Account.LocalID,
      domain: URLString
    ) -> AnyPublisher<ServerPublicKeys, TheErrorLegacy> {
      Publishers.CombineLatest(
        fetchServerPublicPGPKey(domain: domain),
        fetchServerPublicRSAKey(domain: domain)
      )
      .map { (publicPGP: ArmoredPGPPublicKey, rsa: PEMRSAPublicKey) -> AnyPublisher<ServerPublicKeys, TheErrorLegacy> in
        var existingFingerprint: Fingerprint? = nil
        var serverFingerprint: Fingerprint

        switch pgp.extractFingerprint(publicPGP) {
        case let .success(fingerprint):
          serverFingerprint = fingerprint

        case let .failure(error):
          diagnostics.diagnosticLog("...server public PGP key fingerprint extraction failed!")
          return Fail(error: error)
            .eraseToAnyPublisher()
        }

        switch fingerprintStorage.loadServerFingerprint(accountID) {
        case let .success(fingerprint):
          existingFingerprint = fingerprint

        case .failure:
          diagnostics.diagnosticLog("...server public PGP key fingerprint loading failed!")
          return Fail(
            error: .invalidServerFingerprint(
              accountID: accountID,
              updatedFingerprint: serverFingerprint
            )
          )
          .eraseToAnyPublisher()
        }

        if let fingerprint = existingFingerprint {
          switch pgp.verifyPublicKeyFingerprint(publicPGP, fingerprint) {
          case let .success(match):
            if match {
              diagnostics.diagnosticLog("...server public PGP key fingerprint verification succeeded...")
              return Just(
                ServerPublicKeys(publicPGP: publicPGP, pgpFingerprint: serverFingerprint, rsa: rsa)
              )
              .setFailureType(to: TheErrorLegacy.self)
              .eraseToAnyPublisher()
            }
            else {
              diagnostics.diagnosticLog("...server public PGP key fingerprint verification failed!")
              return Fail(
                error: .invalidServerFingerprint(
                  accountID: accountID,
                  updatedFingerprint: serverFingerprint
                )
              )
              .eraseToAnyPublisher()
            }

          case let .failure(error):
            return Fail(error: error)
              .eraseToAnyPublisher()
          }
        }
        else {
          diagnostics.diagnosticLog("...server public PGP key fingerprint verification skipped...")
          switch fingerprintStorage.storeServerFingerprint(accountID, serverFingerprint) {
          case let .failure(error):
            diagnostics.diagnosticLog("...server public PGP key fingerprint save failed!")
            return Fail(error: error)
              .eraseToAnyPublisher()
          case _:
            break
          }
          diagnostics.diagnosticLog("...server public PGP key fingerprint saved...")
          return Just(
            ServerPublicKeys(publicPGP: publicPGP, pgpFingerprint: serverFingerprint, rsa: rsa)
          )
          .setFailureType(to: TheErrorLegacy.self)
          .eraseToAnyPublisher()
        }
      }
      .switchToLatest()
      .eraseToAnyPublisher()
    }

    func prepareSignInChallenge(
      domain: URLString,
      verificationToken: String,
      challengeExpiration: Int,
      serverPublicPGPKey: ArmoredPGPPublicKey,
      armoredPrivateKey: ArmoredPGPPrivateKey,
      passphrase: Passphrase
    ) -> AnyPublisher<ArmoredPGPMessage, TheErrorLegacy> {
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
          return Fail<ArmoredPGPMessage, TheErrorLegacy>(
            error: .signInError()
              .appending(context: "Failed to encode challenge to string")
          )
          .eraseToAnyPublisher()
        }
        encodedChallenge = encoded
      }
      catch {
        diagnostics.diagnosticLog("...sign in challenge encoding failed!")
        return Fail<ArmoredPGPMessage, TheErrorLegacy>(
          error: .signInError(underlyingError: error)
            .appending(context: "Failed to encode challenge")
        )
        .eraseToAnyPublisher()
      }

      let encryptAndSignResult: Result<String, TheErrorLegacy> = pgp.encryptAndSign(
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
        return Fail<ArmoredPGPMessage, TheErrorLegacy>(
          error: error.appending(logMessage: "Failed to encrypt and sign challenge")
        )
        .eraseToAnyPublisher()
      }

      return Just(
        ArmoredPGPMessage(
          rawValue: encryptedAndSignedChallenge
        )
      )
      .setFailureType(to: TheErrorLegacy.self)
      .eraseToAnyPublisher()
    }

    func signIn(
      domain: URLString,
      userID: Account.UserID,
      challenge: ArmoredPGPMessage,
      mfaToken: MFAToken?
    ) -> AnyPublisher<(challenge: String, mfaTokenIsValid: Bool), TheErrorLegacy> {
      return networkClient
        .signInRequest
        .make(
          using: .init(
            domain: domain,
            userID: userID.rawValue,
            challenge: challenge,
            mfaToken: mfaToken
          )
        )
        .map { response in
          (
            challenge: response.body.body.challenge,
            mfaTokenIsValid: response.mfaTokenIsValid
          )
        }
        .eraseToAnyPublisher()
    }

    func decryptVerifyResponse(
      encryptedResponsePayload: String,
      serverPublicPGPKey: ArmoredPGPPublicKey,
      armoredPrivateKey: ArmoredPGPPrivateKey,
      passphrase: Passphrase
    ) -> AnyPublisher<Tokens, TheErrorLegacy> {
      let decryptedResponsePayloadResult: Result<String, TheErrorLegacy> = pgp.decryptAndVerify(
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
        return Fail<Tokens, TheErrorLegacy>(
          error: error.appending(logMessage: "Unable to decrypt and verify response")
        )
        .eraseToAnyPublisher()
      }

      let tokenData: Data = decryptedResponsePayload.data(using: .utf8) ?? Data()
      let tokens: Tokens

      do {
        tokens = try decoder.decode(Tokens.self, from: tokenData)
      }
      catch {
        diagnostics.diagnosticLog("...server response tokens decoding failed!")
        return Fail<Tokens, TheErrorLegacy>.init(
          error: .signInError(underlyingError: error)
        )
        .eraseToAnyPublisher()
      }

      diagnostics.diagnosticLog("...received session tokens...")
      return Just<Tokens>(tokens)
        .setFailureType(to: TheErrorLegacy.self)
        .eraseToAnyPublisher()
    }

    func signInAndDecryptVerifyResponse(
      domain: URLString,
      userID: Account.UserID,
      signInChallenge: ArmoredPGPMessage,
      mfaToken: MFAToken?,
      serverPublicPGPKey: ArmoredPGPPublicKey,
      armoredPrivateKey: ArmoredPGPPrivateKey,
      passphrase: Passphrase
    ) -> AnyPublisher<SignInTokensWithMFAStatus, TheErrorLegacy> {
      signIn(
        domain: domain,
        userID: userID,
        challenge: signInChallenge,
        mfaToken: mfaToken
      )
      .map {
        (encryptedResponsePayload: String, mfaTokenIsValid) -> AnyPublisher<SignInTokensWithMFAStatus, TheErrorLegacy>
        in
        decryptVerifyResponse(
          encryptedResponsePayload: encryptedResponsePayload,
          serverPublicPGPKey: serverPublicPGPKey,
          armoredPrivateKey: armoredPrivateKey,
          passphrase: passphrase
        )
        .map { tokens -> SignInTokensWithMFAStatus in
          SignInTokensWithMFAStatus(
            signInTokens: tokens,
            mfaTokenIsValid: mfaTokenIsValid
          )
        }
        .eraseToAnyPublisher()
      }
      .switchToLatest()
      .eraseToAnyPublisher()
    }

    func decodeVerifySignInTokens(
      account: Account,
      signInTokens: Tokens,
      mfaToken: MFAToken?,
      serverPublicRSAKey: PEMRSAPublicKey,
      verificationToken: String,
      challengeExpiration: Int
    ) -> AnyPublisher<SessionStateWithMFAProviders, TheErrorLegacy> {
      let accessToken: JWT
      switch JWT.from(rawValue: signInTokens.accessToken) {
      case let .success(jwt):
        accessToken = jwt

      case let .failure(error):
        diagnostics.diagnosticLog("...session tokens decoding failed!")
        return Fail<SessionStateWithMFAProviders, TheErrorLegacy>(
          error: error.appending(logMessage: "Failed to prepare for signature verification")
        )
        .eraseToAnyPublisher()
      }

      guard
        verificationToken == signInTokens.verificationToken,
        challengeExpiration > time.timestamp(),
        let signature: Data = accessToken.signature.base64DecodeFromURLEncoded(),
        let signedData: Data = accessToken.signedPayload.data(using: .utf8)
      else {
        diagnostics.diagnosticLog("...session tokens verification failed!")
        return Fail<SessionStateWithMFAProviders, TheErrorLegacy>(
          error: .signInError()
            .appending(logMessage: "Failed to prepare for signature verification")
        )
        .eraseToAnyPublisher()
      }

      switch signatureVerification.verify(signedData, signature, serverPublicRSAKey) {
      case .success:
        diagnostics.diagnosticLog("...session tokens signature verification succeeded...")
        return Just(
          SessionStateWithMFAProviders(
            state: NetworkSessionState(
              account: account,
              accessToken: accessToken,
              refreshToken: NetworkSessionState.RefreshToken(rawValue: signInTokens.refreshToken),
              mfaToken: mfaToken
            ),
            mfaProviders: signInTokens.mfaProviders.map { mfaToken == .none ? $0 : [] } ?? []
          )
        )
        .setFailureType(to: TheErrorLegacy.self)
        .eraseToAnyPublisher()

      case let .failure(error):
        diagnostics.diagnosticLog("...session tokens signature verification failed!")
        return Fail<SessionStateWithMFAProviders, TheErrorLegacy>(
          error: error.appending(logMessage: "Signature verification failed")
        )
        .eraseToAnyPublisher()
      }
    }

    func createSession(
      account: Account,
      armoredPrivateKey: ArmoredPGPPrivateKey,
      passphrase: Passphrase
    ) -> AnyPublisher<Array<MFAProvider>, TheErrorLegacy> {
      ongoingSessionRefresh?.cancellable.cancel()
      withSessionState { sessionState in sessionState = nil }

      let verificationToken: String = uuidGenerator().uuidString
      let challengeExpiration: Int  // 120s is verification token's lifetime
      = time.timestamp() + 120

      let mfaToken: MFAToken? =
        try? accountDataStore
        .loadAccountMFAToken(account.localID)
        .get()  // we don't care about the errors here

      return fetchServerPublicKeys(accountID: account.localID, domain: account.domain)
        .map {
          (serverPublicKeys: ServerPublicKeys) -> AnyPublisher<ServerPublicKeysWithSignInChallenge, TheErrorLegacy> in
          prepareSignInChallenge(
            domain: account.domain,
            verificationToken: verificationToken,
            challengeExpiration: challengeExpiration,
            serverPublicPGPKey: serverPublicKeys.publicPGP,
            armoredPrivateKey: armoredPrivateKey,
            passphrase: passphrase
          )
          .map { (challenge: ArmoredPGPMessage) -> ServerPublicKeysWithSignInChallenge in
            ServerPublicKeysWithSignInChallenge(
              serverPublicKeys: serverPublicKeys,
              signInChallenge: challenge
            )
          }
          .eraseToAnyPublisher()
        }
        .switchToLatest()
        .map {
          (serverPublicKeys: ServerPublicKeys, signInChallenge: ArmoredPGPMessage) -> AnyPublisher<
            ServerPublicKeysWithSignInTokensAndMFAStatus, TheErrorLegacy
          > in
          signInAndDecryptVerifyResponse(
            domain: account.domain,
            userID: account.userID,
            signInChallenge: signInChallenge,
            mfaToken: mfaToken,
            serverPublicPGPKey: serverPublicKeys.publicPGP,
            armoredPrivateKey: armoredPrivateKey,
            passphrase: passphrase
          )
          .map { (signInTokens: Tokens, mfaTokenIsValid: Bool) -> ServerPublicKeysWithSignInTokensAndMFAStatus in
            ServerPublicKeysWithSignInTokensAndMFAStatus(
              serverPublicKeys: serverPublicKeys,
              signInTokens: signInTokens,
              mfaTokenIsValid: mfaTokenIsValid
            )
          }
          .eraseToAnyPublisher()
        }
        .switchToLatest()
        .map {
          (serverPublicKeys: ServerPublicKeys, signInTokens: Tokens, mfaTokenIsValid: Bool) -> AnyPublisher<
            SessionStateWithMFAProviders, TheErrorLegacy
          > in
          decodeVerifySignInTokens(
            account: account,
            signInTokens: signInTokens,
            mfaToken: mfaTokenIsValid ? mfaToken : .none,
            serverPublicRSAKey: serverPublicKeys.rsa,
            verificationToken: verificationToken,
            challengeExpiration: challengeExpiration
          )
          .handleEvents(receiveOutput: { _ in
            guard mfaToken != nil, !mfaTokenIsValid else { return }
            _ = accountDataStore.deleteAccountMFAToken(account.localID)  // ignoring result
          })
          .eraseToAnyPublisher()
        }
        .switchToLatest()
        .handleEvents(receiveOutput: { (state: NetworkSessionState, _: Array<MFAProvider>) in
          var newSession: NetworkSessionState = state
          newSession.mfaToken = mfaToken
          withSessionState { (sessionState: inout NetworkSessionState?) -> Void in
            sessionState = newSession
          }
        })
        .map { (_: NetworkSessionState, mfaProviders: Array<MFAProvider>) -> Array<MFAProvider> in
          mfaProviders
        }
        .eraseToAnyPublisher()
    }

    func createMFAToken(
      account: Account,
      authorization: AccountSession.MFAAuthorizationMethod,
      storeLocally: Bool
    ) -> AnyPublisher<Void, TheErrorLegacy> {
      withSessionState { sessionState in
        guard
          let sessionState: NetworkSessionState = sessionState,
          let accessToken: NetworkSessionState.AccessToken = sessionState.accessToken  // there might be session refresh attempt here
        else {
          diagnostics.diagnosticLog("...missing session for mfa auth!")
          return Fail(error: .missingSessionError()).eraseToAnyPublisher()
        }
        guard sessionState.account == account
        else {
          diagnostics.diagnosticLog("...invalid account for mfa auth!")
          return Fail(error: .sessionClosed()).eraseToAnyPublisher()
        }

        switch authorization {
        case let .totp(otp):
          diagnostics.diagnosticLog("...verifying otp...")
          return networkClient
            .totpAuthorizationRequest
            .make(
              using: .init(
                accessToken: accessToken.rawValue,
                totp: otp,
                remember: storeLocally
              )
            )
            .map(\.mfaToken)
            .flatMapResult { (token: MFAToken) -> Result<Void, TheErrorLegacy> in
              withSessionState { sessionState in
                guard sessionState?.account == account
                else {
                  diagnostics.diagnosticLog("...invalid account for mfa auth!")
                  return .failure(.sessionClosed())
                }
                if storeLocally {
                  return
                    accountDataStore
                    .storeAccountMFAToken(account.localID, token)
                    .map {
                      sessionState?.mfaToken = token
                    }
                }
                else {
                  sessionState?.mfaToken = token
                  return .success
                }
              }
            }
            .eraseToAnyPublisher()

        case let .yubikeyOTP(otp):
          diagnostics.diagnosticLog("...verifying yubikey otp...")
          return networkClient
            .yubikeyAuthorizationRequest
            .make(
              using: .init(
                accessToken: accessToken.rawValue,
                otp: otp,
                remember: storeLocally
              )
            )
            .map(\.mfaToken)
            .flatMapResult { (token: MFAToken) -> Result<Void, TheErrorLegacy> in
              withSessionState { sessionState in
                guard sessionState?.account == account
                else {
                  diagnostics.diagnosticLog("...invalid account for mfa auth!")
                  return .failure(.sessionClosed())
                }
                if storeLocally {
                  return
                    accountDataStore
                    .storeAccountMFAToken(account.localID, token)
                    .map {
                      sessionState?.mfaToken = token
                    }
                }
                else {
                  sessionState?.mfaToken = token
                  return .success
                }
              }
            }
            .eraseToAnyPublisher()
        }
      }
    }

    func refreshSessionIfNeeded(account: Account) -> AnyPublisher<Void, TheErrorLegacy> {
      diagnostics.diagnosticLog("Refreshing session...")
      return withSessionState { sessionState -> AnyPublisher<Void, TheErrorLegacy> in
        if let ongoingRequest: AnyPublisher<Void, TheErrorLegacy> = _ongoingSessionRefresh?.resultPublisher {
          return ongoingRequest
        }
        else {
          guard
            let sessionState: NetworkSessionState = sessionState
          else {
            diagnostics.diagnosticLog("...missing session for session refresh!")
            return Fail(error: .missingSessionError())
              .eraseToAnyPublisher()
          }
          guard sessionState.account == account
          else {
            diagnostics.diagnosticLog("...invalid account for session refresh!")
            return Fail(error: .sessionClosed())
              .eraseToAnyPublisher()
          }
          // we are giving the token 5 second leeway to avoid making network requests
          // with a token that is about to expire since it might result in unauthorized response
          guard sessionState.accessToken?.isExpired(timestamp: time.timestamp(), leeway: 5) ?? true
          else {
            diagnostics.diagnosticLog("... session refresh not required, reusing current session!")
            return Just(Void())  // if current access token is valid there is no need to refresh
              .setFailureType(to: TheErrorLegacy.self)
              .eraseToAnyPublisher()
          }
          guard let refreshToken: NetworkSessionState.RefreshToken = sessionState.refreshToken
          else {
            diagnostics.diagnosticLog("...missing refresh token for session refresh!")
            return Fail(error: .missingSessionError())
              .eraseToAnyPublisher()
          }

          let sessionRefreshSubject: PassthroughSubject<Void, TheErrorLegacy> = .init()

          let sessionRefreshCancellable: AnyCancellable =
            fetchServerPublicRSAKey(domain: account.domain)
            .map { (serverPublicRSAKey: PEMRSAPublicKey) -> AnyPublisher<Void, TheErrorLegacy> in
              diagnostics.diagnosticLog("...requesting token refresh...")
              return networkClient
                .refreshSessionRequest
                .make(
                  using: .init(
                    domain: account.domain,
                    userID: sessionState.account.userID.rawValue,
                    refreshToken: refreshToken.rawValue,
                    mfaToken: sessionState.mfaToken?.rawValue
                  )
                )
                .flatMapResult { (response: RefreshSessionResponse) -> Result<Void, TheErrorLegacy> in
                  let accessToken: JWT
                  switch JWT.from(rawValue: response.accessToken) {
                  case let .success(jwt):
                    accessToken = jwt

                  case let .failure(error):
                    diagnostics.diagnosticLog("...jwt access token decoding failed!")
                    return .failure(error)
                  }

                  guard
                    let signature: Data = accessToken.signature.base64DecodeFromURLEncoded(),
                    let signedData: Data = accessToken.signedPayload.data(using: .utf8)
                  else {
                    diagnostics.diagnosticLog("...jwt access token verification not possible!")
                    return .failure(.signInError())
                  }

                  switch signatureVerification.verify(signedData, signature, serverPublicRSAKey) {
                  case .success:
                    diagnostics.diagnosticLog("...jwt access token verification succeeded...")
                    return withSessionState { sessionState in
                      guard sessionState?.account == account
                      else {
                        diagnostics.diagnosticLog("...session refresh failed due to account switch!")
                        return .failure(.sessionClosed())
                      }
                      sessionState?.accessToken = accessToken
                      sessionState?.refreshToken = .init(rawValue: response.refreshToken)
                      diagnostics.diagnosticLog("...session refresh succeeded!")
                      return .success
                    }
                  case let .failure(error):
                    diagnostics.diagnosticLog("...jwt access token verification failed!")
                    return .failure(error)
                  }
                }
                .eraseToAnyPublisher()
            }
            .switchToLatest()
            .subscribe(sessionRefreshSubject)

          let sessionRefreshResultPublisher: AnyPublisher<Void, TheErrorLegacy> =
            sessionRefreshSubject
            .handleErrors(
              ([.canceled], handler: { _ in /* NOP */ true }),
              defaultHandler: { _ in
                withSessionState { sessionTokens in
                  sessionTokens = nil  // close session if refresh fails, it will require to sign in again
                }
              }
            )
            .handleEvents(
              receiveCancel: {
                // When we cancel session refresh we have to
                // cancel internal publisher as well
                sessionRefreshCancellable.cancel()
                diagnostics.diagnosticLog("...background session refresh canceled!")
              }
            )
            .handleEnd({ ending in
              ongoingSessionRefresh = nil
              guard case .failed = ending else { return }
              withSessionState { sessionState in
                sessionState?.refreshToken = nil
              }
            })
            .share()
            .eraseToAnyPublisher()

          _ongoingSessionRefresh = (
            resultPublisher: sessionRefreshResultPublisher,
            cancellable: sessionRefreshCancellable
          )

          return sessionRefreshResultPublisher

        }
      }
    }

    func sessionRefreshAvailable(_ account: Account) -> Bool {
      withSessionState { sessionState in
        sessionState?.account == account
          && sessionState?.refreshToken != nil
      }
    }

    func closeSession() -> AnyPublisher<Void, TheErrorLegacy> {
      withSessionState { sessionState -> AnyPublisher<Void, TheErrorLegacy> in
        if let domain: URLString = sessionState?.account.domain,
          let refreshToken: NetworkSessionState.RefreshToken = sessionState?.refreshToken
        {
          sessionState = nil
          return networkClient
            .signOutRequest
            .make(
              using: SignOutRequestVariable(
                domain: domain,
                refreshToken: refreshToken.rawValue
              )
            )
            .eraseToAnyPublisher()
        }
        else {
          sessionState = nil
          return Fail<Void, TheErrorLegacy>(
            error: .missingSessionError()
              .appending(
                logMessage: "Sign out attempt failed without active session"
              )
          )
          .eraseToAnyPublisher()
        }
      }
    }

    return Self(
      createSession: createSession(account:armoredPrivateKey:passphrase:),
      createMFAToken: createMFAToken(account:authorization:storeLocally:),
      sessionRefreshAvailable: sessionRefreshAvailable,
      refreshSessionIfNeeded: refreshSessionIfNeeded,
      closeSession: closeSession
    )
  }
}

#if DEBUG
extension NetworkSession {

  internal static var placeholder: Self {
    Self(
      createSession: unimplemented("You have to provide mocks for used methods"),
      createMFAToken: unimplemented("You have to provide mocks for used methods"),
      sessionRefreshAvailable: unimplemented("You have to provide mocks for used methods"),
      refreshSessionIfNeeded: unimplemented("You have to provide mocks for used methods"),
      closeSession: unimplemented("You have to provide mocks for used methods")
    )
  }
}
#endif
