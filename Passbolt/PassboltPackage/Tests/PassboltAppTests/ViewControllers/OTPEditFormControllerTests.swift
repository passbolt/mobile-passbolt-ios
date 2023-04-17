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

final class OTPEditFormControllerTests: LoadableFeatureTestCase<OTPEditFormController> {

  override class var testedImplementationScope: any FeaturesScope.Type {
    SessionScope.self
  }

  override class func testedImplementationRegister(
    _ registry: inout FeaturesRegistry
  ) {
    registry.useLiveOTPEditFormController()
  }

  override func prepare() throws {
    set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_default
      )
    )
    set(OTPEditScope.self)
  }

  func test_viewState_loadsFromFormState_initially() {
    patch(
      \OTPEditForm.state,
       with: always(
        .init(
          name: .valid("name"),
          uri: .invalid(
            "uri",
            error: MockIssue.error()
          ),
          secret: .valid(""),
          algorithm: .valid(.sha256),
          digits: .valid(7),
          type: .totp(
            period: .valid(32)
          )
        )
       )
    )
    withTestedInstanceReturnsEqual(
      OTPEditFormController.ViewState(
        nameField: .valid("name"),
        uriField: .invalid(
          "uri",
          error: MockIssue.error()
        ),
        secretField: .valid(""),
        snackBarMessage: .none
      )
    ) { feature in
      await self.mockExecutionControl.executeAll()

      return await feature.viewState.value
    }
  }
}
