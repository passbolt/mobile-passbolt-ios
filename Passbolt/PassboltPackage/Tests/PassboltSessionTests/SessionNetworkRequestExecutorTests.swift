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
final class SessionNetworkRequestExecutorTests: LoadableFeatureTestCase<SessionNetworkRequestExecutor> {

  override class var testedImplementationRegister: (FeatureFactory) -> @MainActor () -> Void {
    FeatureFactory.usePassboltSessionNetworkRequestExecutor
  }

  override func prepare() throws {
    use(SessionState.placeholder)
    use(SessionStateEnsurance.placeholder)
    use(SessionAuthorizationState.placeholder)
    use(NetworkRequestExecutor.placeholder)
  }

  func test_execute_throws_withoutSession() {
    patch(
      \SessionState.account,
      with: always(.none)
    )
    withTestedInstanceThrows(
      SessionMissing.self
    ) { (testedInstance: SessionNetworkRequestExecutor) in
      try await testedInstance.execute(.none)
    }
  }

  func test_execute_throws_whenEnsuringAccessTokenThrows() {
    patch(
      \SessionState.account,
      with: always(.valid)
    )
    patch(
      \SessionStateEnsurance.accessToken,
      with: alwaysThrow(MockIssue.error())
    )
    withTestedInstanceThrows(
      MockIssue.self
    ) { (testedInstance: SessionNetworkRequestExecutor) in
      try await testedInstance.execute(.none)
    }
  }

  func test_execute_executesRequest_withValidSession() {
    patch(
      \SessionState.account,
      with: always(.valid)
    )
    patch(
      \SessionStateEnsurance.accessToken,
      with: always(.valid)
    )
    patch(
      \SessionState.mfaToken,
      with: always(.none)
    )
    patch(
      \NetworkRequestExecutor.execute,
      with: always(
        self.executed(
          returning: .init(
            url: .test,
            statusCode: 200,
            headers: [:],
            body: .empty
          )
        )
      )
    )
    withTestedInstanceExecuted { (testedInstance: SessionNetworkRequestExecutor) in
      // ignore error
      try? await testedInstance.execute(.none)
    }
  }

  func test_execute_throws_whenRequestExecutionThrows() {
    patch(
      \SessionState.account,
      with: always(.valid)
    )
    patch(
      \SessionStateEnsurance.accessToken,
      with: always(.valid)
    )
    patch(
      \SessionState.mfaToken,
      with: always(.none)
    )
    patch(
      \NetworkRequestExecutor.execute,
      with: alwaysThrow(MockIssue.error())
    )
    withTestedInstanceThrows(
      MockIssue.self
    ) { (testedInstance: SessionNetworkRequestExecutor) in
      try await testedInstance.execute(.none)
    }
  }

  func test_execute_returnsResponse_whenRequestSucceeds() {
    patch(
      \SessionState.account,
      with: always(.valid)
    )
    patch(
      \SessionStateEnsurance.accessToken,
      with: always(.valid)
    )
    patch(
      \SessionState.mfaToken,
      with: always(.none)
    )
    patch(
      \NetworkRequestExecutor.execute,
      with: always(
        .init(
          url: .test,
          statusCode: 200,
          headers: [:],
          body: .empty
        )
      )
    )
    withTestedInstanceReturnsEqual(
      HTTPResponse(
        url: .test,
        statusCode: 200,
        headers: [:],
        body: .empty
      )
    ) { (testedInstance: SessionNetworkRequestExecutor) in
      try await testedInstance.execute(.none)
    }
  }
}
