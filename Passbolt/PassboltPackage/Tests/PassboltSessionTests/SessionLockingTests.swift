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
final class SessionLockingTests: FeaturesTestCase {

  override func commonPrepare() async throws {
    try await super.commonPrepare()
    register(
      { $0.usePassboltSessionLocking() },
      for: SessionLocking.self
    )
    patch(
      \SessionState.updates,
      with: Variable(initial: Void())
        .asAnyUpdatable()
    )
    patch(
      \SessionState.account,
      with: always(.mock_ada)
    )
    patch(
      \SessionState.pendingAuthorization,
      with: always(.none)
    )
    patch(
      \SessionConfigurationLoader.sessionConfiguration,
      with: always(.default)
    )
    set(
      AccountScope.self,
      context: .mock_ada
    )
    set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .default
      )
    )
    patchWipeOnBackground(enabled: false)
    patch(
      \OSTime.monotonicTimestamp,
      with: always(self.monotonicTimestamp)
    )
    self.monotonicTimestamp = 0 as MonotonicTimestamp
  }

  private func patchMonotonicTimestamp(
    readings: Array<MonotonicTimestamp>
  ) {
    let remaining: CriticalState<Array<MonotonicTimestamp>> = .init(readings)
    patch(
      \OSTime.monotonicTimestamp,
      with: { () -> MonotonicTimestamp in
        remaining.access { (readings: inout Array<MonotonicTimestamp>) -> MonotonicTimestamp in
          if readings.count > 1 {
            return readings.removeFirst()
          }
          else {
            return readings.first ?? 0
          }
        }
      }
    )
  }

  /// Patches the wipe on background setting.
  ///
  /// When `failingAfterFirstRead` is set every read except the first one throws, which is what
  /// the keychain does once the device locks. The first read is the one made by `SessionLocking`
  /// while the application is still active and the device still unlocked.
  private func patchWipeOnBackground(
    enabled: Bool,
    failingAfterFirstRead: Bool = false
  ) {
    let performedReads: CriticalState<UInt> = .init(0)
    patch(
      \AccountPreferences.passphraseWipeOnBackground,
      with: .variable(initial: enabled)
    )
    patch(
      \AccountPreferences.readPassphraseWipeOnBackground,
      with: { () throws -> Bool in
        let previousReads: UInt = performedReads.access { (count: inout UInt) -> UInt in
          let previous: UInt = count
          count = previous + 1
          return previous
        }
        if failingAfterFirstRead, previousReads > 0 {
          throw MockIssue.error()
        }
        else {
          return enabled
        }
      }
    )
  }

  func test_ensureAutolock_doesNotAffectAnythingWithoutTrigger() async throws {
    let wipeNotRequested: XCTestExpectation = expectation(
      description: "Passphrase cache should not be wiped without a lifecycle transition"
    )
    wipeNotRequested.isInverted = true
    patch(
      \ApplicationLifecycle.lifecycle,
      with: Empty<ApplicationLifecycle.Transition, Never>()
        .asAsyncSequence()
    )
    patch(
      \SessionState.passphraseWipe,
      with: { (_: Bool) in
        wipeNotRequested.fulfill()
      }
    )

    await withSerialTaskExecutor {
      await withInstance { (feature: SessionLocking) in
        feature.ensureLocking(.mock_ada)
        await self.fulfillment(of: [wipeNotRequested], timeout: 0.1)
      }
    }
  }

  func test_ensureAutolock_wipesPassphraseImmediately_whenEnteringBackground_withWipeOnBackgroundEnabled() async throws
  {
    // no `willResignActive` here on purpose - covers locking becoming enabled after the
    // application already resigned being active, where the setting is read on backgrounding
    let wipeRequested: XCTestExpectation = expectation(description: "Passphrase cache should be wiped")
    patchWipeOnBackground(enabled: true)
    patch(
      \ApplicationLifecycle.lifecycle,
      with: Just(ApplicationLifecycle.Transition.didEnterBackground)
        .asAsyncSequence()
    )
    patch(
      \SessionState.passphraseWipe,
      with: { (force: Bool) in
        self.mockExecuted(with: force)
        wipeRequested.fulfill()
      }
    )

    await withSerialTaskExecutor {
      await withInstance(mockExecutedWith: true) { (testedInstance: SessionLocking) in
        testedInstance.ensureLocking(.mock_ada)
        await self.fulfillment(of: [wipeRequested], timeout: 1)
      }
    }
  }

  func test_ensureAutolock_wipesPassphrase_whenEnteringBackground_andSettingBecomesUnreadable() async throws {
    // Two background cycles. The setting is read successfully during the first one, then the
    // keychain becomes unreachable, which is what happens once the device locks. The second
    // cycle has to wipe the cache using the last successfully read value.
    let wipeRequested: XCTestExpectation = expectation(description: "Passphrase cache should be wiped")
    wipeRequested.expectedFulfillmentCount = 2
    patchWipeOnBackground(
      enabled: true,
      failingAfterFirstRead: true
    )
    let transitions: Array<ApplicationLifecycle.Transition> = [
      .willResignActive,
      .didEnterBackground,
      .willEnterForeground,
      .willResignActive,
      .didEnterBackground,
    ]
    patch(
      \ApplicationLifecycle.lifecycle,
      with: transitions
        .publisher
        .asAsyncSequence()
    )
    patch(
      \SessionState.requestAuthorizationIfNeeded,
      with: { (_: SessionAuthorizationRequest) in
        // NOP
      }
    )
    patch(
      \SessionState.passphraseWipe,
      with: { (force: Bool) in
        self.mockExecuted(with: force)
        wipeRequested.fulfill()
      }
    )

    // when the fallback does not hold, the second cycle defers the wipe instead of
    // performing it and the second fulfillment never arrives
    await withSerialTaskExecutor {
      await withInstance(mockExecutedWith: true) { (testedInstance: SessionLocking) in
        testedInstance.ensureLocking(.mock_ada)
        await self.fulfillment(of: [wipeRequested], timeout: 1)
      }
    }
  }

  func test_ensureAutolock_doesNotWipePassphrase_whenOnlyResigningActive() async throws {
    // resigning active happens also on interruptions which do not background the application,
    // it may only refresh the setting and must not touch the passphrase cache on its own
    let wipeNotRequested: XCTestExpectation = expectation(
      description: "Passphrase cache should not be wiped when only resigning active"
    )
    wipeNotRequested.isInverted = true
    patchWipeOnBackground(enabled: true)
    patch(
      \ApplicationLifecycle.lifecycle,
      with: Just(ApplicationLifecycle.Transition.willResignActive)
        .asAsyncSequence()
    )
    patch(
      \SessionState.passphraseWipe,
      with: { (_: Bool) in
        wipeNotRequested.fulfill()
      }
    )

    await withSerialTaskExecutor {
      await withInstance { (testedInstance: SessionLocking) in
        testedInstance.ensureLocking(.mock_ada)
        await self.fulfillment(of: [wipeNotRequested], timeout: 0.1)
      }
    }
  }

  func test_ensureAutolock_defersPassphraseWipe_whenEnteringBackground_withWipeOnBackgroundDisabled() async throws {
    let wipeRequested: XCTestExpectation = expectation(description: "Passphrase cache should be wiped")
    patchWipeOnBackground(enabled: false)
    patch(
      \ApplicationLifecycle.lifecycle,
      with: AsyncStream<ApplicationLifecycle.Transition> { continuation in
        continuation.yield(.didEnterBackground)
        // Stream stays open — production lifecycle never completes, and an
        // open stream prevents the outer task's defer from cancelling the
        // deferred wipe task before it runs.
      }
      .asAnyAsyncSequence()
    )
    patch(
      \OSTime.waitFor,
      with: { (_: Seconds) in
        // NOP - complete immediately for testing
      }
    )
    patch(
      \SessionState.passphraseWipe,
      with: { (force: Bool) in
        self.mockExecuted(with: force)
        wipeRequested.fulfill()
      }
    )

    await withSerialTaskExecutor {
      await withInstance(mockExecutedWith: true) { (testedInstance: SessionLocking) in
        testedInstance.ensureLocking(.mock_ada)
        await self.fulfillment(of: [wipeRequested], timeout: 1)
      }
    }
  }

  func test_ensureAutolock_requestsAuthorizationIfNeeded_whenEnteringForeground() async {
    let authorizationRequested: XCTestExpectation = expectation(description: "Authorization should be requested")
    patch(
      \ApplicationLifecycle.lifecycle,
      with: Just(ApplicationLifecycle.Transition.willEnterForeground)
        .asAsyncSequence()
    )
    patch(
      \SessionState.requestAuthorizationIfNeeded,
      with: { (request: SessionAuthorizationRequest) in
        self.mockExecuted(with: request)
        authorizationRequested.fulfill()
      }
    )

    await withSerialTaskExecutor {
      await withInstance(mockExecutedWith: SessionAuthorizationRequest.passphrase(.mock_ada)) {
        (testedInstance: SessionLocking) in
        testedInstance.ensureLocking(.mock_ada)
        await self.fulfillment(of: [authorizationRequested], timeout: 1)
      }
    }
  }

  func test_ensureAutolock_wipesPassphrase_whenEnteringForeground_afterWipeDelayInBackground() async throws {
    // 120 seconds spent in background, which is more than the 60 seconds wipe delay
    let wipeRequested: XCTestExpectation = expectation(description: "Passphrase cache should be wiped")
    let deferredWipeTimer: TestSuspension = .init()
    patchMonotonicTimestamp(readings: [0, 120])
    patch(
      \ApplicationLifecycle.lifecycle,
      with: AsyncStream<ApplicationLifecycle.Transition> { continuation in
        continuation.yield(.didEnterBackground)
        continuation.yield(.willEnterForeground)
        // Stream stays open — production lifecycle never completes.
      }
      .asAnyAsyncSequence()
    )
    patch(
      \OSTime.waitFor,
      with: { (_: Seconds) in
        // suspends until the foreground transition cancels the deferred wipe task,
        // so the wipe observed here can only come from the elapsed time check
        await deferredWipeTimer.wait()
      }
    )
    patch(
      \SessionState.requestAuthorizationIfNeeded,
      with: { (_: SessionAuthorizationRequest) in
        // NOP
      }
    )
    patch(
      \SessionState.passphraseWipe,
      with: { (force: Bool) in
        self.mockExecuted(with: force)
        wipeRequested.fulfill()
      }
    )

    await withSerialTaskExecutor {
      await withInstance(mockExecutedWith: true) { (testedInstance: SessionLocking) in
        testedInstance.ensureLocking(.mock_ada)
        await self.fulfillment(of: [wipeRequested], timeout: 1)
      }
    }
  }

  func test_ensureAutolock_keepsPassphrase_whenEnteringForeground_withinWipeDelay() async throws {
    // 10 seconds spent in background, which is less than the 60 seconds wipe delay
    let authorizationRequested: XCTestExpectation = expectation(description: "Authorization should be requested")
    let wipeNotRequested: XCTestExpectation = expectation(
      description: "Passphrase cache should not be wiped within the grace period"
    )
    wipeNotRequested.isInverted = true
    let deferredWipeTimer: TestSuspension = .init()
    patchMonotonicTimestamp(readings: [0, 10])
    patch(
      \ApplicationLifecycle.lifecycle,
      with: AsyncStream<ApplicationLifecycle.Transition> { continuation in
        continuation.yield(.didEnterBackground)
        continuation.yield(.willEnterForeground)
        // Stream stays open — production lifecycle never completes.
      }
      .asAnyAsyncSequence()
    )
    patch(
      \OSTime.waitFor,
      with: { (_: Seconds) in
        // suspends until the foreground transition cancels the deferred wipe task,
        // so a wipe observed here could only come from the elapsed time check
        await deferredWipeTimer.wait()
      }
    )
    patch(
      \SessionState.passphraseWipe,
      with: { (_: Bool) in
        wipeNotRequested.fulfill()
      }
    )
    patch(
      \SessionState.requestAuthorizationIfNeeded,
      with: { (request: SessionAuthorizationRequest) in
        self.mockExecuted(with: request)
        authorizationRequested.fulfill()
      }
    )

    await withSerialTaskExecutor {
      await withInstance(mockExecutedWith: SessionAuthorizationRequest.passphrase(.mock_ada)) {
        (testedInstance: SessionLocking) in
        testedInstance.ensureLocking(.mock_ada)
        await self.fulfillment(
          of: [authorizationRequested, wipeNotRequested],
          timeout: 0.1
        )
      }
    }
  }
}

extension StoredVariable {

  fileprivate static func variable(initial: Value) -> Self {
    .init(
      fetch: { initial },
      store: { _ in /* NOP */ }
    )
  }
}

/// Suspends an awaiting task until the task itself is cancelled.
///
/// Used in place of sleeping for a guessed amount of time - the suspension ends on
/// cancellation, so the test never depends on how long anything actually takes.
private final class TestSuspension: @unchecked Sendable {

  private let stream: AsyncStream<Void>
  private let continuation: AsyncStream<Void>.Continuation

  fileprivate init() {
    var created: AsyncStream<Void>.Continuation?
    // the closure is executed before `init` returns
    let stream: AsyncStream<Void> = .init { (continuation: AsyncStream<Void>.Continuation) in
      created = continuation
    }
    guard let continuation: AsyncStream<Void>.Continuation = created
    else { fatalError("AsyncStream did not provide its continuation") }
    self.stream = stream
    self.continuation = continuation
  }

  /// Suspends until the awaiting task is cancelled.
  /// Nothing is ever sent to the stream and its continuation is retained,
  /// so the only way out is cancellation, which terminates the iteration.
  fileprivate func wait() async {
    for await _: Void in self.stream {}
  }
}
