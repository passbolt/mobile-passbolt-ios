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
final class SessionAuthorizationStateTests: LoadableFeatureTestCase<SessionAuthorizationState> {

  override class var testedImplementationRegister: (FeatureFactory) -> @MainActor () -> Void {
    FeatureFactory.usePassboltSessionAuthorizationState
  }

  override func prepare() throws {
    use(SessionState.placeholder)
  }

  func test_pendingAuthorization_returnsNone_withoutAuthorizationRequest() {
    withTestedInstanceReturnsNone { (testedInstance: SessionAuthorizationState) in
      await testedInstance.pendingAuthorization()
    }
  }

  func test_pendingAuthorization_returnsNone_duringAuthorizationWithoutAuthorizationRequestAndSession() {
    patch(
      \SessionState.account,
      with: always(.none)
    )
    patch(
      \SessionState.passphrase,
      with: always(.none)
    )
    patch(
      \SessionState.mfaToken,
      with: always(.none)
    )

    withTestedInstanceResultNone { (testedInstance: SessionAuthorizationState) in
      try await testedInstance.performAuthorization(.mock_ada) {
        self.result = await testedInstance.pendingAuthorization()
      }
    }
  }

  func test_pendingAuthorization_returnsNone_afterAuthorizationWithoutSession() {
    patch(
      \SessionState.account,
      with: always(.none)
    )
    patch(
      \SessionState.passphrase,
      with: always(.none)
    )
    patch(
      \SessionState.mfaToken,
      with: always(.none)
    )

    withTestedInstanceReturnsNone { (testedInstance: SessionAuthorizationState) in
      try await testedInstance.performAuthorization(.mock_ada) {}
      return await testedInstance.pendingAuthorization()
    }
  }

  func test_pendingAuthorization_returnsPassphraseRequest_afterRequestingPassphraseAuthorization() {
    patch(
      \SessionState.account,
      with: always(.mock_ada)
    )

    withTestedInstanceReturnsEqual(
      SessionAuthorizationRequest.passphrase(.mock_ada)
    ) { (testedInstance: SessionAuthorizationState) in
      try await testedInstance.requestAuthorization(.passphrase(.mock_ada))
      return await testedInstance.pendingAuthorization()
    }
  }

  func test_pendingAuthorization_returnsMFARequest_afterRequestingMFAAuthorization() {
    patch(
      \SessionState.account,
      with: always(.mock_ada)
    )

    withTestedInstanceReturnsEqual(
      SessionAuthorizationRequest.mfa(.mock_ada, providers: .init())
    ) { (testedInstance: SessionAuthorizationState) in
      try await testedInstance.requestAuthorization(.mfa(.mock_ada, providers: .init()))
      return await testedInstance.pendingAuthorization()
    }
  }

  func
    test_pendingAuthorization_returnsPassphraseRequest_afterRequestingMFAAuthorizationWhenPassphraseWasAlreadyRequested()
  {
    patch(
      \SessionState.account,
      with: always(.mock_ada)
    )

    withTestedInstanceReturnsEqual(
      SessionAuthorizationRequest.passphrase(.mock_ada)
    ) { (testedInstance: SessionAuthorizationState) in
      try await testedInstance.requestAuthorization(.passphrase(.mock_ada))
      try await testedInstance.requestAuthorization(.mfa(.mock_ada, providers: .init()))
      return await testedInstance.pendingAuthorization()
    }
  }

  func
    test_pendingAuthorization_returnsPassphraseRequest_afterRequestingPassphraseAuthorizationWhenMFAWasAlreadyRequested()
  {
    patch(
      \SessionState.account,
      with: always(.mock_ada)
    )

    withTestedInstanceReturnsEqual(
      SessionAuthorizationRequest.passphrase(.mock_ada)
    ) { (testedInstance: SessionAuthorizationState) in
      try await testedInstance.requestAuthorization(.mfa(.mock_ada, providers: .init()))
      try await testedInstance.requestAuthorization(.passphrase(.mock_ada))
      return await testedInstance.pendingAuthorization()
    }
  }

  func test_pendingAuthorization_returnsNone_afterRequestingPassphraseAuthorizationWithoutSession() {
    patch(
      \SessionState.account,
      with: always(.none)
    )

    withTestedInstanceReturnsNone { (testedInstance: SessionAuthorizationState) in
      try? await testedInstance.requestAuthorization(.passphrase(.mock_ada))
      return await testedInstance.pendingAuthorization()
    }
  }

  func test_requestAuthorization_throwsSessionClosed_withoutSession() {
    patch(
      \SessionState.account,
      with: always(.none)
    )

    withTestedInstanceThrows(
      SessionClosed.self
    ) { (testedInstance: SessionAuthorizationState) in
      try await testedInstance.requestAuthorization(.passphrase(.mock_ada))
    }
  }

