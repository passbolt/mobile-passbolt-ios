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
final class SessionMFAAuthorizationTests: LoadableFeatureTestCase<SessionMFAAuthorization>, @unchecked Sendable {

  override class func testedImplementationRegister(
    _ registry: inout FeaturesRegistry
  ) {
    registry.usePassboltSessionMFAAuthorization()
  }

  override func prepare() throws {
    use(SessionState.placeholder)
    use(AccountMFATokenStorage.placeholder)
    use(TOTPAuthorizationNetworkOperation.placeholder)
    use(YubiKeyAuthorizationNetworkOperation.placeholder)
    use(WebauthnDelegatedCallbackNetworkOperation.placeholder)
    use(ServerRSAPublicKeyFetchNetworkOperation.placeholder)
    use(YubiKey.placeholder)
  }

  func test_authorizeMFA_totp_throws_withoutSession() {
    patch(
      \SessionState.account,
      with: always(.none)
    )
    withTestedInstanceThrows(
      SessionClosed.self
    ) { (testedInstance: SessionMFAAuthorization) in
      try await testedInstance.authorizeMFA(.totp(.mock_ada, code: "totp", rememberDevice: false))
    }
  }

  func test_authorizeMFA_totp_throws_whenAuthorizationRequestThrows() {
    patch(
      \SessionState.account,
      with: always(.mock_ada)
    )
    patch(
      \TOTPAuthorizationNetworkOperation.execute,
      with: alwaysThrow(MockIssue.error())
    )
    withTestedInstanceThrows(
      MockIssue.self
    ) { (testedInstance: SessionMFAAuthorization) in
      try await testedInstance.authorizeMFA(.totp(.mock_ada, code: "totp", rememberDevice: false))
    }
  }

  func test_authorizeMFA_totp_succeeds_whenAuthorizationSucceeds() {
    patch(
      \SessionState.account,
      with: always(.mock_ada)
    )
    patch(
      \TOTPAuthorizationNetworkOperation.execute,
      with: always(.init(mfaToken: "token"))
    )
    patch(
      \SessionLocking.ensureLocking,
      with: always(Void())
    )
    patch(
      \SessionState.mfaProvided,
      with: always(self.executed())
    )
    withTestedInstanceExecuted { (testedInstance: SessionMFAAuthorization) in
      try await testedInstance.authorizeMFA(.totp(.mock_ada, code: "totp", rememberDevice: false))
    }
  }

  func test_authorizeMFA_totp_throws_whenStoringTokenThrows() {
    patch(
      \SessionState.account,
      with: always(.mock_ada)
    )
    patch(
      \TOTPAuthorizationNetworkOperation.execute,
      with: always(.init(mfaToken: "token"))
    )
    patch(
      \SessionState.mfaProvided,
      with: always(Void())
    )
    patch(
      \AccountMFATokenStorage.storeAccountMFAToken,
      with: alwaysThrow(MockIssue.error())
    )
    withTestedInstanceThrows(
      MockIssue.self
    ) { (testedInstance: SessionMFAAuthorization) in
      try await testedInstance.authorizeMFA(.totp(.mock_ada, code: "totp", rememberDevice: true))
    }
  }

  func test_authorizeMFA_totp_succeeds_whenStoringTokenSucceeds() {
    patch(
      \SessionState.account,
      with: always(.mock_ada)
    )
    patch(
      \TOTPAuthorizationNetworkOperation.execute,
      with: always(.init(mfaToken: "token"))
    )
    patch(
      \SessionState.mfaProvided,
      with: always(Void())
    )
    patch(
      \SessionLocking.ensureLocking,
      with: always(Void())
    )
    patch(
      \AccountMFATokenStorage.storeAccountMFAToken,
      with: always(Void())
    )
    withTestedInstanceNotThrows { (testedInstance: SessionMFAAuthorization) in
      try await testedInstance.authorizeMFA(.totp(.mock_ada, code: "totp", rememberDevice: true))
    }
  }

  func test_authorizeMFA_totp_ensuresSessionLocking_whenAuthorizationSucceeds() {
    patch(
      \SessionState.account,
      with: always(.mock_ada)
    )
    patch(
      \TOTPAuthorizationNetworkOperation.execute,
      with: always(.init(mfaToken: "token"))
    )
    patch(
      \SessionState.mfaProvided,
      with: always(Void())
    )
    patch(
      \SessionLocking.ensureLocking,
      with: always(self.executed())
    )
    patch(
      \AccountMFATokenStorage.storeAccountMFAToken,
      with: always(Void())
    )
    withTestedInstanceExecuted { (testedInstance: SessionMFAAuthorization) in
      try await testedInstance.authorizeMFA(.totp(.mock_ada, code: "totp", rememberDevice: true))
    }
  }

