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
final class SessionAuthorizationTests: LoadableFeatureTestCase<SessionAuthorization> {

  override class var testedImplementationRegister: (FeatureFactory) -> @MainActor () -> Void {
    FeatureFactory.usePassboltSessionAuthorization
  }

  override func prepare() throws {
    use(SessionState.placeholder)
    use(SessionAuthorizationState.placeholder)
    use(SessionNetworkAuthorization.placeholder)
    use(AccountsDataStore.placeholder)
    use(OSTime.placeholder)
    patch(
      environment: \.pgp,
      with: .placeholder
    )
  }

  func test_authorize_adHoc_throws_whenVerifyingPassphraseFails() {
    patch(
      environment: \.pgp.verifyPassphrase,
      with: always(.failure(MockIssue.error()))
    )

    withTestedInstanceThrows(
      PassphraseInvalid.self
    ) { (testedInstance: SessionAuthorization) in
      try await testedInstance.authorize(.adHoc(.valid, "passphrase", "private_key"))
    }
  }

  func test_authorize_passphrase_throws_whenLoadingPrivateKeyFails() {
    patch(
      \AccountsDataStore.loadAccountPrivateKey,
      with: alwaysThrow(MockIssue.error())
    )

    withTestedInstanceThrows(
      MockIssue.self
    ) { (testedInstance: SessionAuthorization) in
      try await testedInstance.authorize(.passphrase(.valid, "passphrase"))
    }
  }

  func test_authorize_passphrase_throws_whenVerifyingPassphraseFails() {
    patch(
      \AccountsDataStore.loadAccountPrivateKey,
      with: always("private_key")
    )
    patch(
      environment: \.pgp.verifyPassphrase,
      with: always(.failure(MockIssue.error()))
    )

    withTestedInstanceThrows(
      PassphraseInvalid.self
    ) { (testedInstance: SessionAuthorization) in
      try await testedInstance.authorize(.passphrase(.valid, "passphrase"))
    }
  }

  func test_authorize_biometrics_throws_whenLoadingPassphraseFails() {
    patch(
      \AccountsDataStore.loadAccountPassphrase,
      with: alwaysThrow(MockIssue.error())
    )

    withTestedInstanceThrows(
      MockIssue.self
    ) { (testedInstance: SessionAuthorization) in
      try await testedInstance.authorize(.biometrics(.valid))
    }
  }

  func test_authorize_biometrics_throws_whenLoadingPrivateKeyFails() {
    patch(
      \AccountsDataStore.loadAccountPassphrase,
      with: always("passphrase")
    )
    patch(
      \AccountsDataStore.loadAccountPrivateKey,
      with: alwaysThrow(MockIssue.error())
    )

    withTestedInstanceThrows(
      MockIssue.self
    ) { (testedInstance: SessionAuthorization) in
      try await testedInstance.authorize(.biometrics(.valid))
    }
  }

  func test_authorize_biometrics_throws_whenVerifyingPassphraseFails() {
    patch(
      \AccountsDataStore.loadAccountPassphrase,
      with: always("passphrase")
    )
    patch(
      \AccountsDataStore.loadAccountPrivateKey,
      with: always("private_key")
    )
    patch(
      environment: \.pgp.verifyPassphrase,
      with: always(.failure(MockIssue.error()))
    )

    withTestedInstanceThrows(
      PassphraseInvalid.self
    ) { (testedInstance: SessionAuthorization) in
      try await testedInstance.authorize(.biometrics(.valid))
    }
  }

  func test_authorize_biometrics_throws_whenCreatingSessionTokensFail() {
    patch(
      \AccountsDataStore.loadAccountPassphrase,
      with: always("passphrase")
    )
    patch(
      \AccountsDataStore.loadAccountPrivateKey,
      with: always("private_key")
    )
    patch(
      environment: \.pgp.verifyPassphrase,
      with: always(.success(Void()))
    )
    patch(
      \SessionState.account,
      with: always(.none)
    )
    patch(
      \AccountsDataStore.loadAccountMFAToken,
      with: always(.none)
    )
    patch(
      \SessionNetworkAuthorization.createSessionTokens,
      with: alwaysThrow(MockIssue.error())
    )

    withTestedInstanceThrows(
      MockIssue.self
    ) { (testedInstance: SessionAuthorization) in
      try await testedInstance.authorize(.biometrics(.valid))
    }
  }

