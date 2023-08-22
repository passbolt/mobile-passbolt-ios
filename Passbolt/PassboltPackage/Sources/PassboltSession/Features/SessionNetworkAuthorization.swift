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

extension SessionNetworkAuthorization: LoadableFeature {

  #if DEBUG
  nonisolated internal static var placeholder: Self {
    Self(
      createSessionTokens: unimplemented2(),
      refreshSessionTokens: unimplemented3(),
      invalidateSessionTokens: unimplemented2()
    )
  }
  #endif
}

// MARK: - Implementation

extension SessionNetworkAuthorization {

  @MainActor fileprivate static func load(
    features: Features
  ) throws -> Self {

    let accountData: AccountsDataStore = try features.instance()
    let time: OSTime = features.instance()
    let pgp: PGP = features.instance()
    let uuidGenerator: UUIDGenerator = features.instance()
    let signatureVerification: SignatureVerification = features.instance()
    let serverPGPPublicKeyFetchNetworkOperation: ServerPGPPublicKeyFetchNetworkOperation = try features.instance()
    let serverRSAPublicKeyFetchNetworkOperation: ServerRSAPublicKeyFetchNetworkOperation = try features.instance()
    let sessionCreateNetworkOperation: SessionCreateNetworkOperation = try features.instance()
    let sessionRefreshNetworkOperation: SessionRefreshNetworkOperation = try features.instance()
    let sessionCloseNetworkOperation: SessionCloseNetworkOperation = try features.instance()

    let jsonEncoder: JSONEncoder = .init()
    let jsonDecoder: JSONDecoder = .init()

    @Sendable nonisolated func fetchServerPublicPGPKeyAndTimeDiff(
      for account: Account
    ) async throws -> (ArmoredPGPPublicKey, Seconds) {
      Diagnostics.logger.info("...fetching server public PGP key...")

      let localTimestampBefore: Timestamp = time.timestamp()
      let response: ServerPGPPublicKeyFetchNetworkOperationResult = try await serverPGPPublicKeyFetchNetworkOperation(
        .init(domain: account.domain)
      )
      let localTimestampAfter: Timestamp = time.timestamp()
      let executionTime: Seconds = .init(rawValue: localTimestampAfter.rawValue - localTimestampBefore.rawValue)
      Diagnostics.logger.info("Local timestamp: \(localTimestampAfter.rawValue, privacy: .public)")
      Diagnostics.logger.info("Server timestamp: \(response.serverTime.rawValue, privacy: .public)")
      // this is not a very precise time synchronization,
      // but it is good enough to solve the most of the timing issues
      // with PGP we encountered which are caused by client and server being out of sync
      let timeDiff: Seconds = .init(rawValue: response.serverTime.rawValue - time.timestamp().rawValue) - executionTime

      guard timeDiff <= 10 && timeDiff >= -10
      else {
        throw
          ServerTimeOutOfSync
          .error(
            "Time difference between client and server is bigger than 10 seconds!",
            serverURL: account.domain
          )
      }
      Diagnostics.logger.info("Using time diff for session: \(timeDiff, privacy: .public)")

      let publicKey: ArmoredPGPPublicKey = .init(rawValue: response.keyData)

      try verifyServerPublicPGPKey(
        publicKey,
        for: account
      )

      return (publicKey, timeDiff)
    }

    @Sendable nonisolated func verifyServerPublicPGPKey(
      _ publicKey: ArmoredPGPPublicKey,
      for account: Account
    ) throws {
      Diagnostics.logger.info("...verifying server public PGP key...")

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
      Diagnostics.logger.info("...fetching server public RSA key...")

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
      challengeExpiration: Int64
    ) async throws -> ArmoredPGPMessage {
      struct Challenge: Encodable {

        var version: String
        var token: String
        var domain: String
        var expiration: Int64

        private enum CodingKeys: String, CodingKey {

          case version = "version"
          case token = "verify_token"
          case domain = "domain"
          case expiration = "verify_token_expiry"
        }
      }

      Diagnostics.logger.info("...preparing authorization challenge...")
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

        let encryptedAndSignedChallenge: String =
          try pgp.encryptAndSign(
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
      challengeExpiration: Int64
    ) throws -> (
      accessToken: SessionAccessToken,
      refreshToken: SessionRefreshToken,
      mfaProviders: Array<SessionMFAProvider>
    ) {
      struct Tokens: Decodable, Equatable {

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
          try pgp
          .decryptAndVerify(
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

      async let (serverPublicPGPKey, serverTimeDiff): (ArmoredPGPPublicKey, Seconds) =
        fetchServerPublicPGPKeyAndTimeDiff(for: authorizationData.account)
      async let serverPublicRSAKey: PEMRSAPublicKey = fetchServerPublicRSAKey(for: authorizationData.account)

      let timeDiff: Seconds = try await serverTimeDiff

      pgp.setTimeOffset(timeDiff)

      // 120s is verification token's lifetime
      let challengeExpiration: Timestamp = time.timestamp() + (timeDiff + 120)

      let challenge = try await prepareEncryptedChallenge(
        account: authorizationData.account,
        passphrase: authorizationData.passphrase,
        accountPrivateKey: authorizationData.privateKey,
        serverPublicPGPKey: serverPublicPGPKey,
        verificationToken: verificationToken,
        challengeExpiration: challengeExpiration.rawValue
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
          challengeExpiration: challengeExpiration.rawValue
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

extension FeaturesRegistry {

  internal mutating func usePassboltSessionNetworkAuthorization() {
    self.use(
      .disposable(
        SessionNetworkAuthorization.self,
        load: SessionNetworkAuthorization
          .load(features:)
      )
    )
  }
}
