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

final class OTPScanningControllerTests: LoadableFeatureTestCase<OTPScanningController> {

  override class var testedImplementationScope: any FeaturesScope.Type {
    SessionScope.self
  }

  override class func testedImplementationRegister(
    _ registry: inout FeaturesRegistry
  ) {
    registry.useLiveOTPScanningController()
  }

  override func prepare() throws {
    set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_default
      )
    )
  }

  func test_processPayload_showsErrorSnackBar_whenFillingFormFails() {
    patch(
      \OTPEditForm.fillFromURI,
      with: alwaysThrow(MockIssue.error())
    )
    withTestedInstanceReturnsEqual(
      SnackBarMessage.error(DisplayableString.localized(key: "testLocalizationKey"))
    ) { feature in
      feature.processPayload("payload")
      await self.mockExecutionControl.executeAll()
      return await feature.viewState.snackBarMessage
    }
  }

  func test_processPayload_navigatesToSuccess_whenFillingFormSucceeds() {
    patch(
      \OTPEditForm.fillFromURI,
      with: always(Void())
    )
    patch(
      \NavigationToOTPScanningSuccess.mockPerform,
      with: always(self.executed())
    )
    patch(
      \NavigationToOTPScanning.mockRevert,
      with: always(self.executed())
    )

    withTestedInstanceExecuted { feature in
      feature.processPayload("payload")
      await self.mockExecutionControl.executeAll()
      return await feature.viewState.snackBarMessage
    }
  }
}
