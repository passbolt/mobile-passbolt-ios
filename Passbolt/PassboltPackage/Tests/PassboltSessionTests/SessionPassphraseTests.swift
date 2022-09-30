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
final class SessionPassphraseTests: LoadableFeatureTestCase<SessionPassphrase> {

  override class var testedImplementationRegister: (FeatureFactory) -> @MainActor () -> Void {
    FeatureFactory.usePassboltSessionPassphrase
  }

  override func prepare() throws {
    use(AccountsDataStore.placeholder)
    use(SessionStateEnsurance.placeholder)
  }

  func test_storeWithBiometry_throws_withoutSession() {
    patch(
      \SessionState.account,
      with: always(.none)
    )
    patch(
      \SessionStateEnsurance.passphrase,
      with: alwaysThrow(MockIssue.error())
    )
    withTestedInstanceThrows(
      SessionMissing.self,
      context: Account.valid
    ) { (testedInstance: SessionPassphrase) in
      try await testedInstance.storeWithBiometry(true)
    }
  }

  func test_storeWithBiometry_throws_whenEnsuringPassphraseThrows() {
    patch(
      \SessionState.account,
      with: always(.valid)
    )
    patch(
      \SessionStateEnsurance.passphrase,
      with: alwaysThrow(MockIssue.error())
    )
    withTestedInstanceThrows(
      MockIssue.self,
      context: Account.valid
    ) { (testedInstance: SessionPassphrase) in
      try await testedInstance.storeWithBiometry(true)
    }
  }

  func test_storeWithBiometry_throws_whenStoringPassphraseThrows() {
    patch(
      \SessionState.account,
      with: always(.valid)
    )
    patch(
      \SessionStateEnsurance.passphrase,
      with: always("Passphrase")
    )
    patch(
      \AccountsDataStore.storeAccountPassphrase,
      with: alwaysThrow(MockIssue.error())
    )
    withTestedInstanceThrows(
      MockIssue.self,
      context: Account.valid
    ) { (testedInstance: SessionPassphrase) in
      try await testedInstance.storeWithBiometry(true)
    }
  }

  func test_storeWithBiometry_succeeds_whenStoringPassphraseSucceeds() {
    patch(
      \SessionState.account,
      with: always(.valid)
    )
    patch(
      \SessionStateEnsurance.passphrase,
      with: always("Passphrase")
    )
    patch(
      \AccountsDataStore.storeAccountPassphrase,
      with: always(Void())
    )
    withTestedInstanceNotThrows(
      context: Account.valid
    ) { (testedInstance: SessionPassphrase) in
      try await testedInstance.storeWithBiometry(true)
    }
  }

  func test_storeWithBiometry_succeeds_whenRemovingPassphraseSucceeds() {
    patch(
      \SessionState.account,
      with: always(.valid)
    )
    patch(
      \AccountsDataStore.deleteAccountPassphrase,
      with: always(Void())
    )
    withTestedInstanceNotThrows(
      context: Account.valid
    ) { (testedInstance: SessionPassphrase) in
      try await testedInstance.storeWithBiometry(false)
    }
  }

  func test_storeWithBiometry_throws_whenRemovingPassphraseThrows() {
    patch(
      \SessionState.account,
      with: always(.valid)
    )
    patch(
      \AccountsDataStore.deleteAccountPassphrase,
      with: alwaysThrow(MockIssue.error())
    )
    withTestedInstanceThrows(
      MockIssue.self,
      context: Account.valid
    ) { (testedInstance: SessionPassphrase) in
      try await testedInstance.storeWithBiometry(false)
    }
  }
}
