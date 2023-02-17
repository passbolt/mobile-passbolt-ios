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

final class TermsAndLicensesSettingsControllerTests: LoadableFeatureTestCase<TermsAndLicensesSettingsController> {

  override class var testedImplementationScope: any FeaturesScope.Type {
    SettingsScope.self
  }

  override class func testedImplementationRegister(
    _ registry: inout FeaturesRegistry
  ) {
    registry.useLiveTermsAndLicensesSettingsController()
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

  func test_navigateToLicenses_opensApplicationSettings() {
    patch(
      \OSLinkOpener.openApplicationSettings,
      with: always(self.executed())
    )
    withTestedInstanceExecuted { feature in
      feature.navigateToLicenses()
      await self.mockExecutionControl.executeAll()
    }
  }

  func test_navigateToTermsAndConditions_opensTermsAndConditionsURL() {
    set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_1
      )
    )
    patch(
      \OSLinkOpener.openURL,
      with: always(self.executed())
    )
    withTestedInstanceExecuted { feature in
      feature.navigateToTermsAndConditions()
      await self.mockExecutionControl.executeAll()
    }
  }

  func test_navigateToPrivacyPolicy_opensPrivacyPolicyURL() {
    set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_1
      )
    )
    patch(
      \OSLinkOpener.openURL,
      with: always(self.executed())
    )
    withTestedInstanceExecuted { feature in
      feature.navigateToPrivacyPolicy()
      await self.mockExecutionControl.executeAll()
    }
  }

  func test_navigateToTermsAndConditions_isIgnoredWithoutURL() {
    set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        // it does not contain terms and conditions url
        configuration: .mock_default
      )
    )
    withTestedInstanceNotExecuted { feature in
      feature.navigateToTermsAndConditions()
      await self.mockExecutionControl.executeAll()
    }
  }

  func test_navigateToPrivacyPolicy_isIgnoredWithoutURL() {
    set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        // it does not contain terms and conditions url
        configuration: .mock_default
      )
    )
    patch(
      \OSLinkOpener.openURL,
      with: always(self.executed())
    )
    withTestedInstanceNotExecuted { feature in
      feature.navigateToPrivacyPolicy()
      await self.mockExecutionControl.executeAll()
    }
  }
}