  func test_authorize_biometrics_succeeds_whenCreatingSessionSucceeds() {
    patch(
      \AccountsDataStore.loadAccountPassphrase,
      with: always("passphrase")
    )
    patch(
      \AccountsDataStore.loadAccountPrivateKey,
      with: always("private_key")
    )
    patch(
      environment: \.pgp.verifyPassphrase,
      with: always(.success(Void()))
    )
    patch(
      \SessionState.account,
      with: always(.none)
    )
    patch(
      \AccountsDataStore.loadAccountMFAToken,
      with: always(.none)
    )
    patch(
      \SessionNetworkAuthorization.createSessionTokens,
      with: always(
        (
          tokens: (
            accessToken: SessionAccessToken.valid,
            refreshToken: "refresh_token" as SessionRefreshToken
          ),
          requiredMFAProviders: [] as Array<SessionMFAProvider>
        )
      )
    )
    patch(
      \AccountsDataStore.storeLastUsedAccount,
      with: always(Void())
    )
    patch(
      \SessionState.setAccount,
      with: always(Void())
    )
    patch(
      \SessionState.setPassphrase,
      with: always(Void())
    )
    patch(
      \SessionState.setMFAToken,
      with: always(Void())
    )
    patch(
      \SessionState.setAccessToken,
      with: always(Void())
    )
    patch(
      \SessionState.setRefreshToken,
      with: always(Void())
    )
    patch(
      \SessionLocking.ensureAutolock,
      context: .valid,
      with: always(Void())
    )

    withTestedInstanceNotThrows { (testedInstance: SessionAuthorization) in
      try await testedInstance.authorize(.biometrics(.valid))
    }
  }

  func test_authorize_biometrics_storesLastUsedAccount_whenCreatingSessionSucceeds() {
    patch(
      \AccountsDataStore.loadAccountPassphrase,
      with: always("passphrase")
    )
    patch(
      \AccountsDataStore.loadAccountPrivateKey,
      with: always("private_key")
    )
    patch(
      environment: \.pgp.verifyPassphrase,
      with: always(.success(Void()))
    )
    patch(
      \SessionState.account,
      with: always(.none)
    )
    patch(
      \AccountsDataStore.loadAccountMFAToken,
      with: always(.none)
    )
    patch(
      \SessionNetworkAuthorization.createSessionTokens,
      with: always(
        (
          tokens: (
            accessToken: SessionAccessToken.valid,
            refreshToken: "refresh_token" as SessionRefreshToken
          ),
          requiredMFAProviders: [] as Array<SessionMFAProvider>
        )
      )
    )
    patch(
      \AccountsDataStore.storeLastUsedAccount,
      with: {
        self.executed(using: $0)
      }
    )
    patch(
      \SessionState.setAccount,
      with: always(Void())
    )
    patch(
      \SessionState.setPassphrase,
      with: always(Void())
    )
    patch(
      \SessionState.setMFAToken,
      with: always(Void())
    )
    patch(
      \SessionState.setAccessToken,
      with: always(Void())
    )
    patch(
      \SessionState.setRefreshToken,
      with: always(Void())
    )
    patch(
      \SessionLocking.ensureAutolock,
      context: .valid,
      with: always(Void())
    )

    withTestedInstanceExecuted(
      using: Account.valid.localID
    ) { (testedInstance: SessionAuthorization) in
      try await testedInstance.authorize(.biometrics(.valid))
    }
  }

