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
import FeatureScopes
import TestExtensions

@testable import PassboltSession

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class SessionCryptographyTests: LoadableFeatureTestCase<SessionCryptography> {

  override class var testedImplementationScope: any FeaturesScope.Type { SessionScope.self }

  override class func testedImplementationRegister(
    _ registry: inout FeaturesRegistry
  ) {
    registry.usePassboltSessionCryptography()
  }

  override func prepare() throws {
    self.set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_1
      )
    )

    use(Session.placeholder)
    use(SessionStateEnsurance.placeholder)
    use(SessionAuthorizationState.placeholder)
    use(AccountsDataStore.placeholder)
    use(PGP.placeholder)
  }

  func test_decryptMessage_returnsDecryptedAndVerifiedMessage_whenAllOperationsSucceed_withPublicKey() {
    patch(
      \Session.currentAccount,
      with: always(.mock_ada)
    )
    patch(
      \SessionStateEnsurance.passphrase,
      with: always("passphrase")
    )
    patch(
      \AccountsDataStore.loadAccountPrivateKey,
      with: always("privatePGPKey")
    )
    patch(
      \PGP.decryptAndVerify,
      with: always(.success(.valid(message: "plainMessage")))
    )

    withTestedInstanceReturnsEqual("plainMessage") { (testedInstance: SessionCryptography) in
      try await testedInstance.decryptMessage("encryptedMessage", "publicPGPKey")
    }
  }

  func test_decryptMessage_returnsDecryptedMessage_whenAllOperationsSucceed_withoutPublicKey() {
    patch(
      \Session.currentAccount,
      with: always(.mock_ada)
    )
    patch(
      \SessionStateEnsurance.passphrase,
      with: always("passphrase")
    )
    patch(
      \AccountsDataStore.loadAccountPrivateKey,
      with: always("privatePGPKey")
    )
    patch(
      \PGP.decrypt,
      with: always(.success("plainMessage"))
    )

    withTestedInstanceReturnsEqual("plainMessage") { (testedInstance: SessionCryptography) in
      try await testedInstance.decryptMessage("encryptedMessage", .none)
    }
  }

  func test_decryptMessage_fails_whenDecryptFails() {
    patch(
      \Session.currentAccount,
      with: always(.mock_ada)
    )
    patch(
      \SessionStateEnsurance.passphrase,
      with: always("passphrase")
    )
    patch(
      \AccountsDataStore.loadAccountPrivateKey,
      with: always("privatePGPKey")
    )
    patch(
      \PGP.decrypt,
      with: always(.failure(MockIssue.error()))
    )

    withTestedInstanceThrows(MockIssue.self) { (testedInstance: SessionCryptography) in
      try await testedInstance.decryptMessage("encryptedMessage", .none)
    }
  }

  func test_decryptMessage_fails_whenLoadingPrivateKeyFails() {
    patch(
      \Session.currentAccount,
      with: always(.mock_ada)
    )
    patch(
      \SessionStateEnsurance.passphrase,
      with: always("passphrase")
    )
    patch(
      \AccountsDataStore.loadAccountPrivateKey,
      with: alwaysThrow(MockIssue.error())
    )

    withTestedInstanceThrows(MockIssue.self) { (testedInstance: SessionCryptography) in
      try await testedInstance.decryptMessage("encryptedMessage", .none)
    }
  }

  func test_decryptMessage_fails_whenAccessingPassphraseFails() {
    patch(
      \Session.currentAccount,
      with: always(.mock_ada)
    )
    patch(
      \SessionStateEnsurance.passphrase,
      with: alwaysThrow(MockIssue.error())
    )

    withTestedInstanceThrows(MockIssue.self) { (testedInstance: SessionCryptography) in
      try await testedInstance.decryptMessage("encryptedMessage", .none)
    }
  }

  func test_decryptMessage_fails_whenSessionMissing() {
    patch(
      \Session.currentAccount,
      with: alwaysThrow(SessionMissing.error())
    )

    withTestedInstanceThrows(SessionMissing.self) { (testedInstance: SessionCryptography) in
      try await testedInstance.decryptMessage("encryptedMessage", .none)
    }
  }

  func test_encryptAndSignMessage_returnsEncryptedMessage_whenAllOperationsSucceed() {
    patch(
      \Session.currentAccount,
      with: always(.mock_ada)
    )
    patch(
      \SessionStateEnsurance.passphrase,
      with: always("passphrase")
    )
    patch(
      \AccountsDataStore.loadAccountPrivateKey,
      with: always("privatePGPKey")
    )
    patch(
      \PGP.encryptAndSign,
      with: always(.success("encryptedMessage"))
    )

    withTestedInstanceReturnsEqual("encryptedMessage") { (testedInstance: SessionCryptography) in
      try await testedInstance.encryptAndSignMessage("plainMessage", "publicPGPKey")
    }
  }

  func test_encryptAndSignMessage_fails_whenEncryptAndSignFails() {
    patch(
      \Session.currentAccount,
      with: always(.mock_ada)
    )
    patch(
      \SessionStateEnsurance.passphrase,
      with: always("passphrase")
    )
    patch(
      \AccountsDataStore.loadAccountPrivateKey,
      with: always("privatePGPKey")
    )
    patch(
      \PGP.decrypt,
      with: always(.failure(MockIssue.error()))
    )

    patch(
      \PGP.encryptAndSign,
      with: always(.failure(MockIssue.error()))
    )

    withTestedInstanceThrows(MockIssue.self) { (testedInstance: SessionCryptography) in
      try await testedInstance.encryptAndSignMessage("plainMessage", "publicPGPKey")
    }
  }

  func test_encryptAndSignMessage_fails_whenLoadingPrivateKeyFails() {
    patch(
      \Session.currentAccount,
      with: always(.mock_ada)
    )
    patch(
      \SessionStateEnsurance.passphrase,
      with: always("passphrase")
    )
    patch(
      \AccountsDataStore.loadAccountPrivateKey,
      with: alwaysThrow(MockIssue.error())
    )

    withTestedInstanceThrows(MockIssue.self) { (testedInstance: SessionCryptography) in
      try await testedInstance.encryptAndSignMessage("plainMessage", "publicPGPKey")
    }
  }

  func test_encryptAndSignMessage_fails_whenAccessingPassphraseFails() {
    patch(
      \Session.currentAccount,
      with: always(.mock_ada)
    )
    patch(
      \SessionStateEnsurance.passphrase,
      with: alwaysThrow(MockIssue.error())
    )

    withTestedInstanceThrows(MockIssue.self) { (testedInstance: SessionCryptography) in
      try await testedInstance.encryptAndSignMessage("plainMessage", "publicPGPKey")
    }
  }

  func test_encryptAndSignMessage_fails_whenSessionMissing() {
    patch(
      \Session.currentAccount,
      with: alwaysThrow(SessionMissing.error())
    )

    withTestedInstanceThrows(SessionMissing.self) { (testedInstance: SessionCryptography) in
      try await testedInstance.encryptAndSignMessage("plainMessage", "publicPGPKey")
    }
  }

  func test_decrytSessionKey_succeeds_withValidData() {
    patch(
      \Session.currentAccount,
      with: always(.mock_ada)
    )
    patch(
      \SessionStateEnsurance.passphrase,
      with: always("passphrase")
    )
    patch(
      \AccountsDataStore.loadAccountPrivateKey,
      with: always("privatePGPKey")
    )
  }
}

extension PGP.VerifiedMessage {
  static func valid(message: String) -> Self {
    .init(
      content: message,
      signature: .empty
    )
  }
}

extension PGP.Signature {
  static var empty: Self {
    .init(
      signature: .empty,
      createdAt: .now,
      fingerprint: .empty,
      keyID: .empty
    )
  }
}
