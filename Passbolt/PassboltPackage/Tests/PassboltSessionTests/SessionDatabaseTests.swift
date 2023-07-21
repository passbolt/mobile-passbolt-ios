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
import Database
import TestExtensions

@testable import PassboltSession

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
@available(iOS 16.0.0, *)
final class SessionDatabaseTests: LoadableFeatureTestCase<SessionDatabase> {

  override class func testedImplementationRegister(
    _ registry: inout FeaturesRegistry
  ) {
    registry.usePassboltSessionDatabase()
  }

  override func prepare() throws {
    use(Session.placeholder)
    patch(
      \Session.updates,
      with: Updates()
    )
    use(SessionState.placeholder)
    use(SessionStateEnsurance.placeholder)
    use(DatabaseAccess.placeholder)
  }

  func test_connection_returnsSome_withActiveSessionWithPassphrase() {
    patch(
      \SessionState.account,
      with: always(.mock_ada)
    )
    patch(
      \SessionStateEnsurance.passphrase,
      with: always("passphrase")
    )
    patch(
      \DatabaseAccess.openConnection,
      with: always(.placeholder)
    )

    withTestedInstanceReturnsSome { (testedInstance: SessionDatabase) in
      try await testedInstance.connection()
    }
  }

  func test_connection_throws_whenOpeningConnectionFails() {
    patch(
      \SessionState.account,
      with: always(.mock_ada)
    )
    patch(
      \SessionStateEnsurance.passphrase,
      with: always("passphrase")
    )
    patch(
      \DatabaseAccess.openConnection,
      with: alwaysThrow(MockIssue.error())
    )

    withTestedInstanceThrows(DatabaseConnectionClosed.self) { (testedInstance: SessionDatabase) in
      try await testedInstance.connection()
    }
  }

  func test_connection_throws_withoutPassphrase() {
    patch(
      \SessionState.account,
      with: always(.mock_ada)
    )
    patch(
      \SessionStateEnsurance.passphrase,
      with: alwaysThrow(MockIssue.error())
    )

    withTestedInstanceThrows(DatabaseConnectionClosed.self) { (testedInstance: SessionDatabase) in
      try await testedInstance.connection()
    }
  }

  func test_connection_throws_withoutSession() {
    patch(
      \SessionState.account,
      with: always(.none)
    )

    withTestedInstanceThrows(DatabaseConnectionClosed.self) { (testedInstance: SessionDatabase) in
      try await testedInstance.connection()
    }
  }

  func test_connection_throws_withActiveSessionClosing() {
    let sessionUpdates: Updates = .init()
    patch(
      \Session.updates,
      with: sessionUpdates
    )
    patch(
      \SessionState.account,
      with: always(self.account)
    )
    patch(
      \SessionStateEnsurance.passphrase,
      with: always("passphrase")
    )
    patch(
      \DatabaseAccess.openConnection,
      with: always(.placeholder)
    )

    self.account = Account.mock_ada
    withTestedInstanceReturnsSome { (testedInstance: SessionDatabase) in
      try await testedInstance.connection()
    }

    self.account = Optional<Account>.none
    sessionUpdates.update()
    withTestedInstanceThrows(DatabaseConnectionClosed.self) { (testedInstance: SessionDatabase) in
      try await testedInstance.connection()
    }
  }
}
