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

  override func commonPrepare() {
    super.commonPrepare()
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
    patch(
      \AccountPreferences.passphraseWipeOnBackground,
      with: .variable(initial: false)
    )
  }

  func test_ensureAutolock_doesNotAffectAnythingWithoutTrigger() async throws {
    patch(
      \ApplicationLifecycle.lifecycle,
      with: Empty<ApplicationLifecycle.Transition, Never>()
        .asAsyncSequence()
    )

    await withSerialTaskExecutor {
      await withInstance { (feature: SessionLocking) in
        feature.ensureLocking(.mock_ada)
        // sleeping beacause of actor switching
        // inside tasks causing the test to finish
        // prematurely Task.yield is not enough here
        try await Task.sleep(nanoseconds: 10 * NSEC_PER_MSEC)
      }
    }
  }

  func test_ensureAutolock_wipesPassphraseImmediately_whenEnteringBackground_withWipeOnBackgroundEnabled() async throws
  {
    patch(
      \AccountPreferences.passphraseWipeOnBackground,
      with: .variable(initial: true)
    )
    patch(
      \ApplicationLifecycle.lifecycle,
      with: Just(ApplicationLifecycle.Transition.didEnterBackground)
        .asAsyncSequence()
    )
    patch(
      \SessionState.passphraseWipe,
      with: { (force: Bool) in
        self.mockExecuted(with: force)
      }
    )

    await withSerialTaskExecutor {
      await withInstance(mockExecutedWith: false) { (testedInstance: SessionLocking) in
        testedInstance.ensureLocking(.mock_ada)
        // sleeping beacause of actor switching
        // inside tasks causing the test to finish
        // prematurely Task.yield is not enough here
        try await Task.sleep(nanoseconds: 10 * NSEC_PER_MSEC)
      }
    }
  }

  func test_ensureAutolock_defersPassphraseWipe_whenEnteringBackground_withWipeOnBackgroundDisabled() async throws {
    patch(
      \AccountPreferences.passphraseWipeOnBackground,
      with: .variable(initial: false)
    )
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
      }
    )

    await withSerialTaskExecutor {
      await withInstance(mockExecutedWith: false) { (testedInstance: SessionLocking) in
        testedInstance.ensureLocking(.mock_ada)
        // sleeping beacause of actor switching
        // inside tasks causing the test to finish
        // prematurely Task.yield is not enough here
        try await Task.sleep(nanoseconds: 10 * NSEC_PER_MSEC)
      }
    }
  }

  func test_ensureAutolock_requestsAuthorizationIfNeeded_whenEnteringForeground() async {
    patch(
      \ApplicationLifecycle.lifecycle,
      with: Just(ApplicationLifecycle.Transition.willEnterForeground)
        .asAsyncSequence()
    )
    patch(
      \SessionState.requestAuthorizationIfNeeded,
      with: { (request: SessionAuthorizationRequest) in
        self.mockExecuted(with: request)
      }
    )

    await withSerialTaskExecutor {
      await withInstance(mockExecutedWith: SessionAuthorizationRequest.passphrase(.mock_ada)) {
        (testedInstance: SessionLocking) in
        testedInstance.ensureLocking(.mock_ada)
        // sleeping beacause of actor switching
        // inside tasks causing the test to finish
        // prematurely Task.yield is not enough here
        try await Task.sleep(nanoseconds: 10 * NSEC_PER_MSEC)
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
