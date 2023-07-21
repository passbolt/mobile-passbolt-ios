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
final class SessionStateEnsuranceTests: LoadableFeatureTestCase<SessionStateEnsurance> {

  override class func testedImplementationRegister(
    _ registry: inout FeaturesRegistry
  ) {
    registry.usePassboltSessionStateEnsurance()
  }

  override func prepare() throws {
    use(SessionAuthorization.placeholder)
  }

  func test_passphrase_throws_withInvalidAuthorizationState() {
    patch(
      \SessionState.passphrase,
      with: always(.none)
    )
    patch(
      \SessionAuthorizationState.waitForAuthorizationIfNeeded,
      with: always(Void())
    )
    withTestedInstanceThrows(
      InternalInconsistency.self
    ) { (testedInstance: SessionStateEnsurance) in
      try await testedInstance.passphrase(.mock_ada)
    }
  }

  func test_passphrase_throws_whenWaitingForAuthorizationThrows() {
    patch(
      \SessionState.passphrase,
      with: always(.none)
    )
    patch(
      \SessionAuthorizationState.waitForAuthorizationIfNeeded,
      with: alwaysThrow(MockIssue.error())
    )
    withTestedInstanceThrows(
      MockIssue.self
    ) { (testedInstance: SessionStateEnsurance) in
      try await testedInstance.passphrase(.mock_ada)
    }
  }

  func test_passphrase_returnsPassphrase_whenAvailable() {
    patch(
      \SessionState.passphrase,
      with: always("passphrase")
    )
    patch(
      \SessionAuthorizationState.waitForAuthorizationIfNeeded,
      with: always(Void())
    )
    withTestedInstanceReturnsEqual(
      "passphrase" as Passphrase
    ) { (testedInstance: SessionStateEnsurance) in
      try await testedInstance.passphrase(.mock_ada)
    }
  }

  func test_passphrase_returnsPassphrase_afterSuccessfulWaitingForAuthorization() {
    self.currentPassphrase = Optional<Passphrase>.none
    patch(
      \SessionState.passphrase,
      with: always(self.currentPassphrase)
    )
    patch(
      \SessionAuthorizationState.waitForAuthorizationIfNeeded,
      with: { (_) async throws in
        self.currentPassphrase = "passphrase" as Passphrase
      }
    )
    withTestedInstanceReturnsEqual(
      "passphrase" as Passphrase
    ) { (testedInstance: SessionStateEnsurance) in
      try await testedInstance.passphrase(.mock_ada)
    }
  }

  func test_accessToken_throws_withInvalidAuthorizationState() {
    patch(
      \SessionState.passphrase,
      with: always(.none)
    )
    patch(
      \SessionState.validAccessToken,
      with: always(.none)
    )
    patch(
      \SessionAuthorizationState.waitForAuthorizationIfNeeded,
      with: always(Void())
    )
    withTestedInstanceThrows(
      InternalInconsistency.self
    ) { (testedInstance: SessionStateEnsurance) in
      try await testedInstance.accessToken(.mock_ada)
    }
  }

  func test_accessToken_throws_whenWaitingForAuthorizationThrows() {
    patch(
      \SessionState.validAccessToken,
      with: always(.none)
    )
    patch(
      \SessionAuthorizationState.waitForAuthorizationIfNeeded,
      with: alwaysThrow(MockIssue.error())
    )
    withTestedInstanceThrows(
      MockIssue.self
    ) { (testedInstance: SessionStateEnsurance) in
      try await testedInstance.accessToken(.mock_ada)
    }
  }

  func test_accessToken_returnsToken_whenAvailable() {
    patch(
      \SessionState.validAccessToken,
      with: always(.valid)
    )
    patch(
      \SessionAuthorizationState.waitForAuthorizationIfNeeded,
      with: always(Void())
    )
    withTestedInstanceReturnsEqual(
      SessionAccessToken.valid
    ) { (testedInstance: SessionStateEnsurance) in
      try await testedInstance.accessToken(.mock_ada)
    }
  }

  func test_accessToken_returnsToken_afterSuccessfulWaitingForAuthorization() {
    self.currentToken = Optional<SessionAccessToken>.none
    patch(
      \SessionState.validAccessToken,
      with: always(self.currentToken)
    )
    patch(
      \SessionAuthorizationState.waitForAuthorizationIfNeeded,
      with: { (_) async throws in
        self.currentToken = SessionAccessToken.valid
      }
    )
    withTestedInstanceReturnsEqual(
      SessionAccessToken.valid
    ) { (testedInstance: SessionStateEnsurance) in
      try await testedInstance.accessToken(.mock_ada)
    }
  }

  func test_accessToken_returnsToken_afterSuccessfulRefresh() {
    self.currentToken = Optional<SessionAccessToken>.none
    patch(
      \SessionState.validAccessToken,
      with: always(self.currentToken)
    )
    patch(
      \SessionState.passphrase,
      with: always("passphrase")
    )
    patch(
      \SessionAuthorization.refreshTokens,
      with: { (_, _) async throws in
        self.currentToken = SessionAccessToken.valid
      }
    )
    patch(
      \SessionAuthorizationState.waitForAuthorizationIfNeeded,
      with: always(Void())
    )
    patch(
      \SessionAuthorizationState.performAuthorization,
      with: { (_, authorization) async throws in
        try await authorization()
      }
    )
    withTestedInstanceReturnsEqual(
      SessionAccessToken.valid
    ) { (testedInstance: SessionStateEnsurance) in
      try await testedInstance.accessToken(.mock_ada)
    }
  }

  func test_accessToken_throws_whenRefreshingTokenFails() {
    patch(
      \SessionState.validAccessToken,
      with: always(.none)
    )
    patch(
      \SessionState.passphrase,
      with: always("passphrase")
    )
    patch(
      \SessionAuthorization.refreshTokens,
      with: alwaysThrow(MockIssue.error())
    )
    patch(
      \SessionAuthorizationState.waitForAuthorizationIfNeeded,
      with: always(Void())
    )
    patch(
      \SessionAuthorizationState.performAuthorization,
      with: { (_, authorization) async throws in
        try await authorization()
      }
    )
    withTestedInstanceThrows(
      MockIssue.self
    ) { (testedInstance: SessionStateEnsurance) in
      try await testedInstance.accessToken(.mock_ada)
    }
  }

  func test_accessToken_throws_whenAuthorizationFails() {
    patch(
      \SessionState.validAccessToken,
      with: always(.none)
    )
    patch(
      \SessionState.passphrase,
      with: always("passphrase")
    )
    patch(
      \SessionAuthorizationState.waitForAuthorizationIfNeeded,
      with: always(Void())
    )
    patch(
      \SessionAuthorizationState.performAuthorization,
      with: alwaysThrow(MockIssue.error())
    )
    withTestedInstanceThrows(
      MockIssue.self
    ) { (testedInstance: SessionStateEnsurance) in
      try await testedInstance.accessToken(.mock_ada)
    }
  }
}
