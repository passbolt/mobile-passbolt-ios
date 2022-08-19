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
import Crypto

@testable import PassboltSession

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class SessionCryptographyTests: LoadableFeatureTestCase<SessionCryptography> {

  override class var testedImplementationRegister: (FeatureFactory) -> @MainActor () -> Void {
    FeatureFactory.usePassboltSessionCryptography
  }

  override func prepare() throws {
    use(Session.placeholder)
    use(SessionStateEnsurance.placeholder)
    use(SessionAuthorizationState.placeholder)
    use(AccountsDataStore.placeholder)
  }

  func test_decryptMessage_returnsDecryptedAndVerifiedMessage_whenAllOperationsSucceed_withPublicKey() {
    patch(
      \Session.currentAccount,
      with: always(.valid)
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
      environment: \.pgp.decryptAndVerify,
       with: always(.success("plainMessage"))
    )

    withTestedInstanceReturnsEqual("plainMessage") { (testedInstance: SessionCryptography) in
      try await testedInstance.decryptMessage("encryptedMessage", "publicPGPKey")
    }
  }

  func test_decryptMessage_returnsDecryptedMessage_whenAllOperationsSucceed_withoutPublicKey() {
    patch(
      \Session.currentAccount,
      with: always(.valid)
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
      environment: \.pgp.decrypt,
       with: always(.success("plainMessage"))
    )

    withTestedInstanceReturnsEqual("plainMessage") { (testedInstance: SessionCryptography) in
      try await testedInstance.decryptMessage("encryptedMessage", .none)
    }
  }

  func test_decryptMessage_fails_whenDecryptFails() {
    patch(
      \Session.currentAccount,
      with: always(.valid)
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
      environment: \.pgp.decrypt,
      with: always(.failure(MockIssue.error()))
    )

    withTestedInstanceThrows(MockIssue.self) { (testedInstance: SessionCryptography) in
      try await testedInstance.decryptMessage("encryptedMessage", .none)
    }
  }

  func test_decryptMessage_fails_whenLoadingPrivateKeyFails() {
    patch(
      \Session.currentAccount,
      with: always(.valid)
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
      with: always(.valid)
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
      with: always(.valid)
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
      environment: \.pgp.encryptAndSign,
       with: always(.success("encryptedMessage"))
    )

    withTestedInstanceReturnsEqual("encryptedMessage") { (testedInstance: SessionCryptography) in
      try await testedInstance.encryptAndSignMessage("plainMessage", "publicPGPKey")
    }
  }

  func test_encryptAndSignMessage_fails_whenEncryptAndSignFails() {
    patch(
      \Session.currentAccount,
      with: always(.valid)
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
      environment: \.pgp.decrypt,
      with: always(.failure(MockIssue.error()))
    )

    patch(
      environment: \.pgp.encryptAndSign,
      with: always(.failure(MockIssue.error()))
    )

    withTestedInstanceThrows(MockIssue.self) { (testedInstance: SessionCryptography) in
      try await testedInstance.encryptAndSignMessage("plainMessage", "publicPGPKey")
    }
  }

  func test_encryptAndSignMessage_fails_whenLoadingPrivateKeyFails() {
    patch(
      \Session.currentAccount,
      with: always(.valid)
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
      with: always(.valid)
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
}
