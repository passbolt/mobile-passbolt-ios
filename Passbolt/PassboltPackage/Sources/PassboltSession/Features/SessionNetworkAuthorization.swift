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

import struct Foundation.Data
import class Foundation.JSONDecoder
import class Foundation.JSONEncoder

// MARK: - Interface

internal struct SessionNetworkAuthorization {

  internal var createSessionTokens:
    @Sendable (
      _ authorizationData: AuthorizationData,
      _ mfaToken: SessionMFAToken?
    ) async throws -> (
      tokens: SessionTokens,
      requiredMFAProviders: Array<SessionMFAProvider>
    )

  internal var refreshSessionTokens:
    @Sendable (
      _ authorizationData: AuthorizationData,
      _ refreshToken: SessionRefreshToken,
      _ mfaToken: SessionMFAToken?
    ) async throws -> SessionTokens

  internal var invalidateSessionTokens:
    @Sendable (
      _ account: Account,
      _ refreshToken: SessionRefreshToken
    ) async throws -> Void
}

extension SessionNetworkAuthorization: LoadableContextlessFeature {

  #if DEBUG
  nonisolated internal static var placeholder: Self {
    Self(
      createSessionTokens: unimplemented(),
      refreshSessionTokens: unimplemented(),
      invalidateSessionTokens: unimplemented()
    )
  }
  #endif
}

// MARK: - Implementation

extension SessionNetworkAuthorization {

