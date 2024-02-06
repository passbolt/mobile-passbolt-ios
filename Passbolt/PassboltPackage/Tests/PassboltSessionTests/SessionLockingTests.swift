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
	}

  func test_ensureAutolock_doesNotAffectAnythingWithoutTrigger() async throws {
    patch(
      \ApplicationLifecycle.lifecycle,
      with: Empty<ApplicationLifecycle.Transition, Never>()
				.asAsyncSequence()
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

  func test_ensureAutolock_clearsPassphrase_whenEnteringBackground() async throws {
    patch(
      \ApplicationLifecycle.lifecycle,
      with: CurrentValueSubject(ApplicationLifecycle.Transition.didEnterBackground)
          .asAsyncSequence()
    )
    patch(
      \SessionState.passphraseWipe,
      with: always(self.mockExecuted())
    )
		patch(
			\SessionState.pendingAuthorization,
			with: always(.none)
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

		await withSerialTaskExecutor {
			await withInstance(mockExecuted: 1) { (testedInstance: SessionLocking) in
				testedInstance.ensureLocking(.mock_ada)
				// sleeping beacause of actor switching
				// inside tasks causing the test to finish
				// prematurely Task.yield is not enough here
				try await Task.sleep(nanoseconds: 10 * NSEC_PER_MSEC)
			}
		}
	}

	func test_ensureAutolock_clearsPassphrase_whenEnteringForeground() async {
		patch(
			\ApplicationLifecycle.lifecycle,
			with: CurrentValueSubject(ApplicationLifecycle.Transition.willEnterForeground)
					.asAsyncSequence()
		)
		patch(
			\SessionState.authorizationRequested,
			 with: { (request: SessionAuthorizationRequest) in
				 self.mockExecuted(with: request)
			 }
		)
		patch(
			\SessionState.pendingAuthorization,
			 with: always(.none)
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

		await withSerialTaskExecutor {
			await withInstance(mockExecutedWith: SessionAuthorizationRequest.passphrase(.mock_ada)) { (testedInstance: SessionLocking) in
				testedInstance.ensureLocking(.mock_ada)
				// sleeping beacause of actor switching
				// inside tasks causing the test to finish
				// prematurely Task.yield is not enough here
				try await Task.sleep(nanoseconds: 10 * NSEC_PER_MSEC)
			}
		}
	}
}
