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
final class SessionTests: LoadableFeatureTestCase<Session> {

  override class var testedImplementationRegister: (FeatureFactory) -> @MainActor () -> Void {
    FeatureFactory.usePassboltSession
  }

  override func prepare() throws {
    use(SessionState.placeholder)
    use(SessionAuthorizationState.placeholder)
    use(SessionAuthorization.placeholder)
    use(SessionMFAAuthorization.placeholder)
    use(SessionNetworkAuthorization.placeholder)
  }

  func test_currentAccount_throwsSessionMissing_whenSessionStateHoldsNoAccount() {
    patch(
      \SessionState.account,
      with: always(.none)
    )

    withTestedInstanceThrows(SessionMissing.self) { (testedInstance: Session) in
      try await testedInstance.currentAccount()
    }
  }

  func test_currentAccount_returnsAccount_whenSessionStateHoldsAccount() {
    patch(
      \SessionState.account,
      with: always(self.account)
    )

    self.account = Account.valid
    withTestedInstanceReturnsEqual(self.account) { (testedInstance: Session) in
      try await testedInstance.currentAccount()
    }
  }

  func test_pendingAuthorization_returnsValueFromSessionAuthorizationState() {
    patch(
      \SessionAuthorizationState.pendingAuthorization,
      with: always(self.pendingAuthorization)
    )

    self.pendingAuthorization = Optional<SessionAuthorizationRequest>.none
    withTestedInstanceReturnsNone { (testedInstance: Session) in
      await testedInstance.pendingAuthorization()
    }

    self.pendingAuthorization = SessionAuthorizationRequest.passphrase(Account.valid)
    withTestedInstanceReturnsEqual(self.pendingAuthorization) { (testedInstance: Session) in
      return await testedInstance.pendingAuthorization()
    }
  }

  func test_authorize_performsUsingSessionAuthorizationStatePerformAuthorization() {
    patch(
      \SessionAuthorizationState.performAuthorization,
      with: always(self.executed())
    )

    withTestedInstanceExecuted { (testedInstance: Session) in
      try await testedInstance.authorize(
        .adHoc(
          Account.valid,
          "passphrase",
          "armoredPGPKey"
        )
      )
    }
  }

  func test_authorize_performsUsingRequestedAccount() {
    patch(
      \SessionAuthorizationState.performAuthorization,
      with: { account, _ in
        self.result = account
      }
    )

    withTestedInstanceResultEqual(Account.valid) { (testedInstance: Session) in
      try await testedInstance.authorize(
        .adHoc(
          Account.valid,
          "passphrase",
          "armoredPGPKey"
        )
      )
    }
  }

  func test_authorize_performsUsingSessionAuthorizationAuthorize() {
    patch(
      \SessionAuthorizationState.performAuthorization,
      with: { _, authorize in
        try await authorize()
      }
    )
    patch(
      \SessionAuthorization.authorize,
      with: always(self.executed())
    )

    withTestedInstanceExecuted { (testedInstance: Session) in
      try await testedInstance.authorize(
        .adHoc(
          Account.valid,
          "passphrase",
          "armoredPGPKey"
        )
      )
    }
  }

  func test_authorize_fails_whenSessionAuthorizationAuthorizeFails() {
    patch(
      \SessionAuthorizationState.performAuthorization,
      with: { _, authorize in
        try await authorize()
      }
    )
    patch(
      \SessionAuthorization.authorize,
      with: alwaysThrow(MockIssue.error())
    )

    withTestedInstanceThrows(MockIssue.self) { (testedInstance: Session) in
      try await testedInstance.authorize(
        .adHoc(
          Account.valid,
          "passphrase",
          "armoredPGPKey"
        )
      )
    }
  }

  func test_authorizeMFA_performsUsingSessionAuthorizationStatePerformAuthorization() {
    patch(
      \SessionAuthorizationState.performAuthorization,
      with: always(self.executed())
    )

    withTestedInstanceExecuted { (testedInstance: Session) in
      try await testedInstance.authorizeMFA(
        .totp(
          Account.valid,
          "totp",
          rememberDevice: false
        )
      )
    }
  }