  func test_authorize_biometrics_updatesSessionState_whenCreatingSessionSucceeds() {
    patch(
      \AccountsDataStore.loadAccountPassphrase,
      with: always("passphrase")
    )
    patch(
      \AccountsDataStore.loadAccountPrivateKey,
      with: always("private_key")
    )
    patch(
      environment: \.pgp.verifyPassphrase,
      with: always(.success(Void()))
    )
    patch(
      \SessionState.account,
      with: always(.none)
    )
    patch(
      \AccountsDataStore.loadAccountMFAToken,
      with: always("mfa_token")
    )
    patch(
      \SessionNetworkAuthorization.createSessionTokens,
      with: always(
        (
          tokens: (
            accessToken: SessionAccessToken.valid,
            refreshToken: "refresh_token" as SessionRefreshToken
          ),
          requiredMFAProviders: [] as Array<SessionMFAProvider>
        )
      )
    )
    patch(
      \AccountsDataStore.storeLastUsedAccount,
      with: always(Void())
    )
    let account: UncheckedSendable<Account?> = .init(.none)
    patch(
      \SessionState.setAccount,
      with: { account.variable = $0 }
    )
    let passphrase: UncheckedSendable<Passphrase?> = .init(.none)
    patch(
      \SessionState.setPassphrase,
      with: { passphrase.variable = $0 }
    )
    let mfaToken: UncheckedSendable<SessionMFAToken?> = .init(.none)
    patch(
      \SessionState.setMFAToken,
      with: { mfaToken.variable = $0 }
    )
    let accessToken: UncheckedSendable<SessionAccessToken?> = .init(.none)
    patch(
      \SessionState.setAccessToken,
      with: { accessToken.variable = $0 }
    )
    let refreshToken: UncheckedSendable<SessionRefreshToken?> = .init(.none)
    patch(
      \SessionState.setRefreshToken,
      with: { refreshToken.variable = $0 }
    )
    patch(
      \SessionLocking.ensureAutolock,
      context: .valid,
      with: always(Void())
    )

    withTestedInstance { (testedInstance: SessionAuthorization) in
      try await testedInstance.authorize(.biometrics(.valid))
      XCTAssertEqual(account.variable, .valid)
      XCTAssertEqual(passphrase.variable, "passphrase")
      XCTAssertEqual(mfaToken.variable, "mfa_token")
      XCTAssertEqual(accessToken.variable, .valid)
      XCTAssertEqual(refreshToken.variable, "refresh_token")
    }
  }

  func test_authorize_biometrics_enablesSessionLocking_whenCreatingSessionSucceeds() {
    patch(
      \AccountsDataStore.loadAccountPassphrase,
      with: always("passphrase")
    )
    patch(
      \AccountsDataStore.loadAccountPrivateKey,
      with: always("private_key")
    )
    patch(
      environment: \.pgp.verifyPassphrase,
      with: always(.success(Void()))
    )
    patch(
      \SessionState.account,
      with: always(.none)
    )
    patch(
      \AccountsDataStore.loadAccountMFAToken,
      with: always(.none)
    )
    patch(
      \SessionNetworkAuthorization.createSessionTokens,
      with: always(
        (
          tokens: (
            accessToken: SessionAccessToken.valid,
            refreshToken: "refresh_token" as SessionRefreshToken
          ),
          requiredMFAProviders: [] as Array<SessionMFAProvider>
        )
      )
    )
    patch(
      \AccountsDataStore.storeLastUsedAccount,
      with: always(Void())
    )
    patch(
      \SessionState.setAccount,
      with: always(Void())
    )
    patch(
      \SessionState.setPassphrase,
      with: always(Void())
    )
    patch(
      \SessionState.setMFAToken,
      with: always(Void())
    )
    patch(
      \SessionState.setAccessToken,
      with: always(Void())
    )
    patch(
      \SessionState.setRefreshToken,
      with: always(Void())
    )
    patch(
      \SessionLocking.ensureAutolock,
      context: .valid,
      with: always(self.executed())
    )

    withTestedInstanceExecuted { (testedInstance: SessionAuthorization) in
      try await testedInstance.authorize(.biometrics(.valid))
    }
  }

