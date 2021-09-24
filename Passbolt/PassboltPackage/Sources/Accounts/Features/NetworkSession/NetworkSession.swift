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

import Commons
import Crypto
import Features
import NetworkClient

import struct Foundation.Data
import class Foundation.JSONDecoder
import class Foundation.JSONEncoder

internal struct NetworkSession {

  // returns nonempty Array<MFAProvider> if MFA required
  // otherwise empty (even if MFA is enabled but current token was valid)
  internal var createSession: (
      _ account: Account,
      _ domain: String,
      _ armoredKey: ArmoredPGPPrivateKey,
      _ passphrase: Passphrase
    ) -> AnyPublisher<Array<MFAProvider>, TheError>

  internal var createMFAToken: (
    _ account: Account,
    _ authorization: AccountSession.MFAAuthorizationMethod,
    _ storeLocally: Bool
  ) -> AnyPublisher<Void, TheError>

  internal var refreshSession: () -> AnyPublisher<NetworkSessionTokens, TheError>
  internal var closeSession: () -> AnyPublisher<Void, TheError>
}

extension NetworkSession {

  fileprivate typealias ServerPublicPGPKeyWithFingerprint = (pgp: ArmoredPGPPublicKey, fingerprint: Fingerprint)
  fileprivate typealias ServerPublicKeys = (pgp: ArmoredPGPPublicKey, pgpFingerprint: Fingerprint, rsa: ArmoredRSAPublicKey)
  fileprivate typealias ServerPublicKeysWithSignInChallenge = (
    serverPublicKeys: ServerPublicKeys, signInChallenge: ArmoredPGPMessage
  )
  fileprivate typealias ServerPublicKeysWithSignInTokens = (serverPublicKeys: ServerPublicKeys, signInTokens: Tokens)
  fileprivate typealias SignInTokensWithMFAStatus = (signInTokens: Tokens, mfaTokenIsValid: Bool)
  fileprivate typealias ServerPublicKeysWithSignInTokensAndMFAStatus = (serverPublicKeys: ServerPublicKeys, signInTokens: Tokens, mfaTokenIsValid: Bool)
  fileprivate typealias SessionTokensWithMFAProviders = (tokens: NetworkSessionTokens, mfaProviders: Array<MFAProvider>)
}

extension NetworkSession: Feature {

