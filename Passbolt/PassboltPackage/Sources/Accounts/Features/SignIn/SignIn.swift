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

public struct SignIn {

  public enum Method {
    case challenge
    case refreshToken(String)
  }

  public var signIn:
    (
      _ userID: Account.UserID,
      _ domain: String,
      _ armoredKey: ArmoredPrivateKey,
      _ passphrase: Passphrase,
      _ method: Method
    ) -> AnyPublisher<SessionTokens, TheError>
}

extension SignIn: Feature {

  public static func load(
    in environment: Environment,
    using features: FeatureFactory,
    cancellables: Cancellables
  ) -> SignIn {
    let uuidGenerator: UUIDGenerator = environment.uuidGenerator
    let time: Time = environment.time
    let pgp: PGP = environment.pgp
    let signatureVerification: SignatureVerfication = environment.signatureVerfication

    let networkClient: NetworkClient = features.instance()
    let diagnostics: Diagnostics = features.instance()

    let encoder: JSONEncoder = .init()
    let decoder: JSONDecoder = .init()

    let serverPGPPublicKey: AnyPublisher<ArmoredPublicKey, TheError> =
      networkClient.serverPGPPublicKeyRequest.make(using: ())
      .map { (response: ServerPGPPublicKeyResponse) -> ArmoredPublicKey in
        ArmoredPublicKey(rawValue: response.body.keyData)
      }
      .eraseToAnyPublisher()

    let rsaPublicKeyStep: AnyPublisher<String, TheError> =
      networkClient.serverRSAPublicKeyRequest.make(using: ())
      .map(\.body.keyData)
      .eraseToAnyPublisher()

    func prepareChallenge(
      for method: Method,
      domain: String,
      verificationToken: String,
      verificationExpiration: Int
    ) -> Result<String, TheError> {
      switch method {
      case .challenge:
        let challenge: SignInRequestChallenge = .init(
          version: "1.0.0",  // Protocol version 1.0.0
          token: verificationToken,
          domain: domain,
          expiration: verificationExpiration
        )

        do {
          let challengeData: Data = try encoder.encode(challenge)

          guard let encodedChallenge: String = .init(bytes: challengeData, encoding: .utf8) else {
            return .failure(.signInError().appending(context: "Failed to encode challenge to string"))
          }

          return .success(encodedChallenge)
        }
        catch {
          return .failure(.signInError(underlyingError: error).appending(context: "Failed to encode challenge"))
        }
      case let .refreshToken(token):
        return .success(token)
      }
    }

    func signIn(
      userID: Account.UserID,
      domain: String,
      armoredKey: ArmoredPrivateKey,
      passphrase: Passphrase,
      method: Method
    ) -> AnyPublisher<SessionTokens, TheError> {
      let verificationToken: String = uuidGenerator().uuidString
      let verificationExpiration: Int = time.timestamp() + 120  // 120s is verification token's lifetime

      let jwtStep: AnyPublisher<String, TheError> =
        serverPGPPublicKey
        .map { (serverPublicKey: ArmoredPublicKey) -> AnyPublisher<ArmoredMessage, TheError> in
          let encodedChallenge: String

          switch prepareChallenge(
            for: method,
            domain: domain,
            verificationToken: verificationToken,
            verificationExpiration: verificationExpiration
          ) {
          case let .success(challenge):
            encodedChallenge = challenge
          case let .failure(error):
            return Fail<ArmoredMessage, TheError>(
              error: .signInError(underlyingError: error).appending(logMessage: "JWT: Failed to encode challenge")
            ).eraseToAnyPublisher()
          }

          let encryptedAndSigned: String

          switch pgp.encryptAndSign(encodedChallenge, passphrase, armoredKey, serverPublicKey) {
          case let .success(result):
            encryptedAndSigned = result

          case let .failure(error):
            return Fail(error: error.appending(logMessage: "Failed to encrypt and sign"))
              .eraseToAnyPublisher()
          }

          return Just<ArmoredMessage>(.init(rawValue: encryptedAndSigned))
            .setFailureType(to: TheError.self)
            .eraseToAnyPublisher()
        }
        .switchToLatest()
        .map { (challenge: ArmoredMessage) -> AnyPublisher<SignInResponse, TheError> in
          switch method {
          case .challenge:
            return networkClient.signInRequest.make(
              using: .init(
                userID: userID.rawValue,
                challenge: challenge
              )
            )
          case let .refreshToken(token):
            return networkClient.refreshSessionRequest.make(
              using: .init(
                userID: userID.rawValue,
                refreshToken: token
              )
            )
          }
        }
        .switchToLatest()
        .map { response -> String in
          response.body.challenge
        }
        .eraseToAnyPublisher()

      let decryptedToken: AnyPublisher<Tokens, TheError> = Publishers.Zip(jwtStep, serverPGPPublicKey)
        .map { encryptedTokenPayload, publicKey -> AnyPublisher<String, TheError> in
          let decrypted: String

          switch pgp.decryptAndVerify(encryptedTokenPayload, passphrase, armoredKey, publicKey) {
          case let .success(result):
            decrypted = result

          case let .failure(error):
            return Fail<String, TheError>(
              error: error.appending(logMessage: "Unable to decrypt and verify")
            )
            .eraseToAnyPublisher()
          }

          return Just<String>(decrypted)
            .setFailureType(to: TheError.self)
            .eraseToAnyPublisher()
        }
        .switchToLatest()
        .map { token -> AnyPublisher<Tokens, TheError> in
          let tokenData: Data = token.data(using: .utf8) ?? Data()
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
        .switchToLatest()
        .eraseToAnyPublisher()

      return Publishers.Zip(rsaPublicKeyStep, decryptedToken)
        .map { (publicKey: String, decryptedToken: Tokens) -> AnyPublisher<SessionTokens, TheError> in

          let accessToken: JWT
          switch JWT.from(rawValue: decryptedToken.accessToken) {
          case let .success(jwt):
            accessToken = jwt

          case let .failure(error):
            return Fail<SessionTokens, TheError>(
              error: .signInError(underlyingError: error)
                .appending(logMessage: "Failed to prepare for signature verification")
            )
            .eraseToAnyPublisher()
          }

          guard verificationToken == decryptedToken.verificationToken,
            verificationExpiration > time.timestamp(),
            let key: Data = Data(base64Encoded: publicKey.stripArmoredFormat()),
            let signature: Data = accessToken.signature.base64DecodeFromURLEncoded(),
            let signedData: Data = accessToken.signedPayload.data(using: .utf8)
          else {
            return Fail<SessionTokens, TheError>(
              error: .signInError().appending(logMessage: "Failed to prepare for signature verification")
            )
            .eraseToAnyPublisher()
          }

          switch signatureVerification.verify(signedData, signature, key) {
          case .success:
            return Just(
              SessionTokens(accessToken: accessToken, refreshToken: decryptedToken.refreshToken)
            )
            .setFailureType(to: TheError.self)
            .eraseToAnyPublisher()

          case let .failure(error):
            return Fail<SessionTokens, TheError>(
              error: error.appending(logMessage: "Signature verification failed")
            )
            .eraseToAnyPublisher()
          }
        }
        .switchToLatest()
        .collectErrorLog(using: diagnostics)
        .eraseToAnyPublisher()
    }

    return Self(signIn: signIn)
  }
}

#if DEBUG
extension SignIn {

  public static var placeholder: SignIn {
    Self(signIn: Commons.placeholder("You have to provide mocks for used methods"))
  }
}
#endif