  func test_authorizeMFA_performsUsingRequestedAccount() {
    patch(
      \SessionAuthorizationState.performAuthorization,
      with: { account, _ in
        self.result = account
      }
    )

    withTestedInstanceResultEqual(Account.valid) { (testedInstance: Session) in
      try await testedInstance.authorizeMFA(
        .totp(
          Account.valid,
          "totp",
          rememberDevice: false
        )
      )
    }
  }

  func test_authorizeMFA_performsUsingSessionMFAAuthorizationAuthorizeMFA() {
    patch(
      \SessionAuthorizationState.performAuthorization,
      with: { _, authorize in
        try await authorize()
      }
    )
    patch(
      \SessionMFAAuthorization.authorizeMFA,
      with: always(self.executed())
    )

    withTestedInstanceExecuted { (testedInstance: Session) in
      try await testedInstance.authorizeMFA(
        .totp(
          Account.valid,
          "totp",
          rememberDevice: false
        )
      )
    }
  }

  func test_authorizeMFA_fails_whenSessionMFAAuthorizationAuthorizeMFAFails() {
    patch(
      \SessionAuthorizationState.performAuthorization,
      with: { _, authorize in
        try await authorize()
      }
    )
    patch(
      \SessionMFAAuthorization.authorizeMFA,
      with: alwaysThrow(MockIssue.error())
    )

    withTestedInstanceThrows(MockIssue.self) { (testedInstance: Session) in
      try await testedInstance.authorizeMFA(
        .totp(
          Account.valid,
          "totp",
          rememberDevice: false
        )
      )
    }
  }

  func test_close_doesNothing_whenNoOrDifferentAccount() {
    patch(
      \SessionState.account,
      with: always(self.account)
    )

    self.account = Optional<Account>.none
    withTestedInstance { (testedInstance: Session) in
      await testedInstance.close(Account.valid)
    }

    self.account = Account.validAlternative
    withTestedInstance { (testedInstance: Session) in
      await testedInstance.close(Account.valid)
    }
  }

  func test_close_cancelsOngoingAuthorization_whenClosingSession() {
    patch(
      \SessionState.account,
      with: always(.valid)
    )
    patch(
      \SessionState.refreshToken,
      with: always(.none)
    )
    patch(
      \SessionState.setAccount,
      with: always(Void())
    )
    patch(
      \SessionAuthorizationState.cancelAuthorization,
      with: always(self.executed())
    )

    withTestedInstanceExecuted { (testedInstance: Session) in
      await testedInstance.close(.none)
    }
  }

  func test_close_invalidatesTokens_whenRefreshTokenAvailable() {
    patch(
      \SessionState.account,
      with: always(.valid)
    )
    patch(
      \SessionState.refreshToken,
      with: always(self.refreshToken)
    )
    patch(
      \SessionState.setAccount,
      with: always(Void())
    )
    patch(
      \SessionAuthorizationState.cancelAuthorization,
      with: always(Void())
    )
    patch(
      \SessionNetworkAuthorization.invalidateSessionTokens,
      with: always(self.executed())
    )

    self.refreshToken = Optional<SessionRefreshToken>.none
    withTestedInstanceNotExecuted { (testedInstance: Session) in
      await testedInstance.close(.none)
    }

    self.refreshToken = "SessionRefreshToken" as SessionRefreshToken
    withTestedInstanceExecuted { (testedInstance: Session) in
      await testedInstance.close(.none)
    }
  }

  func test_close_clearsCurrentAccount_whenClosingSession() {
    patch(
      \SessionState.account,
      with: always(.valid)
    )
    patch(
      \SessionState.refreshToken,
      with: always(.none)
    )
    patch(
      \SessionState.setAccount,
      with: { account in
        self.result = account
      }
    )
    patch(
      \SessionAuthorizationState.cancelAuthorization,
      with: always(Void())
    )

    withTestedInstanceResultEqual(Optional<Account>.none) { (testedInstance: Session) in
      await testedInstance.close(.none)
    }
  }
}