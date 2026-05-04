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
final class SessionPassphraseWipeTests: LoadableFeatureTestCase<SessionState>, @unchecked Sendable {

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

  func test_passphraseWipe_clearsPassphrase_immediately_whenNoTasksRunning() {
    withTestedInstance { (testedInstance: SessionState) in
      await testedInstance.createdSession(
        .mock_ada,
        "passphrase",
        .valid,
        "refreshToken",
        "mfaToken",
        .init()
      )

      await XCTAssertValue(equal: "passphrase") {
        await testedInstance.passphrase()
      }

      await testedInstance.passphraseWipe(false)

      await XCTAssertValue(equal: .none) {
        await testedInstance.passphrase()
      }
    }
  }

  func test_passphraseWipe_defersWipe_whenTasksAreRunning() {
    withTestedInstance { (testedInstance: SessionState) in
      await testedInstance.createdSession(
        .mock_ada,
        "passphrase",
        .valid,
        "refreshToken",
        "mfaToken",
        .init()
      )

      let taskID = SessionTaskID()
      await testedInstance.sessionTaskStarted(taskID)

      await testedInstance.passphraseWipe(false)

      // Passphrase should still be present
      await XCTAssertValue(equal: "passphrase") {
        await testedInstance.passphrase()
      }

      await testedInstance.sessionTaskFinished(taskID)

      await XCTAssertValue(equal: .none) {
        await testedInstance.passphrase()
      }
    }
  }

  func test_passphraseWipe_forcedWipe_clearsPassphrase_evenWhenTasksRunning() {
    withTestedInstance { (testedInstance: SessionState) in
      await testedInstance.createdSession(
        .mock_ada,
        "passphrase",
        .valid,
        "refreshToken",
        "mfaToken",
        .init()
      )

      let taskID = SessionTaskID()
      await testedInstance.sessionTaskStarted(taskID)
      await testedInstance.passphraseWipe(true)

      await XCTAssertValue(equal: .none) {
        await testedInstance.passphrase()
      }

      // Cleanup
      await testedInstance.sessionTaskFinished(taskID)
    }
  }

  func test_passphraseWipe_deferredWipe_executesOnlyOnce_whenMultipleTasksComplete() {
    withTestedInstance { (testedInstance: SessionState) in
      await testedInstance.createdSession(
        .mock_ada,
        "passphrase",
        .valid,
        "refreshToken",
        "mfaToken",
        .init()
      )

      let taskID1 = SessionTaskID()
      let taskID2 = SessionTaskID()
      let taskID3 = SessionTaskID()
      await testedInstance.sessionTaskStarted(taskID1)
      await testedInstance.sessionTaskStarted(taskID2)
      await testedInstance.sessionTaskStarted(taskID3)

      await testedInstance.passphraseWipe(false)

      await XCTAssertValue(equal: "passphrase") {
        await testedInstance.passphrase()
      }

      await testedInstance.sessionTaskFinished(taskID1)

      // Passphrase should still be present (tasks still running)
      await XCTAssertValue(equal: "passphrase") {
        await testedInstance.passphrase()
      }

      await testedInstance.sessionTaskFinished(taskID2)

      // Passphrase should still be present (one task still running)
      await XCTAssertValue(equal: "passphrase") {
        await testedInstance.passphrase()
      }

      await testedInstance.sessionTaskFinished(taskID3)

      // Now passphrase should be wiped
      await XCTAssertValue(equal: .none) {
        await testedInstance.passphrase()
      }
    }
  }

  func test_passphrase_defersWipe_whenExpiredButTasksRunning() {
    withTestedInstance { (testedInstance: SessionState) in
      await testedInstance.createdSession(
        .mock_ada,
        "passphrase",
        .valid,
        "refreshToken",
        "mfaToken",
        .init()
      )

      let taskID = SessionTaskID()
      await testedInstance.sessionTaskStarted(taskID)

      // Expire the passphrase
      self.timestamp = (5 * 60 * 60) as Timestamp

      // Passphrase should still be returned (expired but task running)
      await XCTAssertValue(equal: "passphrase") {
        await testedInstance.passphrase()
      }

      await testedInstance.sessionTaskFinished(taskID)

      await XCTAssertValue(equal: .none) {
        await testedInstance.passphrase()
      }
    }
  }