  @MainActor fileprivate static func load(
    features: FeatureFactory
  ) async throws -> Self {
    unowned let features: FeatureFactory = features

    let diagnostics: OSDiagnostics = features.instance()
    let accountData: AccountsDataStore = try await features.instance()
    let time: OSTime = features.instance()
    let pgp: PGP = features.instance()
    let uuidGenerator: UUIDGenerator = features.instance()
    let signatureVerification: SignatureVerification = features.instance()
    let serverPGPPublicKeyFetchNetworkOperation: ServerPGPPublicKeyFetchNetworkOperation = try await features.instance()
    let serverRSAPublicKeyFetchNetworkOperation: ServerRSAPublicKeyFetchNetworkOperation = try await features.instance()
    let sessionCreateNetworkOperation: SessionCreateNetworkOperation = try await features.instance()
    let sessionRefreshNetworkOperation: SessionRefreshNetworkOperation = try await features.instance()
    let sessionCloseNetworkOperation: SessionCloseNetworkOperation = try await features.instance()

    let jsonEncoder: JSONEncoder = .init()
    let jsonDecoder: JSONDecoder = .init()

    @Sendable nonisolated func fetchServerPublicPGPKey(
      for account: Account
    ) async throws -> ArmoredPGPPublicKey {
      diagnostics
        .log(diagnostic: "...fetching server public PGP key...")

      let publicKey: ArmoredPGPPublicKey = try await .init(
        rawValue: serverPGPPublicKeyFetchNetworkOperation(.init(domain: account.domain))
          .keyData
      )

      try verifyServerPublicPGPKey(
        publicKey,
        for: account
      )

      return publicKey
    }

    @Sendable nonisolated func verifyServerPublicPGPKey(
      _ publicKey: ArmoredPGPPublicKey,
      for account: Account
    ) throws {
      diagnostics
        .log(diagnostic: "...verifying server public PGP key...")

      let serverFingerprint: Fingerprint
      do {
        serverFingerprint =
          try pgp
          .extractFingerprint(publicKey)
          .get()
      }
      catch {
        throw
          ServerPGPFingeprintInvalid
          .error(
            account: account,
            fingerprint: .none
          )
          .recording(error, for: "underlyingError")
      }

      if let storedServerFingerprint: Fingerprint = try accountData.loadServerFingerprint(account.localID) {
        let keysMatch: Bool =
          try pgp
          .verifyPublicKeyFingerprint(
            publicKey,
            storedServerFingerprint
          )
          .get()

        if keysMatch {
          return Void()
        }
        else {
          throw
            ServerPGPFingeprintInvalid
            .error(
              account: account,
              fingerprint: serverFingerprint
            )
        }
      }
      else {
        try accountData
          .storeServerFingerprint(
            account.localID,
            serverFingerprint
          )
      }
    }

    @Sendable nonisolated func fetchServerPublicRSAKey(
      for account: Account
    ) async throws -> PEMRSAPublicKey {
      diagnostics
        .log(diagnostic: "...fetching server public RSA key...")

      return PEMRSAPublicKey(
        rawValue: try await serverRSAPublicKeyFetchNetworkOperation(.init(domain: account.domain))
          .keyData
      )
    }

    @Sendable nonisolated func prepareEncryptedChallenge(
      account: Account,
      passphrase: Passphrase,
      accountPrivateKey: ArmoredPGPPrivateKey,
      serverPublicPGPKey: ArmoredPGPPublicKey,
      verificationToken: String,
      challengeExpiration: Int
    ) async throws -> ArmoredPGPMessage {
      struct Challenge: Encodable {

        var version: String
        var token: String
        var domain: String
        var expiration: Int

        private enum CodingKeys: String, CodingKey {

          case version = "version"
          case token = "verify_token"
          case domain = "domain"
          case expiration = "verify_token_expiry"
        }
      }

      diagnostics
        .log(diagnostic: "...preparing authorization challenge...")
      do {
        let challengeData: Data =
          try jsonEncoder
          .encode(
            Challenge(
              version: "1.0.0",  // Protocol version 1.0.0
              token: verificationToken,
              domain: account.domain.rawValue,
              expiration: challengeExpiration
            )
          )

        guard let encodedChallenge: String = .init(bytes: challengeData, encoding: .utf8)
        else {
          throw
            SessionAuthorizationFailure
            .error(
              "Failed to encode sign in challenge to string",
              account: account
            )
        }

        let encryptedAndSignedChallenge: String = try pgp.encryptAndSign(
          encodedChallenge,
          passphrase,
          accountPrivateKey,
          serverPublicPGPKey
        )
        .get()

        return ArmoredPGPMessage(
          rawValue: encryptedAndSignedChallenge
        )
      }
      catch {
        throw
          SessionAuthorizationFailure
          .error(
            "Failed to prepare sign in challenge",
            account: account
          )
          .recording(error, for: "underlyingError")
      }
    }

    @Sendable nonisolated func decodeEncryptedResponse(
      account: Account,
      passphrase: Passphrase,
      accountPrivateKey: ArmoredPGPPrivateKey,
      serverPublicRSAKey: PEMRSAPublicKey,
      serverPublicPGPKey: ArmoredPGPPublicKey,
      encryptedResponse: ArmoredPGPMessage,
      verificationToken: String,
      challengeExpiration: Int
    ) throws -> (
      accessToken: SessionAccessToken,
      refreshToken: SessionRefreshToken,
      mfaProviders: Array<SessionMFAProvider>
    ) {
      struct Tokens: Codable, Equatable {

        var version: String
        var domain: String
        var verificationToken: String
        var accessToken: String
        var refreshToken: String
        var mfaProviders: Array<SessionMFAProvider>?

        private enum CodingKeys: String, CodingKey {

          case version = "version"
          case domain = "domain"
          case verificationToken = "verify_token"
          case accessToken = "access_token"
          case refreshToken = "refresh_token"
          case mfaProviders = "providers"
        }
      }

      let tokens: Tokens
      do {
        let decryptedPayloadData: Data =
          try pgp.decryptAndVerify(
            encryptedResponse.rawValue,
            passphrase,
            accountPrivateKey,
            serverPublicPGPKey
          )
          .get()
          .data(using: .utf8) ?? Data()

        tokens =
          try jsonDecoder
          .decode(
            Tokens.self,
            from: decryptedPayloadData
          )
      }
      catch {
        throw
          SessionAuthorizationFailure
          .error(
            "Failed to decrypt sign in response",
            account: account
          )
          .recording(error, for: "underlyingError")
      }

      guard
        verificationToken == tokens.verificationToken,
        challengeExpiration > time.timestamp().rawValue
      else {
        throw
          SessionAuthorizationFailure
          .error(
            "Sign in response verification failed",
            account: account
          )
      }

      let accessToken: SessionAccessToken
      do {
        accessToken =
          try JWT
          .from(rawValue: tokens.accessToken)
          .get()
      }
      catch {
        throw
          SessionAuthorizationFailure
          .error(
            "Failed to decode access token",
            account: account
          )
          .recording(error, for: "underlyingError")
      }

      guard
        let signature: Data = accessToken.signature.rawValue.base64DecodeFromURLEncoded(),
        let signedData: Data = accessToken.signedPayload.data(using: .utf8)
      else {
        throw
          SessionAuthorizationFailure
          .error(
            "Failed to prepare access token signature verification",
            account: account
          )
      }

      do {
        try signatureVerification
          .verify(
            signedData,
            signature,
            serverPublicRSAKey
          )
          .get()
      }
      catch {
        throw
          SessionAuthorizationFailure
          .error(
            "Access token signature verification failed",
            account: account
          )
          .recording(error, for: "underlyingError")
      }

      return (
        accessToken: accessToken,
        refreshToken: .init(
          rawValue: tokens.refreshToken
        ),
        mfaProviders: tokens.mfaProviders ?? .init()
      )
    }

    @Sendable nonisolated func createSessionTokens(
      _ authorizationData: AuthorizationData,
      mfaToken: SessionMFAToken?
    ) async throws -> (
      tokens: SessionTokens,
      requiredMFAProviders: Array<SessionMFAProvider>
    ) {
      let verificationToken: String = uuidGenerator.uuid()
      // 120s is verification token's lifetime
      let challengeExpiration: Int = time.timestamp().rawValue + 120

      async let serverPublicPGPKey: ArmoredPGPPublicKey = fetchServerPublicPGPKey(for: authorizationData.account)
      async let serverPublicRSAKey: PEMRSAPublicKey = fetchServerPublicRSAKey(for: authorizationData.account)

      let challenge = try await prepareEncryptedChallenge(
        account: authorizationData.account,
        passphrase: authorizationData.passphrase,
        accountPrivateKey: authorizationData.privateKey,
        serverPublicPGPKey: serverPublicPGPKey,
        verificationToken: verificationToken,
        challengeExpiration: challengeExpiration
      )

      let sessionCreationResult: SessionCreateNetworkOperationResult = try await sessionCreateNetworkOperation(
        .init(
          domain: authorizationData.account.domain,
          userID: authorizationData.account.userID,
          challenge: challenge,
          mfaToken: mfaToken
        )
      )

      let mfaTokenIsValid: Bool = sessionCreationResult.mfaTokenIsValid

      let (
        accessToken,
        refreshToken,
        mfaProviders
      ):
        (
          SessionAccessToken,
          SessionRefreshToken,
          Array<SessionMFAProvider>
        ) = try await decodeEncryptedResponse(
          account: authorizationData.account,
          passphrase: authorizationData.passphrase,
          accountPrivateKey: authorizationData.privateKey,
          serverPublicRSAKey: serverPublicRSAKey,
          serverPublicPGPKey: serverPublicPGPKey,
          encryptedResponse: sessionCreationResult.challenge,
          verificationToken: verificationToken,
          challengeExpiration: challengeExpiration
        )

      return (
        tokens: (
          accessToken: accessToken,
          refreshToken: refreshToken
        ),
        requiredMFAProviders: mfaTokenIsValid
          ? .init()
          : mfaProviders
      )
    }

    @Sendable nonisolated func refreshSessionTokens(
      _ authorizationData: AuthorizationData,
      refreshToken: SessionRefreshToken,
      mfaToken: SessionMFAToken?
    ) async throws -> SessionTokens {
      let sessionRefreshResult: SessionRefreshNetworkOperationResult = try await sessionRefreshNetworkOperation(
        .init(
          domain: authorizationData.account.domain,
          userID: authorizationData.account.userID,
          refreshToken: refreshToken,
          mfaToken: mfaToken
        )
      )

      return (
        accessToken: sessionRefreshResult.accessToken,
        refreshToken: sessionRefreshResult.refreshToken
      )
    }

    @Sendable nonisolated func invalidateSessionTokens(
      _ account: Account,
      _ refreshToken: SessionRefreshToken
    ) async throws {
      try await sessionCloseNetworkOperation(
        .init(
          domain: account.domain,
          refreshToken: refreshToken
        )
      )
    }

    return Self(
      createSessionTokens: createSessionTokens,
      refreshSessionTokens: refreshSessionTokens,
      invalidateSessionTokens: invalidateSessionTokens(_:_:)
    )
  }
}

extension FeatureFactory {

  internal func usePassboltSessionNetworkAuthorization() {
    self.use(
      .disposable(
        SessionNetworkAuthorization.self,
        load: SessionNetworkAuthorization
          .load(features:)
      )
    )
  }
}
