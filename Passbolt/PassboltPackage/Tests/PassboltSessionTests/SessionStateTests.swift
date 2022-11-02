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
import TestExtensions

@testable import PassboltSession

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class SessionStateTests: LoadableFeatureTestCase<SessionState> {

  override class var testedImplementationRegister: (FeatureFactory) -> @MainActor () -> Void {
    FeatureFactory.usePassboltSessionState
  }

  override func prepare() throws {
    patch(
      \OSTime.timestamp,
      with: always(self.timestamp)
    )
    self.timestamp = 0 as Timestamp
  }

  func test_account_isNone_initially() {
    withTestedInstanceReturnsNone { (testedInstance: SessionState) in
      await testedInstance.account()
    }
  }

  func test_passphrase_returnsSome_whenNotExpired() {
    withTestedInstanceReturnsEqual("passphrase" as Passphrase) { (testedInstance: SessionState) in
      await testedInstance.createdSession(
        .mock_ada,
        "passphrase",
        .valid,
        "refreshToken",
        "mfaToken",
        .init()
      )
      return await testedInstance.passphrase()
    }
  }

  func test_passphrase_returnsNone_whenExpired() {
    withTestedInstanceReturnsNone { (testedInstance: SessionState) in
      await testedInstance.createdSession(
        .mock_ada,
        "passphrase",
        .valid,
        "refreshToken",
        "mfaToken",
        .init()
      )
      self.timestamp = (5 * 60 * 60) as Timestamp
      return await testedInstance.passphrase()
    }
  }

  func test_accessToken_returnsSome_whenValid() {
    withTestedInstanceReturnsEqual(JWT.valid) { (testedInstance: SessionState) in
      await testedInstance.createdSession(
        .mock_ada,
        "passphrase",
        .valid,
        "refreshToken",
        "mfaToken",
        .init()
      )
      return await testedInstance.validAccessToken()
    }
  }

  func test_accessToken_returnsNone_whenExpired() {
    withTestedInstanceReturnsNone { (testedInstance: SessionState) in
      await testedInstance.createdSession(
        .mock_ada,
        "passphrase",
        .valid,
        "refreshToken",
        "mfaToken",
        .init()
      )
      self.timestamp = 2_000_000_000 as Timestamp
      return await testedInstance.validAccessToken()
    }
  }

  func test_refreshToken_returnsNone_whenAccessedMoreThanOnce() {
    withTestedInstanceReturnsNone { (testedInstance: SessionState) in
      await testedInstance.createdSession(
        .mock_ada,
        "passphrase",
        .valid,
        "refreshToken",
        "mfaToken",
        .init()
      )
      _ = await testedInstance.refreshToken()
      return await testedInstance.refreshToken()
    }
  }

  func test_createdSession_setsSessionState() {
    withTestedInstance { (testedInstance: SessionState) in
      await testedInstance.createdSession(
        .mock_ada,
        "passphrase",
        .valid,
        "token",
        .none,
        .init()
      )
      await XCTAssertValue(equal: .mock_ada) {
        await testedInstance.account()
      }
      await XCTAssertValue(equal: "passphrase") {
        await testedInstance.passphrase()
      }
      await XCTAssertValue(equal: .valid) {
        await testedInstance.validAccessToken()
      }
      await XCTAssertValue(equal: "token") {
        await testedInstance.refreshToken()
      }
      await XCTAssertValue(equal: .none) {
        await testedInstance.mfaToken()
      }
      await XCTAssertValue(equal: .none) {
        await testedInstance.pendingAuthorization()
      }
    }
  }

  func test_createdSession_setsPendingAuthorization_withRequiredMFAProviders() {
    withTestedInstance { (testedInstance: SessionState) in
      await testedInstance.createdSession(
        .mock_ada,
        "passphrase",
        .valid,
        "token",
        .none,
        [.totp]
      )
      await XCTAssertValue(equal: .mock_ada) {
        await testedInstance.account()
      }
      await XCTAssertValue(equal: "passphrase") {
        await testedInstance.passphrase()
      }
      await XCTAssertValue(equal: .valid) {
        await testedInstance.validAccessToken()
      }
      await XCTAssertValue(equal: "token") {
        await testedInstance.refreshToken()
      }
      await XCTAssertValue(equal: .none) {
        await testedInstance.mfaToken()
      }
      await XCTAssertValue(equal: SessionState.PendingAuthorization.mfa(for: .mock_ada, providers: [.totp])) {
        await testedInstance.pendingAuthorization()
      }
    }
  }

  func test_refreshedSession_throws_withoutSession() {
    withTestedInstanceThrows(
      SessionClosed.self
    ) { (testedInstance: SessionState) in
      try await testedInstance.refreshedSession(
        .mock_ada,
        "passphrase",
        .valid,
        "token",
        .none
      )
    }
  }

  func test_refreshedSession_updatesState_withSession() {
    withTestedInstance { (testedInstance: SessionState) in
      await testedInstance.createdSession(
        .mock_ada,
        "passphrase",
        .valid,
        "token",
        .none,
        .init()
      )
      try await testedInstance.refreshedSession(
        .mock_ada,
        "passphrase_update",
        .valid,
        "token_update",
        "mfa_update"
      )
      await XCTAssertValue(equal: .mock_ada) {
        await testedInstance.account()
      }
      await XCTAssertValue(equal: "passphrase_update") {
        await testedInstance.passphrase()
      }
      await XCTAssertValue(equal: .valid) {
        await testedInstance.validAccessToken()
      }
      await XCTAssertValue(equal: "token_update") {
        await testedInstance.refreshToken()
      }
      await XCTAssertValue(equal: "mfa_update") {
        await testedInstance.mfaToken()
      }
      await XCTAssertValue(equal: .none) {
        await testedInstance.pendingAuthorization()
      }
    }
  }

  func test_refreshedSession_clearsPendingPassphraseAuthorization() {
    withTestedInstance { (testedInstance: SessionState) in
      await testedInstance.createdSession(
        .mock_ada,
        "passphrase",
        .valid,
        "token",
        .none,
        .init()
      )

      try await testedInstance.authorizationRequested(.passphrase(.mock_ada))

      await XCTAssertValue(equal: .passphrase(for: .mock_ada)) {
        await testedInstance.pendingAuthorization()
      }

      try await testedInstance.refreshedSession(
        .mock_ada,
        "passphrase_update",
        .valid,
        "token_update",
        "mfa_update"
      )


      await XCTAssertValue(equal: .none) {
        await testedInstance.pendingAuthorization()
      }
    }
  }

  func test_refreshedSession_doesNotClearPendingMFAAuthorization() {
    withTestedInstance { (testedInstance: SessionState) in
      await testedInstance.createdSession(
        .mock_ada,
        "passphrase",
        .valid,
        "token",
        .none,
        .init()
      )

      try await testedInstance.authorizationRequested(.mfa(.mock_ada, providers: .init()))

      await XCTAssertValue(equal: .mfa(for: .mock_ada, providers: .init())) {
        await testedInstance.pendingAuthorization()
      }

      try await testedInstance.refreshedSession(
        .mock_ada,
        "passphrase_update",
        .valid,
        "token_update",
        "mfa_update"
      )


      await XCTAssertValue(equal: .mfa(for: .mock_ada, providers: .init())) {
        await testedInstance.pendingAuthorization()
      }
    }
  }

  func test_passphraseProvided_throws_withoutSession() {
    withTestedInstanceThrows(
      SessionClosed.self
    ) { (testedInstance: SessionState) in
      try await testedInstance.passphraseProvided(
        .mock_ada,
        "passphrase_update"
      )
    }
  }

  func test_passphraseProvided_updatesPassphrase_withSession() {
    withTestedInstance { (testedInstance: SessionState) in
      await testedInstance.createdSession(
        .mock_ada,
        "passphrase",
        .valid,
        "token",
        .none,
        .init()
      )

      try await testedInstance.passphraseProvided(
        .mock_ada,
        "passphrase_update"
      )


      await XCTAssertValue(equal: "passphrase_update") {
        await testedInstance.passphrase()
      }
    }
  }

  func test_passphraseProvided_Session_clearsPendingPassphraseAuthorization() {
    withTestedInstance { (testedInstance: SessionState) in
      await testedInstance.createdSession(
        .mock_ada,
        "passphrase",
        .valid,
        "token",
        .none,
        .init()
      )

      try await testedInstance.authorizationRequested(.passphrase(.mock_ada))

      await XCTAssertValue(equal: .passphrase(for: .mock_ada)) {
        await testedInstance.pendingAuthorization()
      }

      try await testedInstance.passphraseProvided(
        .mock_ada,
        "passphrase_update"
      )


      await XCTAssertValue(equal: .none) {
        await testedInstance.pendingAuthorization()
      }
    }
  }

  func test_passphraseProvided_doesNotClearPendingMFAAuthorization() {
    withTestedInstance { (testedInstance: SessionState) in
      await testedInstance.createdSession(
        .mock_ada,
        "passphrase",
        .valid,
        "token",
        .none,
        .init()
      )

      try await testedInstance.authorizationRequested(.mfa(.mock_ada, providers: .init()))

      await XCTAssertValue(equal: .mfa(for: .mock_ada, providers: .init())) {
        await testedInstance.pendingAuthorization()
      }

      try await testedInstance.passphraseProvided(
        .mock_ada,
        "passphrase_update"
      )


      await XCTAssertValue(equal: .mfa(for: .mock_ada, providers: .init())) {
        await testedInstance.pendingAuthorization()
      }
    }
  }

  func test_mfaProvided_throws_withoutSession() {
    withTestedInstanceThrows(
      SessionClosed.self
    ) { (testedInstance: SessionState) in
      try await testedInstance.mfaProvided(
        .mock_ada,
        "mfa_update"
      )
    }
  }

  func test_mfaProvided_updatesMFA_withSession() {
    withTestedInstance { (testedInstance: SessionState) in
      await testedInstance.createdSession(
        .mock_ada,
        "passphrase",
        .valid,
        "token",
        .none,
        .init()
      )

      try await testedInstance.mfaProvided(
        .mock_ada,
        "mfa_update"
      )


      await XCTAssertValue(equal: "mfa_update") {
        await testedInstance.mfaToken()
      }
    }
  }

  func test_mfaProvided_Session_clearsPendingMFAAuthorization() {
    withTestedInstance { (testedInstance: SessionState) in
      await testedInstance.createdSession(
        .mock_ada,
        "passphrase",
        .valid,
        "token",
        .none,
        .init()
      )

      try await testedInstance.authorizationRequested(.mfa(.mock_ada, providers: .init()))

      await XCTAssertValue(equal: .mfa(for: .mock_ada, providers: .init())) {
        await testedInstance.pendingAuthorization()
      }

      try await testedInstance.mfaProvided(
        .mock_ada,
        "mfa_update"
      )

      await XCTAssertValue(equal: .none) {
        await testedInstance.pendingAuthorization()
      }
    }
  }

  func test_mfaProvided_doesNotClearPendingPassphraseAuthorization() {
    withTestedInstance { (testedInstance: SessionState) in
      await testedInstance.createdSession(
        .mock_ada,
        "passphrase",
        .valid,
        "token",
        .none,
        .init()
      )

      try await testedInstance.authorizationRequested(.passphrase(.mock_ada))

      await XCTAssertValue(equal: .passphrase(for: .mock_ada)) {
        await testedInstance.pendingAuthorization()
      }

      try await testedInstance.mfaProvided(
        .mock_ada,
        "mfa_update"
      )


      await XCTAssertValue(equal: .passphrase(for: .mock_ada)) {
        await testedInstance.pendingAuthorization()
      }
    }
  }

  func test_closedSession_clearsAllData() {
    withTestedInstance { (testedInstance: SessionState) in
      await testedInstance.createdSession(
        .mock_ada,
        "passphrase",
        .valid,
        "refreshToken",
        "mfaToken",
        .init()
      )

      await testedInstance.closedSession()

      await XCTAssertValue(equal: .none) {
        await testedInstance.account()
      }
      await XCTAssertValue(equal: .none) {
        await testedInstance.passphrase()
      }
      await XCTAssertValue(equal: .none) {
        await testedInstance.validAccessToken()
      }
      await XCTAssertValue(equal: .none) {
        await testedInstance.refreshToken()
      }
      await XCTAssertValue(equal: .none) {
        await testedInstance.mfaToken()
      }
    }
  }

  func test_pendingAuthorization_returnsNone_withoutAuthorizationRequest() {
    withTestedInstanceReturnsNone { (testedInstance: SessionState) in
      await testedInstance.pendingAuthorization()
    }
  }

  func test_authorizationRequested_throws_withoutSession() {
    withTestedInstanceThrows(
      SessionClosed.self
    ) { (testedInstance: SessionState) in
      try await testedInstance.authorizationRequested(.passphrase(.mock_ada))
    }
  }

  func test_authorizationRequested_setsPendingAuthorization_withSession() {
    withTestedInstanceReturnsEqual(
      SessionState.PendingAuthorization.passphrase(for: .mock_ada)
    ) { (testedInstance: SessionState) in
      await testedInstance.createdSession(
        .mock_ada,
        "passphrase",
        .valid,
        "token",
        "mfa",
        .init()
      )
      try await testedInstance.authorizationRequested(.passphrase(.mock_ada))
      return await testedInstance.pendingAuthorization()
    }
  }

  func test_authorizationRequested_updatesPendingAuthorization_withMFAWhenPassphrasePending() {
    withTestedInstanceReturnsEqual(
      SessionState.PendingAuthorization.passphraseWithMFA(for: .mock_ada, providers: .init())
    ) { (testedInstance: SessionState) in
      await testedInstance.createdSession(
        .mock_ada,
        "passphrase",
        .valid,
        "token",
        "mfa",
        .init()
      )
      try await testedInstance.authorizationRequested(.passphrase(.mock_ada))
      try await testedInstance.authorizationRequested(.mfa(.mock_ada, providers: .init()))
      return await testedInstance.pendingAuthorization()
    }
  }

  func test_authorizationRequested_updatesPendingAuthorization_withPassphraseWhenMFAPending() {
    withTestedInstanceReturnsEqual(
      SessionState.PendingAuthorization.passphraseWithMFA(for: .mock_ada, providers: .init())
    ) { (testedInstance: SessionState) in
      await testedInstance.createdSession(
        .mock_ada,
        "passphrase",
        .valid,
        "token",
        "mfa",
        .init()
      )
      try await testedInstance.authorizationRequested(.mfa(.mock_ada, providers: .init()))
      try await testedInstance.authorizationRequested(.passphrase(.mock_ada))
      return await testedInstance.pendingAuthorization()
    }
  }

  func test_authorizationRequested_doesNothing_withPassphraseAndMFAPending() {
    withTestedInstanceReturnsEqual(
      SessionState.PendingAuthorization.passphraseWithMFA(for: .mock_ada, providers: .init())
    ) { (testedInstance: SessionState) in
      await testedInstance.createdSession(
        .mock_ada,
        "passphrase",
        .valid,
        "token",
        "mfa",
        .init()
      )
      try await testedInstance.authorizationRequested(.passphrase(.mock_ada))
      try await testedInstance.authorizationRequested(.mfa(.mock_ada, providers: .init()))

      try await testedInstance.authorizationRequested(.passphrase(.mock_ada))
      try await testedInstance.authorizationRequested(.mfa(.mock_ada, providers: .init()))
      return await testedInstance.pendingAuthorization()
    }
  }
}
