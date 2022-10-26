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

import TestExtensions

@testable import PassboltSession

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class SessionNetworkAuthorizationTests: LoadableFeatureTestCase<SessionNetworkAuthorization> {

  override class var testedImplementationRegister: (FeatureFactory) -> @MainActor () -> Void {
    FeatureFactory.usePassboltSessionNetworkAuthorization
  }

  override func prepare() throws {
    use(AccountsDataStore.placeholder)
    use(ServerPGPPublicKeyFetchNetworkOperation.placeholder)
    use(ServerRSAPublicKeyFetchNetworkOperation.placeholder)
    use(SessionCreateNetworkOperation.placeholder)
    use(SessionRefreshNetworkOperation.placeholder)
    use(SessionCloseNetworkOperation.placeholder)
    use(OSTime.placeholder)
    patch(
      environment: \.pgp,
      with: .placeholder
    )
    patch(
      environment: \.signatureVerfication,
      with: .placeholder
    )
    patch(
      environment: \.uuidGenerator.uuid,
      with: always(.test)
    )
  }

  func test_createSessionTokens_throws_whenFetchingServerPGPKeyThrows() {
    patch(
      \OSTime.timestamp,
      with: always(0)
    )
    patch(
      \ServerRSAPublicKeyFetchNetworkOperation.execute,
      with: always(.init(keyData: "key"))
    )
    patch(
      \ServerPGPPublicKeyFetchNetworkOperation.execute,
      with: alwaysThrow(MockIssue.error())
    )
    withTestedInstanceThrows(
      MockIssue.self
    ) { (testedInstance: SessionNetworkAuthorization) in
      try await testedInstance.createSessionTokens(
        (
          account: .mock_ada,
          passphrase: "passphrase",
          privateKey: "private_key"
        ),
        .none
      )
    }
  }

  func test_createSessionTokens_throws_whenExtractingServerPGPKeyFingerprintFails() {
    patch(
      \OSTime.timestamp,
      with: always(0)
    )
    patch(
      \ServerRSAPublicKeyFetchNetworkOperation.execute,
      with: always(.init(keyData: "key"))
    )
    patch(
      \ServerPGPPublicKeyFetchNetworkOperation.execute,
      with: always(.init(keyData: "key"))
    )
    patch(
      environment: \.pgp.extractFingerprint,
      with: always(.failure(MockIssue.error()))
    )

    withTestedInstanceThrows(
      ServerPGPFingeprintInvalid.self
    ) { (testedInstance: SessionNetworkAuthorization) in
      try await testedInstance.createSessionTokens(
        (
          account: .mock_ada,
          passphrase: "passphrase",
          privateKey: "private_key"
        ),
        .none
      )
    }
  }

  func test_createSessionTokens_throws_whenValidatingServerPGPKeyFingerprintThrows() {
    patch(
      \OSTime.timestamp,
      with: always(0)
    )
    patch(
      \ServerRSAPublicKeyFetchNetworkOperation.execute,
      with: always(.init(keyData: "key"))
    )
    patch(
      \ServerPGPPublicKeyFetchNetworkOperation.execute,
      with: always(.init(keyData: "key"))
    )
    patch(
      environment: \.pgp.extractFingerprint,
      with: always(.success("fingerprint"))
    )
    patch(
      \AccountsDataStore.loadServerFingerprint,
      with: always("other")
    )
    patch(
      environment: \.pgp.verifyPublicKeyFingerprint,
      with: always(.failure(MockIssue.error()))
    )

    withTestedInstanceThrows(
      MockIssue.self
    ) { (testedInstance: SessionNetworkAuthorization) in
      try await testedInstance.createSessionTokens(
        (
          account: .mock_ada,
          passphrase: "passphrase",
          privateKey: "private_key"
        ),
        .none
      )
    }
  }

  func test_createSessionTokens_throws_whenValidatingServerPGPKeyFingerprintFails() {
    patch(
      \OSTime.timestamp,
      with: always(0)
    )
    patch(
      \ServerRSAPublicKeyFetchNetworkOperation.execute,
      with: always(.init(keyData: "key"))
    )
    patch(
      \ServerPGPPublicKeyFetchNetworkOperation.execute,
      with: always(.init(keyData: "key"))
    )
    patch(
      environment: \.pgp.extractFingerprint,
      with: always(.success("fingerprint"))
    )
    patch(
      \AccountsDataStore.loadServerFingerprint,
      with: always("other")
    )
    patch(
      environment: \.pgp.verifyPublicKeyFingerprint,
      with: always(.success(false))
    )

    withTestedInstanceThrows(
      ServerPGPFingeprintInvalid.self
    ) { (testedInstance: SessionNetworkAuthorization) in
      try await testedInstance.createSessionTokens(
        (
          account: .mock_ada,
          passphrase: "passphrase",
          privateKey: "private_key"
        ),
        .none
      )
    }
  }

  func test_createSessionTokens_validatesServerKey_whenLocalFingerprintIsStored() {
    patch(
      \OSTime.timestamp,
      with: always(0)
    )
    patch(
      \ServerRSAPublicKeyFetchNetworkOperation.execute,
      with: always(.init(keyData: "key"))
    )
    patch(
      \ServerPGPPublicKeyFetchNetworkOperation.execute,
      with: always(.init(keyData: "key"))
    )
    patch(
      environment: \.pgp.extractFingerprint,
      with: always(.success("fingerprint"))
    )
    patch(
      \AccountsDataStore.loadServerFingerprint,
      with: always("other")
    )
    patch(
      environment: \.pgp.verifyPublicKeyFingerprint,
      with: always(self.executed(returning: .failure(MockIssue.error())))
    )

    withTestedInstanceExecuted { (testedInstance: SessionNetworkAuthorization) in
      // ignore error
      try? await testedInstance.createSessionTokens(
        (
          account: .mock_ada,
          passphrase: "passphrase",
          privateKey: "private_key"
        ),
        .none
      )
    }
  }

  func test_createSessionTokens_throws_whenEncryptingChallengeThrows() {
    patch(
      \OSTime.timestamp,
      with: always(0)
    )
    patch(
      \ServerRSAPublicKeyFetchNetworkOperation.execute,
      with: alwaysThrow(MockIssue.error())
    )
    patch(
      \ServerPGPPublicKeyFetchNetworkOperation.execute,
      with: always(.init(keyData: "key"))
    )
    patch(
      environment: \.pgp.extractFingerprint,
      with: always(.success("fingerprint"))
    )
    patch(
      \AccountsDataStore.loadServerFingerprint,
      with: always("other")
    )
    patch(
      environment: \.pgp.verifyPublicKeyFingerprint,
      with: always(.success(true))
    )
    patch(
      environment: \.pgp.encryptAndSign,
      with: always(.failure(MockIssue.error()))
    )

    withTestedInstanceThrows(
      SessionAuthorizationFailure.self
    ) { (testedInstance: SessionNetworkAuthorization) in
      try await testedInstance.createSessionTokens(
        (
          account: .mock_ada,
          passphrase: "passphrase",
          privateKey: "private_key"
        ),
        .none
      )
    }
  }

  func test_createSessionTokens_throws_whenSessionCreationRequestThrows() {
    patch(
      \OSTime.timestamp,
      with: always(0)
    )
    patch(
      \ServerRSAPublicKeyFetchNetworkOperation.execute,
      with: always(.init(keyData: "key"))
    )
    patch(
      \ServerPGPPublicKeyFetchNetworkOperation.execute,
      with: always(.init(keyData: "key"))
    )
    patch(
      environment: \.pgp.extractFingerprint,
      with: always(.success("fingerprint"))
    )
    patch(
      \AccountsDataStore.loadServerFingerprint,
      with: always("other")
    )
    patch(
      environment: \.pgp.verifyPublicKeyFingerprint,
      with: always(.success(true))
    )
    patch(
      environment: \.pgp.encryptAndSign,
      with: always(.success("encrypted"))
    )
    patch(
      \SessionCreateNetworkOperation.execute,
      with: alwaysThrow(MockIssue.error())
    )

    withTestedInstanceThrows(
      MockIssue.self
    ) { (testedInstance: SessionNetworkAuthorization) in
      try await testedInstance.createSessionTokens(
        (
          account: .mock_ada,
          passphrase: "passphrase",
          privateKey: "private_key"
        ),
        .none
      )
    }
  }

  func test_createSessionTokens_throws_whenChallengeDecryptFails() {
    patch(
      \OSTime.timestamp,
      with: always(0)
    )
    patch(
      \ServerRSAPublicKeyFetchNetworkOperation.execute,
      with: always(.init(keyData: "key"))
    )
    patch(
      \ServerPGPPublicKeyFetchNetworkOperation.execute,
      with: always(.init(keyData: "key"))
    )
    patch(
      environment: \.pgp.extractFingerprint,
      with: always(.success("fingerprint"))
    )
    patch(
      \AccountsDataStore.loadServerFingerprint,
      with: always("other")
    )
    patch(
      environment: \.pgp.verifyPublicKeyFingerprint,
      with: always(.success(true))
    )
    patch(
      environment: \.pgp.encryptAndSign,
      with: always(.success("encrypted"))
    )
    patch(
      \SessionCreateNetworkOperation.execute,
      with: always(
        .init(
          mfaTokenIsValid: false,
          challenge: "challenge"
        )
      )
    )
    patch(
      environment: \.pgp.decryptAndVerify,
      with: always(.failure(MockIssue.error()))
    )

    withTestedInstanceThrows(
      SessionAuthorizationFailure.self
    ) { (testedInstance: SessionNetworkAuthorization) in
      try await testedInstance.createSessionTokens(
        (
          account: .mock_ada,
          passphrase: "passphrase",
          privateKey: "private_key"
        ),
        .none
      )
    }
  }

  func test_createSessionTokens_throws_whenDecryptedResponseIsInvalid() {
    patch(
      \OSTime.timestamp,
      with: always(0)
    )
    patch(
      \ServerRSAPublicKeyFetchNetworkOperation.execute,
      with: always(.init(keyData: "key"))
    )
    patch(
      \ServerPGPPublicKeyFetchNetworkOperation.execute,
      with: always(.init(keyData: "key"))
    )
    patch(
      environment: \.pgp.extractFingerprint,
      with: always(.success("fingerprint"))
    )
    patch(
      \AccountsDataStore.loadServerFingerprint,
      with: always("other")
    )
    patch(
      environment: \.pgp.verifyPublicKeyFingerprint,
      with: always(.success(true))
    )
    patch(
      environment: \.pgp.encryptAndSign,
      with: always(.success("encrypted"))
    )
    patch(
      \SessionCreateNetworkOperation.execute,
      with: always(
        .init(
          mfaTokenIsValid: false,
          challenge: "challenge"
        )
      )
    )
    patch(
      environment: \.pgp.decryptAndVerify,
      with: always(.success("wrong"))
    )

    withTestedInstanceThrows(
      SessionAuthorizationFailure.self
    ) { (testedInstance: SessionNetworkAuthorization) in
      try await testedInstance.createSessionTokens(
        (
          account: .mock_ada,
          passphrase: "passphrase",
          privateKey: "private_key"
        ),
        .none
      )
    }
  }

  func test_createSessionTokens_throws_whenVerifyTokenIsNotMatching() {
    patch(
      \OSTime.timestamp,
      with: always(0)
    )
    patch(
      \ServerRSAPublicKeyFetchNetworkOperation.execute,
      with: always(.init(keyData: "key"))
    )
    patch(
      \ServerPGPPublicKeyFetchNetworkOperation.execute,
      with: always(.init(keyData: "key"))
    )
    patch(
      environment: \.pgp.extractFingerprint,
      with: always(.success("fingerprint"))
    )
    patch(
      \AccountsDataStore.loadServerFingerprint,
      with: always("other")
    )
    patch(
      environment: \.pgp.verifyPublicKeyFingerprint,
      with: always(.success(true))
    )
    patch(
      environment: \.pgp.encryptAndSign,
      with: always(.success("encrypted"))
    )
    patch(
      \SessionCreateNetworkOperation.execute,
      with: always(
        .init(
          mfaTokenIsValid: false,
          challenge: "challenge"
        )
      )
    )
    patch(
      environment: \.pgp.decryptAndVerify,
      with: always(
        .success(
          """
          {
            "version": "1.0.0",
            "domain": "passbolt.dev",
            "verify_token": "invalid",
            "access_token": "\(SessionAccessToken.valid.rawValue)",
            "refresh_token": "token",
            "providers": []
          }
          """
        )
      )
    )

    withTestedInstanceThrows(
      SessionAuthorizationFailure.self
    ) { (testedInstance: SessionNetworkAuthorization) in
      try await testedInstance.createSessionTokens(
        (
          account: .mock_ada,
          passphrase: "passphrase",
          privateKey: "private_key"
        ),
        .none
      )
    }
  }

  func test_createSessionTokens_throws_whenSignatureVerficationFails() {
    patch(
      \OSTime.timestamp,
      with: always(0)
    )
    patch(
      \ServerRSAPublicKeyFetchNetworkOperation.execute,
      with: always(.init(keyData: "key"))
    )
    patch(
      \ServerPGPPublicKeyFetchNetworkOperation.execute,
      with: always(.init(keyData: "key"))
    )
    patch(
      environment: \.pgp.extractFingerprint,
      with: always(.success("fingerprint"))
    )
    patch(
      \AccountsDataStore.loadServerFingerprint,
      with: always("other")
    )
    patch(
      environment: \.pgp.verifyPublicKeyFingerprint,
      with: always(.success(true))
    )
    patch(
      environment: \.pgp.encryptAndSign,
      with: always(.success("encrypted"))
    )
    patch(
      \SessionCreateNetworkOperation.execute,
      with: always(
        .init(
          mfaTokenIsValid: false,
          challenge: "challenge"
        )
      )
    )
    patch(
      environment: \.pgp.decryptAndVerify,
      with: always(
        .success(
          """
          {
            "version": "1.0.0",
            "domain": "passbolt.dev",
            "verify_token": "\(UUID.test.uuidString)",
            "access_token": "\(SessionAccessToken.valid.rawValue)",
            "refresh_token": "token",
            "providers": []
          }
          """
        )
      )
    )
    patch(
      environment: \.signatureVerfication.verify,
      with: always(.failure(MockIssue.error()))
    )

    withTestedInstanceThrows(
      SessionAuthorizationFailure.self
    ) { (testedInstance: SessionNetworkAuthorization) in
      try await testedInstance.createSessionTokens(
        (
          account: .mock_ada,
          passphrase: "passphrase",
          privateKey: "private_key"
        ),
        .none
      )
    }
  }

  func test_createSessionTokens_returnsTokens_whenAllOperationsSucceed() {
    patch(
      \OSTime.timestamp,
      with: always(0)
    )
    patch(
      \ServerRSAPublicKeyFetchNetworkOperation.execute,
      with: always(.init(keyData: "key"))
    )
    patch(
      \ServerPGPPublicKeyFetchNetworkOperation.execute,
      with: always(.init(keyData: "key"))
    )
    patch(
      environment: \.pgp.extractFingerprint,
      with: always(.success("fingerprint"))
    )
    patch(
      \AccountsDataStore.loadServerFingerprint,
      with: always("other")
    )
    patch(
      environment: \.pgp.verifyPublicKeyFingerprint,
      with: always(.success(true))
    )
    patch(
      environment: \.pgp.encryptAndSign,
      with: always(.success("encrypted"))
    )
    patch(
      \SessionCreateNetworkOperation.execute,
      with: always(
        .init(
          mfaTokenIsValid: false,
          challenge: "challenge"
        )
      )
    )
    patch(
      environment: \.pgp.decryptAndVerify,
      with: always(
        .success(
          """
          {
            "version": "1.0.0",
            "domain": "passbolt.dev",
            "verify_token": "\(UUID.test.uuidString)",
            "access_token": "\(SessionAccessToken.valid.rawValue)",
            "refresh_token": "token",
            "providers": []
          }
          """
        )
      )
    )
    patch(
      environment: \.signatureVerfication.verify,
      with: always(.success(Void()))
    )

    withTestedInstance { (testedInstance: SessionNetworkAuthorization) in
      let result = try await testedInstance.createSessionTokens(
        (
          account: .mock_ada,
          passphrase: "passphrase",
          privateKey: "private_key"
        ),
        .none
      )
      XCTAssertEqual(result.tokens.accessToken, .valid)
      XCTAssertEqual(result.tokens.refreshToken, "token")
    }
  }

  func test_createSessionTokens_returnsNoMFAProvidersIfMFATokenIsValid_whenAllOperationsSucceed() {
    patch(
      \OSTime.timestamp,
      with: always(0)
    )
    patch(
      \ServerRSAPublicKeyFetchNetworkOperation.execute,
      with: always(.init(keyData: "key"))
    )
    patch(
      \ServerPGPPublicKeyFetchNetworkOperation.execute,
      with: always(.init(keyData: "key"))
    )
    patch(
      environment: \.pgp.extractFingerprint,
      with: always(.success("fingerprint"))
    )
    patch(
      \AccountsDataStore.loadServerFingerprint,
      with: always("other")
    )
    patch(
      environment: \.pgp.verifyPublicKeyFingerprint,
      with: always(.success(true))
    )
    patch(
      environment: \.pgp.encryptAndSign,
      with: always(.success("encrypted"))
    )
    patch(
      \SessionCreateNetworkOperation.execute,
      with: always(
        .init(
          mfaTokenIsValid: true,
          challenge: "challenge"
        )
      )
    )
    patch(
      environment: \.pgp.decryptAndVerify,
      with: always(
        .success(
          """
          {
            "version": "1.0.0",
            "domain": "passbolt.dev",
            "verify_token": "\(UUID.test.uuidString)",
            "access_token": "\(SessionAccessToken.valid.rawValue)",
            "refresh_token": "token",
            "providers": ["yubikey"]
          }
          """
        )
      )
    )
    patch(
      environment: \.signatureVerfication.verify,
      with: always(.success(Void()))
    )

    withTestedInstance { (testedInstance: SessionNetworkAuthorization) in
      let result = try await testedInstance.createSessionTokens(
        (
          account: .mock_ada,
          passphrase: "passphrase",
          privateKey: "private_key"
        ),
        .none
      )
      XCTAssertEqual(result.requiredMFAProviders, [])
    }
  }

  func test_createSessionTokens_returnsMFAProvidersIfMFATokenIsInvalid_whenAllOperationsSucceed() {
    patch(
      \OSTime.timestamp,
      with: always(0)
    )
    patch(
      \ServerRSAPublicKeyFetchNetworkOperation.execute,
      with: always(.init(keyData: "key"))
    )
    patch(
      \ServerPGPPublicKeyFetchNetworkOperation.execute,
      with: always(.init(keyData: "key"))
    )
    patch(
      environment: \.pgp.extractFingerprint,
      with: always(.success("fingerprint"))
    )
    patch(
      \AccountsDataStore.loadServerFingerprint,
      with: always("other")
    )
    patch(
      environment: \.pgp.verifyPublicKeyFingerprint,
      with: always(.success(true))
    )
    patch(
      environment: \.pgp.encryptAndSign,
      with: always(.success("encrypted"))
    )
    patch(
      \SessionCreateNetworkOperation.execute,
      with: always(
        .init(
          mfaTokenIsValid: false,
          challenge: "challenge"
        )
      )
    )
    patch(
      environment: \.pgp.decryptAndVerify,
      with: always(
        .success(
          """
          {
            "version": "1.0.0",
            "domain": "passbolt.dev",
            "verify_token": "\(UUID.test.uuidString)",
            "access_token": "\(SessionAccessToken.valid.rawValue)",
            "refresh_token": "token",
            "providers": ["yubikey"]
          }
          """
        )
      )
    )
    patch(
      environment: \.signatureVerfication.verify,
      with: always(.success(Void()))
    )

    withTestedInstance { (testedInstance: SessionNetworkAuthorization) in
      let result = try await testedInstance.createSessionTokens(
        (
          account: .mock_ada,
          passphrase: "passphrase",
          privateKey: "private_key"
        ),
        .none
      )
      XCTAssertEqual(result.requiredMFAProviders, [.yubiKey])
    }
  }

  func test_createSessionTokens_throws_whenFetchingServerRSAKeyThrows() {
    patch(
      \OSTime.timestamp,
      with: always(0)
    )
    patch(
      \ServerRSAPublicKeyFetchNetworkOperation.execute,
      with: alwaysThrow(MockIssue.error())
    )
    patch(
      \ServerPGPPublicKeyFetchNetworkOperation.execute,
      with: always(.init(keyData: "key"))
    )
    patch(
      environment: \.pgp.extractFingerprint,
      with: always(.success("fingerprint"))
    )
    patch(
      \AccountsDataStore.loadServerFingerprint,
      with: always("other")
    )
    patch(
      environment: \.pgp.verifyPublicKeyFingerprint,
      with: always(.success(true))
    )
    patch(
      environment: \.pgp.encryptAndSign,
      with: always(.success("encrypted"))
    )
    patch(
      \SessionCreateNetworkOperation.execute,
      with: always(
        .init(
          mfaTokenIsValid: false,
          challenge: "challenge"
        )
      )
    )

    withTestedInstanceThrows(
      MockIssue.self
    ) { (testedInstance: SessionNetworkAuthorization) in
      try await testedInstance.createSessionTokens(
        (
          account: .mock_ada,
          passphrase: "passphrase",
          privateKey: "private_key"
        ),
        .none
      )
    }
  }

  func test_refreshSessionTokens_throws_whenRefreshOperationFails() {
    patch(
      \SessionRefreshNetworkOperation.execute,
      with: alwaysThrow(MockIssue.error())
    )
    withTestedInstanceThrows(
      MockIssue.self
    ) { (testedInstance: SessionNetworkAuthorization) in
      try await testedInstance.refreshSessionTokens(
        (
          account: .mock_ada,
          passphrase: "passphrase",
          privateKey: "private_key"
        ),
        "refresh_token",
        .none
      )
    }
  }

  func test_refreshSessionTokens_returnsNewTokens_whenRefreshingSucceeds() {
    patch(
      \SessionRefreshNetworkOperation.execute,
      with: always(
        .init(
          accessToken: .valid,
          refreshToken: "new_refresh_token"
        )
      )
    )
    withTestedInstance { (testedInstance: SessionNetworkAuthorization) in
      let result = try await testedInstance.refreshSessionTokens(
        (
          account: .mock_ada,
          passphrase: "passphrase",
          privateKey: "private_key"
        ),
        "refresh_token",
        .none
      )
      XCTAssertEqual(result.accessToken, .valid)
      XCTAssertEqual(result.refreshToken, "new_refresh_token")
    }
  }

  func test_invalidateSessionTokens_throws_whenClosingSessionFails() {
    patch(
      \SessionCloseNetworkOperation.execute,
      with: alwaysThrow(MockIssue.error())
    )
    withTestedInstanceThrows(
      MockIssue.self
    ) { (testedInstance: SessionNetworkAuthorization) in
      try await testedInstance.invalidateSessionTokens(
        .mock_ada,
        "refresh_token"
      )
    }
  }

  func test_invalidateSessionTokens_succeeds_whenClosingSessionSucceeds() {
    patch(
      \SessionCloseNetworkOperation.execute,
      with: always(Void())
    )
    withTestedInstanceNotThrows { (testedInstance: SessionNetworkAuthorization) in
      try await testedInstance.invalidateSessionTokens(
        .mock_ada,
        "refresh_token"
      )
    }
  }
}