  func test_authorize_biometrics_fails_whenMFAAuthorizationPending() {
    patch(
      \AccountsDataStore.loadAccountPassphrase,
      with: always("passphrase")
    )
    patch(
      \AccountsDataStore.loadAccountPrivateKey,
      with: always("private_key")
    )
    patch(
      environment: \.pgp.verifyPassphrase,
      with: always(.success(Void()))
    )
    patch(
      \SessionState.account,
      with: always(.valid)
    )
    patch(
      \AccountsDataStore.loadAccountMFAToken,
      with: always(.none)
    )
    patch(
      \SessionNetworkAuthorization.refreshSessionTokens,
      with: always(
        (
          accessToken: SessionAccessToken.valid,
          refreshToken: "refresh_token" as SessionRefreshToken
        )
      )
    )
    patch(
      \SessionAuthorizationState.pendingAuthorization,
      with: always(.mfa(.valid, providers: .init()))
    )
    patch(
      \AccountsDataStore.deleteAccountMFAToken,
      with: always(Void())
    )

    withTestedInstanceThrows(
      SessionMFAAuthorizationRequired.self
    ) { (testedInstance: SessionAuthorization) in
      try await testedInstance.authorize(.biometrics(.valid))
    }
  }

  func test_authorize_biometrics_clearsStoredMFA_whenMFAAuthorizationPending() {
    patch(
      \AccountsDataStore.loadAccountPassphrase,
      with: always("passphrase")
    )
    patch(
      \AccountsDataStore.loadAccountPrivateKey,
      with: always("private_key")
    )
    patch(
      environment: \.pgp.verifyPassphrase,
      with: always(.success(Void()))
    )
    patch(
      \SessionState.account,
      with: always(.valid)
    )
    patch(
      \AccountsDataStore.loadAccountMFAToken,
      with: always(.none)
    )
    patch(
      \SessionNetworkAuthorization.refreshSessionTokens,
      with: always(
        (
          accessToken: SessionAccessToken.valid,
          refreshToken: "refresh_token" as SessionRefreshToken
        )
      )
    )
    patch(
      \SessionAuthorizationState.pendingAuthorization,
      with: always(.mfa(.valid, providers: .init()))
    )
    patch(
      \AccountsDataStore.deleteAccountMFAToken,
      with: self.executed(using:)
    )

    withTestedInstanceExecuted(
      using: Account.valid.localID
    ) { (testedInstance: SessionAuthorization) in
      // ignore error
      try? await testedInstance.authorize(.biometrics(.valid))
    }
  }

  func test_authorize_biometrics_succeedsWithoutRequests_whenCurrentTokenIsValid() {
    patch(
      \AccountsDataStore.loadAccountPassphrase,
      with: always("passphrase")
    )
    patch(
      \AccountsDataStore.loadAccountPrivateKey,
      with: always("private_key")
    )
    patch(
      environment: \.pgp.verifyPassphrase,
      with: always(.success(Void()))
    )
    patch(
      \SessionState.account,
      with: always(.valid)
    )
    patch(
      \AccountsDataStore.loadAccountMFAToken,
      with: always(.none)
    )
    patch(
      \SessionNetworkAuthorization.refreshSessionTokens,
      with: always(
        (
          accessToken: SessionAccessToken.valid,
          refreshToken: "refresh_token" as SessionRefreshToken
        )
      )
    )
    patch(
      \SessionAuthorizationState.pendingAuthorization,
      with: always(.mfa(.validAlternative, providers: .init()))
    )
    patch(
      \SessionState.mfaToken,
      with: always("mfa_token")
    )
    patch(
      \SessionState.validAccessToken,
      with: always(.valid)
    )
    patch(
      \OSTime.timestamp,
      with: always(0)
    )
    patch(
      \SessionState.setPassphrase,
      with: always(Void())
    )
    withTestedInstanceNotThrows { (testedInstance: SessionAuthorization) in
      try await testedInstance.authorize(.biometrics(.valid))
    }
  }