  func test_closedSession_clearsPassphrase_andCancelsDeferredWipe() {
    withTestedInstance { (testedInstance: SessionState) in
      await testedInstance.createdSession(
        .mock_ada,
        "passphrase",
        .valid,
        "refreshToken",
        "mfaToken",
        .init()
      )

      let taskID = SessionTaskID()
      await testedInstance.sessionTaskStarted(taskID)

      await testedInstance.passphraseWipe(false)

      await testedInstance.closedSession()

      // Account should be cleared
      await XCTAssertValue(equal: .none) {
        await testedInstance.account()
      }

      // Passphrase should be cleared
      await XCTAssertValue(equal: .none) {
        await testedInstance.passphrase()
      }

      await testedInstance.sessionTaskFinished(taskID)

      // Passphrase should still be none
      await XCTAssertValue(equal: .none) {
        await testedInstance.passphrase()
      }
    }
  }

  func test_multipleDeferredWipeRequests_onlyExecuteOnce() {
    withTestedInstance { (testedInstance: SessionState) in
      await testedInstance.createdSession(
        .mock_ada,
        "passphrase",
        .valid,
        "refreshToken",
        "mfaToken",
        .init()
      )

      let taskID = SessionTaskID()
      await testedInstance.sessionTaskStarted(taskID)

      // Request wipe multiple times while task is running
      await testedInstance.passphraseWipe(false)
      await testedInstance.passphraseWipe(false)
      await testedInstance.passphraseWipe(false)

      await XCTAssertValue(equal: "passphrase") {
        await testedInstance.passphrase()
      }

      await testedInstance.sessionTaskFinished(taskID)

      await XCTAssertValue(equal: .none) {
        await testedInstance.passphrase()
      }
    }
  }

  func test_taskStartedAndFinished_maintainsCorrectCount() {
    withTestedInstance { (testedInstance: SessionState) in
      await testedInstance.createdSession(
        .mock_ada,
        "passphrase",
        .valid,
        "refreshToken",
        "mfaToken",
        .init()
      )

      let taskID1 = SessionTaskID()
      let taskID2 = SessionTaskID()

      await testedInstance.sessionTaskStarted(taskID1)
      await testedInstance.passphraseWipe(false)
      await testedInstance.sessionTaskStarted(taskID2)
      await testedInstance.sessionTaskFinished(taskID1)

      await XCTAssertValue(equal: "passphrase") {
        await testedInstance.passphrase()
      }

      await testedInstance.sessionTaskFinished(taskID2)

      await XCTAssertValue(equal: .none) {
        await testedInstance.passphrase()
      }
    }
  }

  func test_closedSession_cancelsRunningTasks() {
    withTestedInstance { (testedInstance: SessionState) in
      await testedInstance.createdSession(
        .mock_ada,
        "passphrase",
        .valid,
        "refreshToken",
        "mfaToken",
        .init()
      )

      let cancellationExpectation: XCTestExpectation = .init(
        description: "Task was cancelled"
      )
      let task: Task<Void, Error> = Task {
        try await withTaskCancellationHandler {
          try await Task.sleep(nanoseconds: 60_000_000_000)
        } onCancel: {
          cancellationExpectation.fulfill()
        }
      }
      let taskID: SessionTaskID = .init()
      await testedInstance.sessionTaskStarted(taskID)
      await testedInstance.sessionTaskRegistered(taskID, task)

      await testedInstance.closedSession()

      await self.fulfillment(of: [cancellationExpectation], timeout: 1.0)
    }
  }
}
