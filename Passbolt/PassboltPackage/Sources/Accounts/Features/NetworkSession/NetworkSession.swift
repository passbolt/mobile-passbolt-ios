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

  internal var createSession:
    (
      _ userID: Account.UserID,
      _ domain: String,
      _ armoredKey: ArmoredPGPPrivateKey,
      _ passphrase: Passphrase
    ) -> AnyPublisher<NetworkSessionTokens, TheError>
  internal var refreshSession: () -> AnyPublisher<NetworkSessionTokens, TheError>
  internal var closeSession: () -> AnyPublisher<Void, TheError>
}

extension NetworkSession {

  fileprivate typealias ServerPublicKeys = (pgp: ArmoredPGPPublicKey, rsa: ArmoredRSAPublicKey)
  fileprivate typealias ServerPublicKeysWithSignInChallenge = (
    serverPublicKeys: ServerPublicKeys, signInChallenge: ArmoredPGPMessage
  )
  fileprivate typealias ServerPublicKeysWithSignInTokens = (serverPublicKeys: ServerPublicKeys, signInTokens: Tokens)
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
                  refreshToken: sessionTokens.refreshToken.rawValue
                )
              }
          }
          .eraseToAnyPublisher()
      )

    func fetchServerPublicPGPKey() -> AnyPublisher<ArmoredPGPPublicKey, TheError> {
      networkClient
        .serverPGPPublicKeyRequest
        .make()
        .map { response in
          ArmoredPGPPublicKey(rawValue: response.body.keyData)
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

    func fetchServerPublicKeys() -> AnyPublisher<ServerPublicKeys, TheError> {
      Publishers.Zip(
        fetchServerPublicPGPKey(),
        fetchServerPublicRSAKey()
      )
      .map { (pgp: ArmoredPGPPublicKey, rsa: ArmoredRSAPublicKey) -> ServerPublicKeys in
        #warning("TODO: [PAS-235] verify server key fingerprint")
        return ServerPublicKeys(pgp: pgp, rsa: rsa)
      }
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
          error: .signInError(underlyingError: error)
            .appending(logMessage: "Failed to encrypt and sign challenge")
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
      challenge: ArmoredPGPMessage
    ) -> AnyPublisher<String, TheError> {
      networkClient
        .signInRequest
        .make(
          using: .init(
            userID: userID.rawValue,
            challenge: challenge
          )
        )
        .map(\.body.challenge)
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
          error: .signInError(underlyingError: error)
            .appending(logMessage: "Unable to decrypt and verify response")
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
      serverPublicPGPKey: ArmoredPGPPublicKey,
      armoredPrivateKey: ArmoredPGPPrivateKey,
      passphrase: Passphrase
    ) -> AnyPublisher<Tokens, TheError> {
      signIn(
        userID: userID,
        challenge: signInChallenge
      )
      .map { (encryptedResponsePayload: String) -> AnyPublisher<Tokens, TheError> in
        decryptVerifyResponse(
          encryptedResponsePayload: encryptedResponsePayload,
          serverPublicPGPKey: serverPublicPGPKey,
          armoredPrivateKey: armoredPrivateKey,
          passphrase: passphrase
        )
        .eraseToAnyPublisher()
      }
      .switchToLatest()
      .eraseToAnyPublisher()
    }

    func decodeVerifySignInTokens(
      signInTokens: Tokens,
      serverPublicRSAKey: ArmoredRSAPublicKey,
      verificationToken: String,
      challengeExpiration: Int
    ) -> AnyPublisher<NetworkSessionTokens, TheError> {
      let accessToken: JWT
      switch JWT.from(rawValue: signInTokens.accessToken) {
      case let .success(jwt):
        accessToken = jwt

      case let .failure(error):
        return Fail<NetworkSessionTokens, TheError>(
          error: .signInError(underlyingError: error)
            .appending(logMessage: "Failed to prepare for signature verification")
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
        return Fail<NetworkSessionTokens, TheError>(
          error: .signInError()
            .appending(logMessage: "Failed to prepare for signature verification")
        )
        .eraseToAnyPublisher()
      }

      switch signatureVerification.verify(signedData, signature, key) {
      case .success:
        return Just(
          NetworkSessionTokens(
            accessToken: accessToken,
            refreshToken: NetworkSessionTokens.RefreshToken(rawValue: signInTokens.refreshToken)
          )
        )
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()

      case let .failure(error):
        return Fail<NetworkSessionTokens, TheError>(
          error: .signInError(underlyingError: error)
            .appending(logMessage: "Signature verification failed")
        )
        .eraseToAnyPublisher()
      }
    }

    func createSession(
      userID: Account.UserID,
      domain: String,
      armoredPrivateKey: ArmoredPGPPrivateKey,
      passphrase: Passphrase
    ) -> AnyPublisher<NetworkSessionTokens, TheError> {
      let verificationToken: String = uuidGenerator().uuidString
      let challengeExpiration: Int  // 120s is verification token's lifetime
      = time.timestamp() + 120

      return fetchServerPublicKeys()
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
            ServerPublicKeysWithSignInTokens, TheError
          > in
          signInAndDecryptVerifyResponse(
            userID: userID,
            signInChallenge: signInChallenge,
            serverPublicPGPKey: serverPublicKeys.pgp,
            armoredPrivateKey: armoredPrivateKey,
            passphrase: passphrase
          )
          .map { (tokens: Tokens) -> ServerPublicKeysWithSignInTokens in
            ServerPublicKeysWithSignInTokens(
              serverPublicKeys: serverPublicKeys,
              signInTokens: tokens
            )
          }
          .eraseToAnyPublisher()
        }
        .switchToLatest()
        .map {
          (serverPublicKeys: ServerPublicKeys, signInTokens: Tokens) -> AnyPublisher<NetworkSessionTokens, TheError> in
          decodeVerifySignInTokens(
            signInTokens: signInTokens,
            serverPublicRSAKey: serverPublicKeys.rsa,
            verificationToken: verificationToken,
            challengeExpiration: challengeExpiration
          )
        }
        .switchToLatest()
        .handleEvents(receiveOutput: { (tokens: NetworkSessionTokens) in
          sessionTokensSubject.send(tokens)
        })
        .eraseToAnyPublisher()
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
      createSession: createSession(userID:domain:armoredPrivateKey:passphrase:),
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
      refreshSession: Commons.placeholder("You have to provide mocks for used methods"),
      closeSession: Commons.placeholder("You have to provide mocks for used methods")
    )
  }
}
#endif
