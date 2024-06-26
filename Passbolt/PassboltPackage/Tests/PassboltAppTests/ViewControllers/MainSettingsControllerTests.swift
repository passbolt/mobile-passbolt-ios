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

import FeatureScopes
import TestExtensions

@testable import PassboltApp

final class MainSettingsControllerTests: FeaturesTestCase {

  override func commonPrepare() {
    super.commonPrepare()
    set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_default
      )
    )
    set(SettingsScope.self)
  }

  func test_navigateToAccountsSettings_performsNavigation() async {
    patch(
      \NavigationToAccountsSettings.mockPerform,
      with: always(self.mockExecuted())
    )
    await withInstance(
      of: MainSettingsViewController.self,
      mockExecuted: 1
    ) { feature in
      await feature.navigateToAccountsSettings()

    }
  }

  func test_navigateToTroubleshooting_performsNavigation() async {
    patch(
      \NavigationToTroubleshootingSettings.mockPerform,
      with: always(self.mockExecuted())
    )
    await withInstance(
      of: MainSettingsViewController.self,
      mockExecuted: 1
    ) { feature in
      await feature.navigateToTroubleshooting()

    }
  }

  func test_navigateToApplicationSettings_performsNavigation() async {
    patch(
      \NavigationToApplicationSettings.mockPerform,
      with: always(self.mockExecuted())
    )
    await withInstance(
      of: MainSettingsViewController.self,
      mockExecuted: 1
    ) { feature in
      await feature.navigateToApplicationSettings()

    }
  }

  func test_navigateToTermsAndLicenses_performsNavigation() async {
    patch(
      \NavigationToTermsAndLicensesSettings.mockPerform,
      with: always(self.mockExecuted())
    )
    await withInstance(
      of: MainSettingsViewController.self,
      mockExecuted: 1
    ) { feature in
      await feature.navigateToTermsAndLicenses()

    }
  }
}
