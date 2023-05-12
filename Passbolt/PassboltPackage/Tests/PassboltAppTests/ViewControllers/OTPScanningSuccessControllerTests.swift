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

final class OTPScanningSuccessControllerTests: FeaturesTestCase {

  override func commonPrepare() {
    super.commonPrepare()
    register(
      { $0.useLiveOTPScanningSuccessController() },
      for: OTPScanningSuccessController.self
    )
    set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_default
      )
    )
  }

  func test_createStandaloneOTP_navigatesBack_whenSucceeded() async throws {
    patch(
      \NavigationToOTPScanning.mockRevert,
      with: always(self.dynamicVariables.executed = Void())
    )
    patch(
      \ResourceEditForm.update,
      with: { _ async throws in
        Resource.mock_1
      }
    )
    patch(
      \ResourceEditForm.sendForm,
      with: always(.mock_1)
    )

    let feature: OTPScanningSuccessController = try self.testedInstance(
      context: .init(
        issuer: "https://passbolt.com",
        account: "user_automated@passbolt.com",
        secret: .init(
          sharedSecret: "AAAA",
          algorithm: .sha1,
          digits: 6,
          period: 30
        )
      )
    )
    feature.createStandaloneOTP()
    await self.asyncExecutionControl.executeAll()

    XCTAssertNotNil(self.dynamicVariables.getIfPresent(\.executed, of: Void.self))
  }

  func test_createStandaloneOTP_doesNotNavigate_whenFailed() async throws {
    patch(
      \NavigationToOTPScanning.mockRevert,
      with: always(self.dynamicVariables.executed = Void())
    )
    patch(
      \ResourceEditForm.update,
      with: { _ async throws in
        throw MockIssue.error()
      }
    )
    patch(
      \ResourceEditForm.sendForm,
      with: alwaysThrow(MockIssue.error())
    )

    let feature: OTPScanningSuccessController = try self.testedInstance(
      context: .init(
        issuer: "https://passbolt.com",
        account: "user_automated@passbolt.com",
        secret: .init(
          sharedSecret: "AAAA",
          algorithm: .sha1,
          digits: 6,
          period: 30
        )
      )
    )
    feature.createStandaloneOTP()
    await self.asyncExecutionControl.executeAll()

    XCTAssertNil(self.dynamicVariables.getIfPresent(\.executed, of: Void.self))
  }

  func test_createStandaloneOTP_presentsError_whenFailed() async throws {
    patch(
      \ResourceEditForm.update,
      with: { _ async throws in
        throw MockIssue.error()
      }
    )
    patch(
      \ResourceEditForm.sendForm,
      with: alwaysThrow(MockIssue.error())
    )

    let feature: OTPScanningSuccessController = try self.testedInstance(
      context: .init(
        issuer: "https://passbolt.com",
        account: "user_automated@passbolt.com",
        secret: .init(
          sharedSecret: "AAAA",
          algorithm: .sha1,
          digits: 6,
          period: 30
        )
      )
    )
    feature.createStandaloneOTP()
    await self.asyncExecutionControl.executeAll()

    await XCTAssertValue(
      equal:
        SnackBarMessage
        .error("testLocalizationKey")
    ) {
      feature.viewState.snackBarMessage
    }
  }
}