  func test_authorizeMFA_yubikey_throws_withoutSession() {
    patch(
      \SessionState.account,
      with: always(.none)
    )
    withTestedInstanceThrows(
      SessionClosed.self
    ) { (testedInstance: SessionMFAAuthorization) in
      try await testedInstance.authorizeMFA(.yubiKey(.mock_ada, rememberDevice: false))
    }
  }

  func test_authorizeMFA_yubikey_throws_whenReadingNFCThrows() {
    patch(
      \SessionState.account,
      with: always(.mock_ada)
    )
    patch(
      \YubiKey.read,
      with: always(
        Fail(error: MockIssue.error())
          .eraseToAnyPublisher()
      )
    )
    withTestedInstanceThrows(
      MockIssue.self
    ) { (testedInstance: SessionMFAAuthorization) in
      try await testedInstance.authorizeMFA(.yubiKey(.mock_ada, rememberDevice: false))
    }
  }

  func test_authorizeMFA_yubikey_throws_whenAuthorizationRequestThrows() {
    patch(
      \SessionState.account,
      with: always(.mock_ada)
    )
    patch(
      \YubiKey.read,
      with: always(
        Just("otp")
          .eraseErrorType()
          .eraseToAnyPublisher()
      )
    )
    patch(
      \YubiKeyAuthorizationNetworkOperation.execute,
      with: alwaysThrow(MockIssue.error())
    )
    withTestedInstanceThrows(
      MockIssue.self
    ) { (testedInstance: SessionMFAAuthorization) in
      try await testedInstance.authorizeMFA(.yubiKey(.mock_ada, rememberDevice: false))
    }
  }

  func test_authorizeMFA_yubikey_savesToken_whenAuthorizationSucceeds() {
    patch(
      \SessionState.account,
      with: always(.mock_ada)
    )
    patch(
      \YubiKey.read,
      with: always(
        Just("otp")
          .eraseErrorType()
          .eraseToAnyPublisher()
      )
    )
    patch(
      \YubiKeyAuthorizationNetworkOperation.execute,
      with: always(.init(mfaToken: "token"))
    )
    patch(
      \SessionState.mfaProvided,
      with: always(self.executed())
    )
    patch(
      \SessionLocking.ensureLocking,
      with: always(Void())
    )
    withTestedInstanceExecuted { (testedInstance: SessionMFAAuthorization) in
      try await testedInstance.authorizeMFA(.yubiKey(.mock_ada, rememberDevice: false))
    }
  }

  func test_authorizeMFA_yubikey_throws_whenStoringTokenThrows() {
    patch(
      \SessionState.account,
      with: always(.mock_ada)
    )
    patch(
      \YubiKey.read,
      with: always(
        Just("otp")
          .eraseErrorType()
          .eraseToAnyPublisher()
      )
    )
    patch(
      \YubiKeyAuthorizationNetworkOperation.execute,
      with: always(.init(mfaToken: "token"))
    )
    patch(
      \SessionState.mfaProvided,
      with: always(Void())
    )
    patch(
      \AccountMFATokenStorage.storeAccountMFAToken,
      with: alwaysThrow(MockIssue.error())
    )
    withTestedInstanceThrows(
      MockIssue.self
    ) { (testedInstance: SessionMFAAuthorization) in
      try await testedInstance.authorizeMFA(.yubiKey(.mock_ada, rememberDevice: true))
    }
  }

  func test_authorizeMFA_yubikey_succeeds_whenStoringTokenSucceeds() {
    patch(
      \SessionState.account,
      with: always(.mock_ada)
    )
    patch(
      \YubiKey.read,
      with: always(
        Just("otp")
          .eraseErrorType()
          .eraseToAnyPublisher()
      )
    )
    patch(
      \YubiKeyAuthorizationNetworkOperation.execute,
      with: always(.init(mfaToken: "token"))
    )
    patch(
      \SessionState.mfaProvided,
      with: always(Void())
    )
    patch(
      \SessionLocking.ensureLocking,
      with: always(Void())
    )
    patch(
      \AccountMFATokenStorage.storeAccountMFAToken,
      with: alwaysThrow(MockIssue.error())
    )
    withTestedInstanceThrows(
      MockIssue.self
    ) { (testedInstance: SessionMFAAuthorization) in
      try await testedInstance.authorizeMFA(.yubiKey(.mock_ada, rememberDevice: true))
    }
  }