  func test_requestAuthorization_throwsSessionClosed_withDifferentSession() {
    patch(
      \SessionState.account,
      with: always(.mock_frances)
    )

    withTestedInstanceThrows(
      SessionClosed.self
    ) { (testedInstance: SessionAuthorizationState) in
      try await testedInstance.requestAuthorization(.passphrase(.mock_ada))
    }
  }

  func test_requestAuthorization_setsPendingAuthorization_withTheSameSession() {
    patch(
      \SessionState.account,
      with: always(.mock_ada)
    )

    withTestedInstanceReturnsEqual(
      SessionAuthorizationRequest.passphrase(.mock_ada)
    ) { (testedInstance: SessionAuthorizationState) in
      try await testedInstance.requestAuthorization(.mfa(.mock_ada, providers: .init()))
      try await testedInstance.requestAuthorization(.passphrase(.mock_ada))
      return await testedInstance.pendingAuthorization()
    }
  }

  func test_cancelAuthorization_cancels_ongoingAuthorization() {
    patch(
      \SessionState.account,
      with: always(.none)
    )
    patch(
      \SessionState.passphrase,
      with: always(.none)
    )
    patch(
      \SessionState.mfaToken,
      with: always(.none)
    )

    withTestedInstanceThrows(
      CancellationError.self
    ) { (testedInstance: SessionAuthorizationState) in
      try await testedInstance.performAuthorization(.mock_ada) {
        await testedInstance.cancelAuthorization()
        try await Task.sleep(nanoseconds: NSEC_PER_SEC)
      }
    }
  }

  func test_performAuthorization_throws_onRecursion() {
    patch(
      \SessionState.account,
      with: always(.none)
    )
    patch(
      \SessionState.passphrase,
      with: always(.none)
    )
    patch(
      \SessionState.mfaToken,
      with: always(.none)
    )

    withTestedInstanceThrows(
      CancellationError.self
    ) { (testedInstance: SessionAuthorizationState) in
      try await testedInstance.performAuthorization(.mock_ada) {
        try await testedInstance.performAuthorization(.mock_ada) {
        }
      }
    }
  }

  func test_waitForAuthorizationIfNeeded_throwsSessionClosed_withoutSession() {
    patch(
      \SessionState.account,
      with: always(.none)
    )
    patch(
      \SessionState.passphrase,
      with: always(.none)
    )
    patch(
      \SessionState.mfaToken,
      with: always(.none)
    )

    withTestedInstanceThrows(
      SessionClosed.self
    ) { (testedInstance: SessionAuthorizationState) in
      try await testedInstance.waitForAuthorizationIfNeeded(.passphrase(.mock_ada))
    }
  }

  func test_waitForAuthorizationIfNeeded_throwsSessionClosed_withDifferentSession() {
    patch(
      \SessionState.account,
      with: always(.mock_frances)
    )
    patch(
      \SessionState.passphrase,
      with: always(.none)
    )
    patch(
      \SessionState.mfaToken,
      with: always(.none)
    )

    withTestedInstanceThrows(
      SessionClosed.self
    ) { (testedInstance: SessionAuthorizationState) in
      try await testedInstance.waitForAuthorizationIfNeeded(.passphrase(.mock_ada))
    }
  }

  func test_waitForAuthorizationIfNeeded_doesNothing_whenRequestingPassphraseAndPassphraseIsAvailable() {
    patch(
      \SessionState.account,
      with: always(.mock_ada)
    )
    patch(
      \SessionState.passphrase,
      with: always("passphrase")
    )
    patch(
      \SessionState.mfaToken,
      with: always(.none)
    )

    withTestedInstanceReturnsNone { (testedInstance: SessionAuthorizationState) in
      try await testedInstance.waitForAuthorizationIfNeeded(.passphrase(.mock_ada))
      return await testedInstance.pendingAuthorization()
    }
  }

  func test_waitForAuthorizationIfNeeded_doesNothing_whenRequestingMFAAndMFAIsAvailable() {
    patch(
      \SessionState.account,
      with: always(.mock_ada)
    )
    patch(
      \SessionState.passphrase,
      with: always(.none)
    )
    patch(
      \SessionState.mfaToken,
      with: always("token")
    )

    withTestedInstanceReturnsNone { (testedInstance: SessionAuthorizationState) in
      try await testedInstance.waitForAuthorizationIfNeeded(.mfa(.mock_ada, providers: .init()))
      return await testedInstance.pendingAuthorization()
    }
  }

  func test_waitForAuthorizationIfNeeded_doesNotHang_duringAuthorization() {
    patch(
      \SessionState.account,
      with: always(.mock_ada)
    )
    patch(
      \SessionState.passphrase,
      with: always(.none)
    )
    patch(
      \SessionState.mfaToken,
      with: always(.none)
    )

    withTestedInstance { (testedInstance: SessionAuthorizationState) in
      try await testedInstance.performAuthorization(.mock_ada) {
        try await testedInstance.waitForAuthorizationIfNeeded(.mfa(.mock_ada, providers: .init()))
      }
    }
  }
}
