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
@available(iOS 16.0.0, *)
final class SessionMFAAuthorizationTests: LoadableFeatureTestCase<SessionMFAAuthorization> {

  override class func testedImplementationRegister(
    _ registry: inout FeaturesRegistry
  ) {
    registry.usePassboltSessionMFAAuthorization()
  }

  override func prepare() throws {
    use(SessionState.placeholder)
    use(AccountsDataStore.placeholder)
    use(TOTPAuthorizationNetworkOperation.placeholder)
    use(YubiKeyAuthorizationNetworkOperation.placeholder)
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
      \AccountsDataStore.storeAccountMFAToken,
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
      \AccountsDataStore.storeAccountMFAToken,
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
			\AccountsDataStore.storeAccountMFAToken,
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
      \AccountsDataStore.storeAccountMFAToken,
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
      \AccountsDataStore.storeAccountMFAToken,
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
			\AccountsDataStore.storeAccountMFAToken,
			with: always(Void())
		)
		withTestedInstanceExecuted { (testedInstance: SessionMFAAuthorization) in
			try await testedInstance.authorizeMFA(.yubiKey(.mock_ada, rememberDevice: true))
		}
	}
}
