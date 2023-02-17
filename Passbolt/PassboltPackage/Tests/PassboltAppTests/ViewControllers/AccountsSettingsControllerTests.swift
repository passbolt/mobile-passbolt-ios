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

@testable import PassboltApp

final class AccountsSettingsControllerTests: LoadableFeatureTestCase<AccountsSettingsController> {

  override class var testedImplementationScope: any FeaturesScope.Type {
    SettingsScope.self
  }

  override class func testedImplementationRegister(
    _ registry: inout FeaturesRegistry
  ) {
    registry.useLiveAccountsSettingsController()
  }

  override func prepare() throws {
    set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_default
      )
    )
    set(SettingsScope.self)
  }

  func test_navigateToAccountExport_performsNavigation() {
    patch(
      \NavigationToAccountExport.mockPerform,
      with: always(self.executed())
    )
    withTestedInstanceExecuted { feature in
      feature.navigateToAccountExport()
      await self.mockExecutionControl.executeAll()
    }
  }

  func test_navigateToManageAccounts_performsNavigation() {
    patch(
      \NavigationToManageAccounts.mockPerform,
      with: always(self.executed())
    )
    withTestedInstanceExecuted { feature in
      feature.navigateToManageAccounts()
      await self.mockExecutionControl.executeAll()
    }
  }
}
