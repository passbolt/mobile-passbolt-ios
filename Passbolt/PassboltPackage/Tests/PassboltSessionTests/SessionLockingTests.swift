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
final class SessionLockingTests: LoadableFeatureTestCase<SessionLocking> {

  override class var testedImplementationRegister: (FeatureFactory) -> @MainActor () -> Void {
    FeatureFactory.usePassboltSessionLocking
  }

  var executionMockControl: AsyncExecutor.MockExecutionControl!

  override func prepare() throws {
    self.executionMockControl = .init()
    use(AsyncExecutor.mock(executionMockControl))
    use(SessionAuthorizationState.placeholder)
    use(SessionState.placeholder)
  }

  override func cleanup() throws {
    self.executionMockControl = .none
  }

  func test_ensureAutolock_doesNotAffectAnythingByItsOwn() {
    patch(
      environment: \.appLifeCycle.lifeCyclePublisher,
      with: always(
        Empty<AppLifeCycle.Transition, Never>()
          .eraseToAnyPublisher()
      )
    )

    withTestedInstance(
      context: Account.mock_ada
    ) { (testedInstance: SessionLocking) in
      testedInstance.ensureAutolock()
    }
  }

  func test_ensureAutolock_clearsPassphrase_whenEnteringBackground() {
    patch(
      environment: \.appLifeCycle.lifeCyclePublisher,
      with: always(
        CurrentValueSubject(AppLifeCycle.Transition.didEnterBackground)
          .eraseToAnyPublisher()
      )
    )
    patch(
      \SessionState.setPassphrase,
      with: { (passphrase: Passphrase?) in
        self.executed(using: passphrase)
      }
    )
    withTestedInstanceExecuted(
      using: Optional<Passphrase>.none,
      context: Account.mock_ada
    ) { (testedInstance: SessionLocking) in
      try await self.executionMockControl.execute {
        testedInstance.ensureAutolock()
      }
    }
  }

  func test_ensureAutolock_clearsPassphrase_whenEnteringForeground() {
    patch(
      environment: \.appLifeCycle.lifeCyclePublisher,
      with: always(
        CurrentValueSubject(AppLifeCycle.Transition.willEnterForeground)
          .eraseToAnyPublisher()
      )
    )
    patch(
      \SessionAuthorizationState.requestAuthorization,
      with: { (request: SessionAuthorizationRequest) in
        self.executed(using: request)
      }
    )
    withTestedInstanceExecuted(
      using: SessionAuthorizationRequest.passphrase(.mock_ada),
      context: Account.mock_ada
    ) { (testedInstance: SessionLocking) in
      try await self.executionMockControl.execute {
        testedInstance.ensureAutolock()
      }
    }
  }
}