  func test_authorize_biometrics_refreshesSession_whenRefreshIsAvailable() {
    patch(
      \AccountsDataStore.loadAccountPassphrase,
      with: always("passphrase")
    )
    patch(
      \AccountsDataStore.loadAccountPrivateKey,
      with: always("private_key")
    )
    patch(
      environment: \.pgp.verifyPassphrase,
      with: always(.success(Void()))
    )
    patch(
      \SessionState.account,
      with: always(.valid)
    )
    patch(
      \AccountsDataStore.loadAccountMFAToken,
      with: always(.none)
    )
    patch(
      \SessionNetworkAuthorization.refreshSessionTokens,
      with: always(
        (
          accessToken: SessionAccessToken.valid,
          refreshToken: "refresh_token" as SessionRefreshToken
        )
      )
    )
    patch(
      \SessionAuthorizationState.pendingAuthorization,
      with: always(.mfa(.validAlternative, providers: .init()))
    )
    patch(
      \SessionState.mfaToken,
      with: always("mfa_token")
    )
    patch(
      \SessionState.validAccessToken,
      with: always(.none)
    )
    patch(
      \SessionState.refreshToken,
      with: always("refresh_token")
    )
    patch(
      \SessionState.setPassphrase,
      with: always(Void())
    )
    patch(
      \SessionState.setMFAToken,
      with: always(Void())
    )
    patch(
      \SessionState.setAccessToken,
      with: always(Void())
    )
    patch(
      \SessionState.setRefreshToken,
      with: always(Void())
    )

    withTestedInstance { (testedInstance: SessionAuthorization) in
      try await testedInstance.authorize(.biometrics(.valid))
    }
  }

  func test_authorize_biometrics_createsSession_whenRefreshFails() {
    patch(
      \AccountsDataStore.loadAccountPassphrase,
      with: always("passphrase")
    )
    patch(
      \AccountsDataStore.loadAccountPrivateKey,
      with: always("private_key")
    )
    patch(
      environment: \.pgp.verifyPassphrase,
      with: always(.success(Void()))
    )
    patch(
      \SessionState.account,
      with: always(.valid)
    )
    patch(
      \AccountsDataStore.loadAccountMFAToken,
      with: always(.none)
    )
    patch(
      \SessionNetworkAuthorization.refreshSessionTokens,
      with: alwaysThrow(MockIssue.error())
    )
    patch(
      \SessionNetworkAuthorization.createSessionTokens,
      with: always(
        (
          tokens: (
            accessToken: SessionAccessToken.valid,
            refreshToken: "refresh_token" as SessionRefreshToken
          ),
          requiredMFAProviders: [] as Array<SessionMFAProvider>
        )
      )
    )
    patch(
      \SessionAuthorizationState.pendingAuthorization,
      with: always(.mfa(.validAlternative, providers: .init()))
    )
    patch(
      \SessionState.mfaToken,
      with: always("mfa_token")
    )
    patch(
      \SessionState.validAccessToken,
      with: always(.none)
    )
    patch(
      \SessionState.refreshToken,
      with: always("refresh_token")
    )
    patch(
      \AccountsDataStore.storeLastUsedAccount,
      with: always(Void())
    )
    patch(
      \SessionState.setAccount,
      with: always(Void())
    )
    patch(
      \SessionState.setPassphrase,
      with: always(Void())
    )
    patch(
      \SessionState.setMFAToken,
      with: always(Void())
    )
    patch(
      \SessionState.setAccessToken,
      with: always(Void())
    )
    patch(
      \SessionState.setRefreshToken,
      with: always(Void())
    )
    patch(
      \SessionLocking.ensureAutolock,
      context: .valid,
      with: always(Void())
    )

    withTestedInstance { (testedInstance: SessionAuthorization) in
      try await testedInstance.authorize(.biometrics(.valid))
    }
  }