  func test_authorizeMFA_yubikey_ensuresSessionLocking_whenAuthorizationSucceeds() {
    patch(
      \SessionState.account,
      with: always(.mock_ada)
    )
    patch(
      \YubiKey.read,
      with: always(
        Just("otp")
          .eraseErrorType()
          .eraseToAnyPublisher()
      )
    )
    patch(
      \YubiKeyAuthorizationNetworkOperation.execute,
      with: always(.init(mfaToken: "token"))
    )
    patch(
      \SessionState.mfaProvided,
      with: always(Void())
    )
    patch(
      \SessionLocking.ensureLocking,
      with: always(self.executed())
    )
    patch(
      \AccountMFATokenStorage.storeAccountMFAToken,
      with: always(Void())
    )
    withTestedInstanceExecuted { (testedInstance: SessionMFAAuthorization) in
      try await testedInstance.authorizeMFA(.yubiKey(.mock_ada, rememberDevice: true))
    }
  }

  func test_authorizeMFA_webauthn_throws_withoutSession() {
    patch(
      \SessionState.account,
      with: always(.none)
    )
    withTestedInstanceThrows(
      SessionClosed.self
    ) { (testedInstance: SessionMFAAuthorization) in
      try await testedInstance
        .authorizeMFA(
          .webauthn(
            .mock_ada,
            delegatedState: "delegated-state",
            delegatedToken: self.delegatedToken,
            delegatedSecret: "delegated-secret",
            rememberDevice: false
          )
        )
    }
  }

  func test_authorizeMFA_webauthn_throws_whenConsumingDelegatedTokenThrows() {
    patch(
      \SessionState.account,
      with: always(.mock_ada)
    )
    patchDelegatedTokenVerification()
    patch(
      \WebauthnDelegatedCallbackNetworkOperation.execute,
      with: alwaysThrow(MockIssue.error())
    )
    withTestedInstanceThrows(
      MockIssue.self
    ) { (testedInstance: SessionMFAAuthorization) in
      try await testedInstance
        .authorizeMFA(
          .webauthn(
            .mock_ada,
            delegatedState: "delegated-state",
            delegatedToken: self.delegatedToken,
            delegatedSecret: "delegated-secret",
            rememberDevice: false
          )
        )
    }
  }

  func test_authorizeMFA_webauthn_providesToken_whenConsumingDelegatedTokenSucceeds() {
    patch(
      \SessionState.account,
      with: always(.mock_ada)
    )
    patchDelegatedTokenVerification()
    patch(
      \WebauthnDelegatedCallbackNetworkOperation.execute,
      with: always(.init(mfaToken: "token"))
    )
    patch(
      \SessionLocking.ensureLocking,
      with: always(Void())
    )
    patch(
      \SessionState.mfaProvided,
      with: always(self.executed())
    )
    withTestedInstanceExecuted { (testedInstance: SessionMFAAuthorization) in
      try await testedInstance
        .authorizeMFA(
          .webauthn(
            .mock_ada,
            delegatedState: "delegated-state",
            delegatedToken: self.delegatedToken,
            delegatedSecret: "delegated-secret",
            rememberDevice: false
          )
        )
    }
  }

  func test_authorizeMFA_webauthn_passesDelegatedTokenAndSecret_toCallbackOperation() {
    patch(
      \SessionState.account,
      with: always(.mock_ada)
    )
    patchDelegatedTokenVerification()
    patch(
      \WebauthnDelegatedCallbackNetworkOperation.execute,
      with: { (input: WebauthnDelegatedCallbackNetworkOperationVariable) in
        // token and secret are both strings, the order pins each value to its own field
        self.executed(using: [input.delegatedToken, input.delegatedSecret] as Array<String>)
        return .init(mfaToken: "token")
      }
    )
    patch(
      \SessionLocking.ensureLocking,
      with: always(Void())
    )
    patch(
      \SessionState.mfaProvided,
      with: always(Void())
    )
    withTestedInstanceExecuted(
      using: [self.delegatedToken, "delegated-secret"] as Array<String>
    ) { (testedInstance: SessionMFAAuthorization) in
      try await testedInstance
        .authorizeMFA(
          .webauthn(
            .mock_ada,
            delegatedState: "delegated-state",
            delegatedToken: self.delegatedToken,
            delegatedSecret: "delegated-secret",
            rememberDevice: false
          )
        )
    }
  }