  internal static func load(
    in environment: Environment,
    using features: FeatureFactory,
    cancellables: Cancellables
  ) -> Self {
    let uuidGenerator: UUIDGenerator = environment.uuidGenerator
    let time: Time = environment.time
    let pgp: PGP = environment.pgp
    let signatureVerification: SignatureVerfication = environment.signatureVerfication

    let accountDataStore: AccountsDataStore = features.instance()
    let fingerprintStorage: FingerprintStorage = features.instance()
    let networkClient: NetworkClient = features.instance()

    let sessionTokensSubject: CurrentValueSubject<NetworkSessionTokens?, Never> = .init(nil)

    let encoder: JSONEncoder = .init()
    let decoder: JSONDecoder = .init()

    networkClient
      .setTokensPublisher(
        sessionTokensSubject
          .map { (sessionTokens: NetworkSessionTokens?) -> NetworkClient.Tokens? in
            sessionTokens
              .map { sessionTokens in
                NetworkClient.Tokens(
                  accessToken: sessionTokens.accessToken.rawValue,
                  isExpired: {
                    sessionTokens
                      .accessToken
                      .isExpired(timestamp: time.timestamp())
                  },
                  refreshToken: sessionTokens.refreshToken.rawValue,
                  mfaToken: sessionTokens.mfaToken?.rawValue
                )
              }
          }
          .eraseToAnyPublisher()
      )

    func fetchServerPublicPGPKey() -> AnyPublisher<ServerPublicPGPKeyWithFingerprint, TheError> {
      networkClient
        .serverPGPPublicKeyRequest
        .make()
        .map { response in
          #warning("Fingerprint should be extracted from the public key")
          return (
            pgp: ArmoredPGPPublicKey(rawValue: response.body.keyData),
            fingerprint: .init(rawValue: response.body.fingerprint)
          )
        }
        .eraseToAnyPublisher()
    }

    func fetchServerPublicRSAKey() -> AnyPublisher<ArmoredRSAPublicKey, TheError> {
      networkClient
        .serverRSAPublicKeyRequest
        .make()
        .map { response in
          ArmoredRSAPublicKey(rawValue: response.body.keyData)
        }
        .eraseToAnyPublisher()
    }

    func fetchServerPublicKeys(accountID: Account.LocalID) -> AnyPublisher<ServerPublicKeys, TheError> {
      Publishers.Zip(
        fetchServerPublicPGPKey(),
        fetchServerPublicRSAKey()
      )
        .map { (pgp: ServerPublicPGPKeyWithFingerprint, rsa: ArmoredRSAPublicKey) -> AnyPublisher<ServerPublicKeys, TheError> in
          var existingFingerprint: Fingerprint? = nil
          
          switch fingerprintStorage.loadServerFingerprint(accountID) {
          case let .success(fingerprint):
            existingFingerprint = fingerprint
            
          case let .failure(error):
            return Fail(
              error: .invalidServerFingerprint(
                accountID: accountID,
                updatedFingerprint: pgp.fingerprint
              )
            )
            .eraseToAnyPublisher()
          }
          
          if let fingerprint = existingFingerprint {
            if fingerprint == pgp.fingerprint {
              return Just(
                ServerPublicKeys(pgp: pgp.pgp, pgpFingerprint: pgp.fingerprint, rsa: rsa)
              )
                .setFailureType(to: TheError.self)
                .eraseToAnyPublisher()
            }
            else {
              return Fail(
                error: .invalidServerFingerprint(
                  accountID: accountID,
                  updatedFingerprint: pgp.fingerprint
                )
              )
                .eraseToAnyPublisher()
            }
          } else {
            switch fingerprintStorage.storeServerFingerprint(accountID, pgp.fingerprint) {
            case let .failure(error):
              return Fail(error: error)
                .eraseToAnyPublisher()
            case _:
              break
            }
            return Just(
              ServerPublicKeys(pgp: pgp.pgp, pgpFingerprint: pgp.fingerprint, rsa: rsa)
            )
              .setFailureType(to: TheError.self)
              .eraseToAnyPublisher()
          }
        }
        .switchToLatest()
        .eraseToAnyPublisher()
    }

    func prepareSignInChallenge(
      domain: String,
      verificationToken: String,
      challengeExpiration: Int,
      serverPublicPGPKey: ArmoredPGPPublicKey,
      armoredPrivateKey: ArmoredPGPPrivateKey,
      passphrase: Passphrase
    ) -> AnyPublisher<ArmoredPGPMessage, TheError> {
      let challenge: SignInRequestChallenge = .init(
        version: "1.0.0",  // Protocol version 1.0.0
        token: verificationToken,
        domain: domain,
        expiration: challengeExpiration
      )

      let encodedChallenge: String
      do {
        let challengeData: Data = try encoder.encode(challenge)

        guard let encoded: String = .init(bytes: challengeData, encoding: .utf8)
        else {
          return Fail<ArmoredPGPMessage, TheError>(
            error: .signInError()
              .appending(context: "Failed to encode challenge to string")
          )
          .eraseToAnyPublisher()
        }
        encodedChallenge = encoded
      }
      catch {
        return Fail<ArmoredPGPMessage, TheError>(
          error: .signInError(underlyingError: error)
            .appending(context: "Failed to encode challenge")
        )
        .eraseToAnyPublisher()
      }

      let encryptAndSignResult: Result<String, TheError> = pgp.encryptAndSign(
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
        return Fail<ArmoredPGPMessage, TheError>(
          error: error.appending(logMessage: "Failed to encrypt and sign challenge")
        )
        .eraseToAnyPublisher()
      }

      return Just(
        ArmoredPGPMessage(
          rawValue: encryptedAndSignedChallenge
        )
      )
      .setFailureType(to: TheError.self)
      .eraseToAnyPublisher()
    }

    func signIn(
      userID: Account.UserID,
      challenge: ArmoredPGPMessage,
      mfaToken: MFAToken?
    ) -> AnyPublisher<(challenge: String, mfaTokenIsValid: Bool), TheError> {
      return networkClient
        .signInRequest
        .make(
          using: .init(
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
    ) -> AnyPublisher<Tokens, TheError> {
      let decryptedResponsePayloadResult: Result<String, TheError> = pgp.decryptAndVerify(
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
        return Fail<Tokens, TheError>(
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
        return Fail<Tokens, TheError>.init(
          error: .signInError(underlyingError: error)
        )
        .eraseToAnyPublisher()
      }

      return Just<Tokens>(tokens)
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    }

    func signInAndDecryptVerifyResponse(
      userID: Account.UserID,
      signInChallenge: ArmoredPGPMessage,
      mfaToken: MFAToken?,
      serverPublicPGPKey: ArmoredPGPPublicKey,
      armoredPrivateKey: ArmoredPGPPrivateKey,
      passphrase: Passphrase
    ) -> AnyPublisher<SignInTokensWithMFAStatus, TheError> {
      signIn(
        userID: userID,
        challenge: signInChallenge,
        mfaToken: mfaToken
      )
      .map { (encryptedResponsePayload: String, mfaTokenIsValid) -> AnyPublisher<SignInTokensWithMFAStatus, TheError> in
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
      serverPublicRSAKey: ArmoredRSAPublicKey,
      verificationToken: String,
      challengeExpiration: Int
    ) -> AnyPublisher<SessionTokensWithMFAProviders, TheError> {
      let accessToken: JWT
      switch JWT.from(rawValue: signInTokens.accessToken) {
      case let .success(jwt):
        accessToken = jwt

      case let .failure(error):
        return Fail<SessionTokensWithMFAProviders, TheError>(
          error: error.appending(logMessage: "Failed to prepare for signature verification")
        )
        .eraseToAnyPublisher()
      }

      guard
        verificationToken == signInTokens.verificationToken,
        challengeExpiration > time.timestamp(),
        let key: Data = Data(base64Encoded: serverPublicRSAKey.stripArmoredFormat()),
        let signature: Data = accessToken.signature.base64DecodeFromURLEncoded(),
        let signedData: Data = accessToken.signedPayload.data(using: .utf8)
      else {
        return Fail<SessionTokensWithMFAProviders, TheError>(
          error: .signInError()
            .appending(logMessage: "Failed to prepare for signature verification")
        )
        .eraseToAnyPublisher()
      }

      switch signatureVerification.verify(signedData, signature, key) {
      case .success:
        return Just(
          SessionTokensWithMFAProviders(
            tokens: NetworkSessionTokens(
              accountLocalID: account.localID,
              accessToken: accessToken,
              refreshToken: NetworkSessionTokens.RefreshToken(rawValue: signInTokens.refreshToken),
              mfaToken: mfaToken
            ),
            mfaProviders: signInTokens.mfaProviders.map { mfaToken == .none ? $0 : [] } ?? []
          )
        )
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()

      case let .failure(error):
        return Fail<SessionTokensWithMFAProviders, TheError>(
          error: error.appending(logMessage: "Signature verification failed")
        )
        .eraseToAnyPublisher()
      }
    }

    func createSession(
      account: Account,
      domain: String,
      armoredPrivateKey: ArmoredPGPPrivateKey,
      passphrase: Passphrase
    ) -> AnyPublisher<Array<MFAProvider>, TheError> {
      let verificationToken: String = uuidGenerator().uuidString
      let challengeExpiration: Int  // 120s is verification token's lifetime
      = time.timestamp() + 120

      let mfaToken: MFAToken? = try? accountDataStore
        .loadAccountMFAToken(account.localID)
        .get() // we don't care about the errors here

      return fetchServerPublicKeys(accountID: account.localID)
        .map { (serverPublicKeys: ServerPublicKeys) -> AnyPublisher<ServerPublicKeysWithSignInChallenge, TheError> in
          prepareSignInChallenge(
            domain: domain,
            verificationToken: verificationToken,
            challengeExpiration: challengeExpiration,
            serverPublicPGPKey: serverPublicKeys.pgp,
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
            ServerPublicKeysWithSignInTokensAndMFAStatus, TheError
          > in
          signInAndDecryptVerifyResponse(
            userID: account.userID,
            signInChallenge: signInChallenge,
            mfaToken: mfaToken,
            serverPublicPGPKey: serverPublicKeys.pgp,
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
          (serverPublicKeys: ServerPublicKeys, signInTokens: Tokens, mfaTokenIsValid: Bool) -> AnyPublisher<SessionTokensWithMFAProviders, TheError> in
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
            _ = accountDataStore.deleteAccountMFAToken(account.localID) // ignoring result
          })
          .eraseToAnyPublisher()
        }
        .switchToLatest()
        .handleEvents(receiveOutput: { (tokens: NetworkSessionTokens, _: Array<MFAProvider>) in

          var copyTokens: NetworkSessionTokens = tokens
          copyTokens.mfaToken = mfaToken
          sessionTokensSubject.send(copyTokens)
        })
        .map { (_: NetworkSessionTokens, mfaProviders: Array<MFAProvider>) -> Array<MFAProvider> in
          mfaProviders
        }
        .eraseToAnyPublisher()
    }

    func createMFAToken(
      account: Account,
      authorization: AccountSession.MFAAuthorizationMethod,
      storeLocally: Bool
    ) -> AnyPublisher<Void, TheError> {
      switch authorization {
      case let .totp(otp):
        return networkClient
          .totpAuthorizationRequest
          .make(using: .init(totp: otp, remember: storeLocally))
          .map(\.mfaToken)
          .flatMapResult { (token: MFAToken) -> Result<Void, TheError> in
            if storeLocally {
              return accountDataStore
                .storeAccountMFAToken(account.localID, token)
                .map {
                  sessionTokensSubject.value?.mfaToken = token
                }
            } else {
              sessionTokensSubject.value?.mfaToken = token
              return .success
            }
          }
          .eraseToAnyPublisher()

      case let .yubikeyOTP(otp):
        return networkClient
          .yubikeyAuthorizationRequest
          .make(using: .init(otp: otp, remember: storeLocally))
          .map(\.mfaToken)
          .flatMapResult { (token: MFAToken) -> Result<Void, TheError> in
            if storeLocally {
              return accountDataStore
                .storeAccountMFAToken(account.localID, token)
                .map {
                  sessionTokensSubject.value?.mfaToken = token
                }
            } else {
              sessionTokensSubject.value?.mfaToken = token
              return .success
            }
          }
          .eraseToAnyPublisher()
      }
    }

    func refreshSession() -> AnyPublisher<NetworkSessionTokens, TheError> {
      #warning("TODO: [PAS-160] token refresh disabled, please always sign in")
      Commons.placeholder("TODO: to complete [PAS-160]")
    }

    func closeSession() -> AnyPublisher<Void, TheError> {
      sessionTokensSubject
        .first()
        .map { sessionTokens -> AnyPublisher<Void, TheError> in
          if let refreshToken: NetworkSessionTokens.RefreshToken = sessionTokens?.refreshToken {
            sessionTokensSubject.send(nil)
            return networkClient
              .signOutRequest
              .make(
                using: SignOutRequestVariable(
                  refreshToken: refreshToken.rawValue
                )
              )
              .eraseToAnyPublisher()
          }
          else {
            return Fail<Void, TheError>(
              error: .missingSessionError()
                .appending(
                  logMessage: "Sign out attempt failed without active session"
                )
            )
            .eraseToAnyPublisher()
          }
        }
        .switchToLatest()
        .eraseToAnyPublisher()
    }

    return Self(
      createSession: createSession(account:domain:armoredPrivateKey:passphrase:),
      createMFAToken: createMFAToken(account:authorization:storeLocally:),
      refreshSession: refreshSession,
      closeSession: closeSession
    )
  }
}

#if DEBUG
extension NetworkSession {

  internal static var placeholder: Self {
    Self(
      createSession: Commons.placeholder("You have to provide mocks for used methods"),
      createMFAToken: Commons.placeholder("You have to provide mocks for used methods"),
      refreshSession: Commons.placeholder("You have to provide mocks for used methods"),
      closeSession: Commons.placeholder("You have to provide mocks for used methods")
    )
  }
}
#endif
