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

@testable import PassboltAccountSetup

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class AccountDataExportTests: LoadableFeatureTestCase<AccountDataExport> {

  override class var testedImplementationScope: any FeaturesScope.Type {
    AccountTransferScope.self
  }

  override class func testedImplementationRegister(
    _ registry: inout FeaturesRegistry
  ) {
    registry.usePassboltAccountDataExport()
  }

  override func prepare() throws {
    set(AccountTransferScope.self)
    set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_default
      )
    )
  }

  func test_exportAccountData_fails_whenSessionAuthorizationFails() {
    patch(
      \Session.authorize,
      with: alwaysThrow(MockIssue.error())
    )
    withTestedInstanceThrows(
      MockIssue.self
    ) { feature in
      try await feature.exportAccountData(.biometrics)
    }
    withTestedInstanceThrows(
      MockIssue.self
    ) { feature in
      try await feature.exportAccountData(.passphrase("passphrase"))
    }
  }

  func test_exportAccountData_fails_whenAccessingProfileFails() {
    patch(
      \Session.authorize,
      with: always(Void())
    )
    patch(
      \AccountDetails.profile,
      context: .mock_ada,
      with: alwaysThrow(MockIssue.error())
    )
    withTestedInstanceThrows(
      MockIssue.self
    ) { feature in
      try await feature.exportAccountData(.biometrics)
    }
  }

  func test_exportAccountData_fails_whenAccessingPrivateKeyFails() {
    patch(
      \Session.authorize,
      with: always(Void())
    )
    patch(
      \AccountDetails.profile,
      context: .mock_ada,
      with: always(.mock_ada)
    )
    patch(
      \AccountsDataStore.loadAccountPrivateKey,
      with: alwaysThrow(MockIssue.error())
    )
    withTestedInstanceThrows(
      MockIssue.self
    ) { feature in
      try await feature.exportAccountData(.biometrics)
    }
  }

  func test_exportAccountData_succeeds_whenAllOperationsSucceed() {
    patch(
      \Session.authorize,
      with: always(Void())
    )
    patch(
      \AccountDetails.profile,
      context: .mock_ada,
      with: always(.mock_ada)
    )
    patch(
      \AccountsDataStore.loadAccountPrivateKey,
      with: always(AccountTransferData.mock_ada.armoredKey)
    )
    withTestedInstanceReturnsEqual(
      AccountTransferData.mock_ada
    ) { feature in
      try await feature.exportAccountData(.biometrics)
    }
  }
}