  func test_authorizeMFA_webauthn_savesToken_whenRememberingDevice() {
    patch(
      \SessionState.account,
      with: always(.mock_ada)
    )
    patchDelegatedTokenVerification()
    patch(
      \WebauthnDelegatedCallbackNetworkOperation.execute,
      with: always(.init(mfaToken: "token"))
    )
    patch(
      \SessionState.mfaProvided,
      with: always(Void())
    )
    patch(
      \SessionLocking.ensureLocking,
      with: always(Void())
    )
    patch(
      \AccountMFATokenStorage.storeAccountMFAToken,
      with: always(self.executed())
    )
    withTestedInstanceExecuted { (testedInstance: SessionMFAAuthorization) in
      try await testedInstance
        .authorizeMFA(
          .webauthn(
            .mock_ada,
            delegatedState: "delegated-state",
            delegatedToken: self.delegatedToken,
            delegatedSecret: "delegated-secret",
            rememberDevice: true
          )
        )
    }
  }

  func test_authorizeMFA_webauthn_throws_whenFetchingServerRSAKeyThrows() {
    patch(
      \SessionState.account,
      with: always(.mock_ada)
    )
    patch(
      \ServerRSAPublicKeyFetchNetworkOperation.execute,
      with: alwaysThrow(MockIssue.error())
    )
    withTestedInstanceThrows(
      MockIssue.self
    ) { (testedInstance: SessionMFAAuthorization) in
      try await testedInstance
        .authorizeMFA(
          .webauthn(
            .mock_ada,
            delegatedState: "delegated-state",
            delegatedToken: self.delegatedToken,
            delegatedSecret: "delegated-secret",
            rememberDevice: false
          )
        )
    }
  }

  func test_authorizeMFA_webauthn_throws_withoutConsumingDelegatedToken_whenTokenIsNotValid() {
    patch(
      \SessionState.account,
      with: always(.mock_ada)
    )
    patchDelegatedTokenVerification()
    patch(
      \WebauthnDelegatedCallbackNetworkOperation.execute,
      with: alwaysThrow(MockIssue.error())
    )
    // reaching the callback operation would throw MockIssue instead
    withTestedInstanceThrows(
      WebauthnAuthorizationFailure.self
    ) { (testedInstance: SessionMFAAuthorization) in
      try await testedInstance
        .authorizeMFA(
          .webauthn(
            .mock_ada,
            delegatedState: "other-state",
            delegatedToken: self.delegatedToken,
            delegatedSecret: "delegated-secret",
            rememberDevice: false
          )
        )
    }
  }

  func test_authorizeMFA_webauthn_fetchesServerRSAKey_fromAccountDomain() {
    patch(
      \SessionState.account,
      with: always(.mock_ada)
    )
    patchDelegatedTokenVerification()
    patch(
      \ServerRSAPublicKeyFetchNetworkOperation.execute,
      with: { (input: ServerRSAPublicKeyFetchNetworkOperationVariable) in
        self.executed(using: input.domain)
        return .init(keyData: "server-rsa-key")
      }
    )
    patch(
      \WebauthnDelegatedCallbackNetworkOperation.execute,
      with: always(.init(mfaToken: "token"))
    )
    patch(
      \SessionLocking.ensureLocking,
      with: always(Void())
    )
    patch(
      \SessionState.mfaProvided,
      with: always(Void())
    )
    withTestedInstanceExecuted(
      using: Account.mock_ada.domain
    ) { (testedInstance: SessionMFAAuthorization) in
      try await testedInstance
        .authorizeMFA(
          .webauthn(
            .mock_ada,
            delegatedState: "delegated-state",
            delegatedToken: self.delegatedToken,
            delegatedSecret: "delegated-secret",
            rememberDevice: false
          )
        )
    }
  }

  // issued by `https://passbolt.com/` for the `delegated-state` ceremony, expiring at 1000,
  // its signature is not valid so the signature verification is mocked
  private let delegatedToken: String =
    "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9."
    + "eyJpc3MiOiJodHRwczovL3Bhc3Nib2x0LmNvbS8iLCJhdWQiOiJwYXNzYm9sdC1tb2JpbGUtbWZhLWV4Y2hhbmdlIiwic3Vi"
    + "IjoidXNlci1pZCIsImNpZCI6ImRlbGVnYXRlZC1zdGF0ZSIsImp0aSI6InRva2VuLWlkIiwiaWF0IjowLCJleHAiOjEwMDB9."
    + "c2lnbmF0dXJl"

  private func patchDelegatedTokenVerification() {
    patch(
      \ServerRSAPublicKeyFetchNetworkOperation.execute,
      with: always(.init(keyData: "server-rsa-key"))
    )
    patch(
      \SignatureVerification.verify,
      with: always(.success(Void()))
    )
    patch(
      \OSTime.timestamp,
      with: always(0)
    )
  }
}
