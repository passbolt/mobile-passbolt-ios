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
final class SessionStateTests: LoadableFeatureTestCase<SessionState>, @unchecked Sendable {

  override class func testedImplementationRegister(
    _ registry: inout FeaturesRegistry
  ) {
    registry.usePassboltSessionState()
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

  // MARK: - Passphrase caching with task tracking tests

  func test_sessionTaskFinished_untracksTask() {
    withTestedInstance { (testedInstance: SessionState) in
      await testedInstance.createdSession(
        .mock_ada,
        "passphrase",
        .valid,
        "token",
        .none,
        .init()
      )

      let taskID: SessionTaskID = .init()
      await testedInstance.sessionTaskStarted(taskID)
      await testedInstance.sessionTaskFinished(taskID)

      // Task is no longer tracked - passphrase wipe should work immediately
      await testedInstance.passphraseWipe(false)

      await XCTAssertValue(equal: .none) {
        await testedInstance.passphrase()
      }
    }
  }

  func test_passphraseWipe_defersWipe_whenTasksRunning() {
    withTestedInstance { (testedInstance: SessionState) in
      await testedInstance.createdSession(
        .mock_ada,
        "passphrase",
        .valid,
        "token",
        .none,
        .init()
      )

      let taskID: SessionTaskID = .init()
      await testedInstance.sessionTaskStarted(taskID)

      // Request wipe without force
      await testedInstance.passphraseWipe(false)

      // Passphrase should still be present
      await XCTAssertValue(equal: "passphrase") {
        await testedInstance.passphrase()
      }
    }
  }

  func test_passphraseWipe_forcesWipe_whenTasksRunning() {
    withTestedInstance { (testedInstance: SessionState) in
      await testedInstance.createdSession(
        .mock_ada,
        "passphrase",
        .valid,
        "token",
        .none,
        .init()
      )

      let taskID: SessionTaskID = .init()
      await testedInstance.sessionTaskStarted(taskID)

      // Force wipe
      await testedInstance.passphraseWipe(true)

      // Passphrase should be wiped even with running task
      await XCTAssertValue(equal: .none) {
        await testedInstance.passphrase()
      }
    }
  }

  func test_passphraseWipe_wipesImmediately_whenNoTasksRunning() {
    withTestedInstance { (testedInstance: SessionState) in
      await testedInstance.createdSession(
        .mock_ada,
        "passphrase",
        .valid,
        "token",
        .none,
        .init()
      )

      // No tasks running - wipe should be immediate
      await testedInstance.passphraseWipe(false)

      await XCTAssertValue(equal: .none) {
        await testedInstance.passphrase()
      }
    }
  }

  func test_passphraseWipe_deferredWipeCompletes_whenAllTasksFinish() {
    withTestedInstance { (testedInstance: SessionState) in
      await testedInstance.createdSession(
        .mock_ada,
        "passphrase",
        .valid,
        "token",
        .none,
        .init()
      )

      let taskID1: SessionTaskID = .init()
      let taskID2: SessionTaskID = .init()

      await testedInstance.sessionTaskStarted(taskID1)
      await testedInstance.sessionTaskStarted(taskID2)

      // Request wipe - should be deferred
      await testedInstance.passphraseWipe(false)

      // Passphrase still present with tasks running
      await XCTAssertValue(equal: "passphrase") {
        await testedInstance.passphrase()
      }

      // Finish first task - passphrase should still be present
      await testedInstance.sessionTaskFinished(taskID1)
      await XCTAssertValue(equal: "passphrase") {
        await testedInstance.passphrase()
      }

      // Finish second task - passphrase should be wiped automatically
      await testedInstance.sessionTaskFinished(taskID2)
      await XCTAssertValue(equal: .none) {
        await testedInstance.passphrase()
      }
    }
  }

  func test_passphrase_returnsExpiredPassphrase_whenTasksRunning() {
    withTestedInstance { (testedInstance: SessionState) in
      await testedInstance.createdSession(
        .mock_ada,
        "passphrase",
        .valid,
        "token",
        .none,
        .init()
      )

      let taskID: SessionTaskID = .init()
      await testedInstance.sessionTaskStarted(taskID)

      // Expire the passphrase
      self.timestamp = (5 * 60 * 60) as Timestamp

      // Should return expired passphrase since task is running
      await XCTAssertValue(equal: "passphrase") {
        await testedInstance.passphrase()
      }
    }
  }

  func test_passphrase_wipesExpiredPassphrase_whenTasksComplete() {
    withTestedInstance { (testedInstance: SessionState) in
      await testedInstance.createdSession(
        .mock_ada,
        "passphrase",
        .valid,
        "token",
        .none,
        .init()
      )

      let taskID: SessionTaskID = .init()
      await testedInstance.sessionTaskStarted(taskID)

      // Expire the passphrase
      self.timestamp = (5 * 60 * 60) as Timestamp

      // Access passphrase while task is running
      await XCTAssertValue(equal: "passphrase") {
        await testedInstance.passphrase()
      }

      // Finish the task
      await testedInstance.sessionTaskFinished(taskID)

      // Now accessing passphrase should return none (wiped automatically)
      await XCTAssertValue(equal: .none) {
        await testedInstance.passphrase()
      }
    }
  }

  func test_passphraseWipe_resetsWipeFlag_afterForceWipe() {
    withTestedInstance { (testedInstance: SessionState) in
      await testedInstance.createdSession(
        .mock_ada,
        "passphrase",
        .valid,
        "token",
        .none,
        .init()
      )

      let taskID: SessionTaskID = .init()
      await testedInstance.sessionTaskStarted(taskID)

      // Defer wipe
      await testedInstance.passphraseWipe(false)

      // Force wipe
      await testedInstance.passphraseWipe(true)

      // Set new passphrase
      try await testedInstance.passphraseProvided(.mock_ada, "new_passphrase")

      // Finish task - should not trigger wipe since flag was reset
      await testedInstance.sessionTaskFinished(taskID)

      // Passphrase should still be present
      await XCTAssertValue(equal: "new_passphrase") {
        await testedInstance.passphrase()
      }
    }
  }

  func test_executeUntracksTask_whenTaskThrows() async throws {
    let testedInstance: SessionState = try self.testedInstance()
    await testedInstance.createdSession(
      .mock_ada,
      "passphrase",
      .valid,
      "token",
      .none,
      .init()
    )
    // ensure passphrase is available
    await XCTAssertValue(equal: "passphrase") {
      await testedInstance.passphrase()
    }
    let passphraseCheckedExpectation: XCTestExpectation = .init(
      description: "Passphrase checked"
    )
    let task = testedInstance.execute {
      await self.fulfillment(of: [passphraseCheckedExpectation], timeout: 1.0)
      throw MockIssue.error()
    }
    // Request wipe - should be deferred because task is tracked
    await testedInstance.passphraseWipe(false)
    // ensure passphrase is still available
    await XCTAssertValue(equal: "passphrase") {
      await testedInstance.passphrase()
    }
    passphraseCheckedExpectation.fulfill()
    // Wait for task to complete (with error)
    _ = try? await task.value
    await XCTAssertValue(equal: .none) {
      await testedInstance.passphrase()
    }
  }

  func test_execute_tracksTaskLifecycle() async throws {
    let testedInstance: SessionState = try self.testedInstance()

    await testedInstance.createdSession(
      .mock_ada,
      "passphrase",
      .valid,
      "token",
      .none,
      .init()
    )

    let passphraseCheckedExpectation: XCTestExpectation = .init(
      description: "Passphrase checked within execute"
    )
    let operationExecuted: CriticalState<Bool> = .init(false)
    let task = testedInstance.execute {
      await self.fulfillment(of: [passphraseCheckedExpectation], timeout: 1.0)
      operationExecuted.set(true)
    }

    // Request wipe - should be deferred because task is tracked
    await testedInstance.passphraseWipe(false)

    // Passphrase still present
    await XCTAssertValue(equal: "passphrase") {
      await testedInstance.passphrase()
    }
    passphraseCheckedExpectation.fulfill()

    // Wait for task to complete
    _ = try? await task.value

    XCTAssertTrue(operationExecuted.get())

    // After task completes, passphrase should be wiped
    await XCTAssertValue(equal: .none) {
      await testedInstance.passphrase()
    }
  }

  func test_execute_untracksTask_afterThrowingOperation() async throws {
    let testedInstance: SessionState = try self.testedInstance()

    await testedInstance.createdSession(
      .mock_ada,
      "passphrase",
      .valid,
      "token",
      .none,
      .init()
    )

    let task = testedInstance.execute {
      throw MockIssue.error()
    }

    // Request wipe - should be deferred because task is tracked
    await testedInstance.passphraseWipe(false)

    // Wait for task to complete (with error)
    _ = try? await task.value

    // After task completes (even with error), passphrase should be wiped
    await XCTAssertValue(equal: .none) {
      await testedInstance.passphrase()
    }
  }

  func test_multipleTasksAndDeferredWipe_complexScenario() async throws {
    let testedInstance: SessionState = try self.testedInstance()

    await testedInstance.createdSession(
      .mock_ada,
      "passphrase",
      .valid,
      "token",
      .none,
      .init()
    )

    let task1Executed: CriticalState<Bool> = .init(false)
    let task2Executed: CriticalState<Bool> = .init(false)

    let task1 = testedInstance.execute {
      task1Executed.set(true)
      try await Task.sleep(nanoseconds: 10_000_000)  // 10ms
    }

    let task2 = testedInstance.execute {
      task2Executed.set(true)
      try await Task.sleep(nanoseconds: 10_000_000)  // 10ms
    }

    // Request wipe while both tasks are running
    await testedInstance.passphraseWipe(false)

    // Passphrase still present
    await XCTAssertValue(equal: "passphrase") {
      await testedInstance.passphrase()
    }

    // Wait for both tasks to complete
    _ = try? await task1.value
    _ = try? await task2.value

    XCTAssertTrue(task1Executed.get())
    XCTAssertTrue(task2Executed.get())

    // After all tasks complete, passphrase should be wiped
    await XCTAssertValue(equal: .none) {
      await testedInstance.passphrase()
    }
  }

  func test_requestAuthorizationIfNeeded_doesNothing_whenAlreadyAuthorizedWithValidPassphrase() {
    withTestedInstance { (testedInstance: SessionState) in
      await testedInstance.createdSession(
        .mock_ada,
        "passphrase",
        .valid,
        "refreshToken",
        "mfaToken",
        .init()
      )
      // Should not throw - passphrase is valid and not expired
      try await testedInstance.requestAuthorizationIfNeeded(.passphrase(.mock_ada))

      // Passphrase should still be present
      await XCTAssertValue(equal: "passphrase") {
        await testedInstance.passphrase()
      }
    }
  }

  func test_requestAuthorizationIfNeeded_requestsAuthorization_whenPassphraseExpired() {
    withTestedInstance { (testedInstance: SessionState) in
      await testedInstance.createdSession(
        .mock_ada,
        "passphrase",
        .valid,
        "refreshToken",
        "mfaToken",
        .init()
      )
      // Advance time past expiration
      self.timestamp = (5 * 60 * 60) as Timestamp

      // Should request authorization since passphrase is expired
      try await testedInstance.requestAuthorizationIfNeeded(.passphrase(.mock_ada))

      // Should have pending authorization
      let pending: SessionState.PendingAuthorization? = await testedInstance.pendingAuthorization()
      XCTAssertNotNil(pending)
    }
  }

  func test_requestAuthorizationIfNeeded_requestsAuthorization_whenNoSession() {
    withTestedInstance { (testedInstance: SessionState) in
      // No session created - should request authorization
      do {
        try await testedInstance.requestAuthorizationIfNeeded(.passphrase(.mock_ada))
        XCTFail("Expected requestAuthorizationIfNeeded to throw without session")
      }
      catch {
        // Expected - no session means authorization request should throw
        return
      }
    }
  }
}