  func test_authorize_biometrics_createsSession_whenRefreshIsUnavailable() {
    patch(
      \AccountsDataStore.loadAccountPassphrase,
      with: always("passphrase")
    )
    patch(
      \AccountsDataStore.loadAccountPrivateKey,
      with: always("private_key")
    )
    patch(
      environment: \.pgp.verifyPassphrase,
      with: always(.success(Void()))
    )
    patch(
      \SessionState.account,
      with: always(.valid)
    )
    patch(
      \AccountsDataStore.loadAccountMFAToken,
      with: always(.none)
    )
    patch(
      \SessionNetworkAuthorization.refreshSessionTokens,
      with: always(
        (
          accessToken: SessionAccessToken.valid,
          refreshToken: "refresh_token" as SessionRefreshToken
        )
      )
    )
    patch(
      \SessionAuthorizationState.pendingAuthorization,
      with: always(.mfa(.validAlternative, providers: .init()))
    )
    patch(
      \SessionState.mfaToken,
      with: always("mfa_token")
    )
    patch(
      \SessionState.validAccessToken,
      with: always(.none)
    )
    patch(
      \SessionState.refreshToken,
      with: always(.none)
    )
    patch(
      \SessionNetworkAuthorization.createSessionTokens,
      with: always(
        (
          tokens: (
            accessToken: SessionAccessToken.valid,
            refreshToken: "refresh_token" as SessionRefreshToken
          ),
          requiredMFAProviders: [] as Array<SessionMFAProvider>
        )
      )
    )
    patch(
      \AccountsDataStore.storeLastUsedAccount,
      with: always(Void())
    )
    patch(
      \SessionState.setAccount,
      with: always(Void())
    )
    patch(
      \SessionState.setPassphrase,
      with: always(Void())
    )
    patch(
      \SessionState.setMFAToken,
      with: always(Void())
    )
    patch(
      \SessionState.setAccessToken,
      with: always(Void())
    )
    patch(
      \SessionState.setRefreshToken,
      with: always(Void())
    )
    patch(
      \SessionLocking.ensureAutolock,
      context: .valid,
      with: always(self.executed())
    )

    withTestedInstanceExecuted { (testedInstance: SessionAuthorization) in
      try await testedInstance.authorize(.biometrics(.valid))
    }
  }

  func test_refreshTokens_throws_withoutSession() {
    patch(
      \AccountsDataStore.loadAccountPrivateKey,
      with: always("private_key")
    )
    patch(
      environment: \.pgp.verifyPassphrase,
      with: always(.success(Void()))
    )
    patch(
      \SessionState.account,
      with: always(.validAlternative)
    )
    patch(
      \AccountsDataStore.loadAccountMFAToken,
      with: always(.none)
    )
    patch(
      \SessionNetworkAuthorization.refreshSessionTokens,
      with: alwaysThrow(MockIssue.error())
    )

    withTestedInstanceThrows(
      SessionClosed.self
    ) { (testedInstance: SessionAuthorization) in
      try await testedInstance.refreshTokens(.valid, "passphrase")
    }
  }

  func test_refreshTokens_updatesSessionState_whenRefreshSucceeds() {
    patch(
      \AccountsDataStore.loadAccountPrivateKey,
      with: always("private_key")
    )
    patch(
      environment: \.pgp.verifyPassphrase,
      with: always(.success(Void()))
    )
    patch(
      \SessionState.account,
      with: always(.validAlternative)
    )
    patch(
      \AccountsDataStore.loadAccountMFAToken,
      with: always(.none)
    )

    withTestedInstanceThrows(
      SessionClosed.self
    ) { (testedInstance: SessionAuthorization) in
      try await testedInstance.refreshTokens(.valid, "passphrase")
    }
  }

  func test_refreshTokens_createsNewSession_whenRefreshFails() {
    patch(
      \AccountsDataStore.loadAccountPassphrase,
      with: always("passphrase")
    )
    patch(
      \AccountsDataStore.loadAccountPrivateKey,
      with: always("private_key")
    )
    patch(
      environment: \.pgp.verifyPassphrase,
      with: always(.success(Void()))
    )
    patch(
      \SessionState.account,
      with: always(.valid)
    )
    patch(
      \AccountsDataStore.loadAccountMFAToken,
      with: always(.none)
    )
    patch(
      \SessionNetworkAuthorization.refreshSessionTokens,
      with: alwaysThrow(MockIssue.error())
    )
    patch(
      \SessionNetworkAuthorization.createSessionTokens,
      with: always(
        self.executed(
          returning: (
            tokens: (
              accessToken: SessionAccessToken.valid,
              refreshToken: "refresh_token" as SessionRefreshToken
            ),
            requiredMFAProviders: [] as Array<SessionMFAProvider>
          )
        )
      )
    )
    patch(
      \SessionAuthorizationState.pendingAuthorization,
      with: always(.mfa(.validAlternative, providers: .init()))
    )
    patch(
      \SessionState.mfaToken,
      with: always("mfa_token")
    )
    patch(
      \SessionState.validAccessToken,
      with: always(.none)
    )
    patch(
      \SessionState.refreshToken,
      with: always("refresh_token")
    )
    patch(
      \AccountsDataStore.storeLastUsedAccount,
      with: always(Void())
    )
    patch(
      \SessionState.setAccount,
      with: always(Void())
    )
    patch(
      \SessionState.setPassphrase,
      with: always(Void())
    )
    patch(
      \SessionState.setMFAToken,
      with: always(Void())
    )
    patch(
      \SessionState.setAccessToken,
      with: always(Void())
    )
    patch(
      \SessionState.setRefreshToken,
      with: always(Void())
    )
    patch(
      \SessionLocking.ensureAutolock,
      context: .valid,
      with: always(Void())
    )

    withTestedInstanceExecuted { (testedInstance: SessionAuthorization) in
      try await testedInstance.refreshTokens(.valid, "passphrase")
    }
  }

  func test_authorize_biometrics_throws_whenCreatingSessionSucceedsWithMFARequired() {
    patch(
      \AccountsDataStore.loadAccountPassphrase,
      with: always("passphrase")
    )
    patch(
      \AccountsDataStore.loadAccountPrivateKey,
      with: always("private_key")
    )
    patch(
      environment: \.pgp.verifyPassphrase,
      with: always(.success(Void()))
    )
    patch(
      \SessionState.account,
      with: always(.none)
    )
    patch(
      \AccountsDataStore.loadAccountMFAToken,
      with: always("mfa_token")
    )
    patch(
      \SessionNetworkAuthorization.createSessionTokens,
      with: always(
        (
          tokens: (
            accessToken: SessionAccessToken.valid,
            refreshToken: "refresh_token" as SessionRefreshToken
          ),
          requiredMFAProviders: [.yubiKey] as Array<SessionMFAProvider>
        )
      )
    )
    patch(
      \AccountsDataStore.storeLastUsedAccount,
      with: always(Void())
    )
    patch(
      \SessionState.setAccount,
      with: always(Void())
    )
    patch(
      \SessionState.setPassphrase,
      with: always(Void())
    )
    patch(
      \SessionState.setMFAToken,
      with: always(Void())
    )
    patch(
      \SessionState.setAccessToken,
      with: always(Void())
    )
    patch(
      \SessionState.setRefreshToken,
      with: always(Void())
    )
    patch(
      \SessionLocking.ensureAutolock,
      context: .valid,
      with: always(Void())
    )
    patch(
      \AccountsDataStore.deleteAccountMFAToken,
      with: always(Void())
    )

    withTestedInstanceThrows(
      SessionMFAAuthorizationRequired.self
    ) { (testedInstance: SessionAuthorization) in
      try await testedInstance.authorize(.biometrics(.valid))
    }
  }
}
