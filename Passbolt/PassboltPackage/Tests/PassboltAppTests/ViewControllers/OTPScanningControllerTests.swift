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

final class OTPScanningControllerTests: FeaturesTestCase {

  override func commonPrepare() {
    super.commonPrepare()
    register(
      { $0.useLiveOTPScanningController() },
      for: OTPConfigurationScanningController.self
    )
    set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_default
      )
    )
  }

  func test_processPayload_showsErrorSnackBar_whenParsingFails() async throws {
    let feature: OTPConfigurationScanningController = try self.testedInstance()

    feature.processPayload("payload")
    await self.asyncExecutionControl.executeAll()

    await XCTAssertValue(
      equal: SnackBarMessage
        .error("error.otp.configuration.invalid")
    ) {
      feature.viewState.snackBarMessage
    }
  }

  func test_processPayload_navigatesToSuccess_whenParsingSucceeds() async throws {
    patch(
      \NavigationToOTPScanningSuccess.mockPerform,
       with: always(self.dynamicVariables.executed = Void())
    )

    let feature: OTPConfigurationScanningController = try self.testedInstance()

    feature.processPayload("otpauth://totp/Passbolt:edith@passbolt.com?secret=SECRET_KEY&issuer=Passbolt&digits=6&period=30&algorithm=SHA1")
    await self.asyncExecutionControl.executeAll()

    XCTAssertNotNil(self.dynamicVariables.getIfPresent(\.executed, of: Void.self))
  }

  func test_processPayload_doesNotNavigate_whenParsingFails() async throws {
    patch(
      \NavigationToOTPScanningSuccess.mockPerform,
       with: always(self.dynamicVariables.executed = Void())
    )

    let feature: OTPConfigurationScanningController = try self.testedInstance()

    feature.processPayload("payload")
    await self.asyncExecutionControl.executeAll()

    XCTAssertNil(self.dynamicVariables.getIfPresent(\.executed, of: Void.self))
  }


  func test_processPayload_fails_withInvalidScheme() async throws {
    let feature: OTPConfigurationScanningController = try self.testedInstance()

    feature.processPayload("invalid://")
    await self.asyncExecutionControl.executeAll()

    await XCTAssertValue(
      equal: SnackBarMessage
        .error("error.otp.configuration.invalid")
    ) {
      feature.viewState.snackBarMessage
    }
  }

  func test_processPayload_fails_withInvalidType() async throws {
    let feature: OTPConfigurationScanningController = try self.testedInstance()

    feature.processPayload("otpauth://invalid")
    await self.asyncExecutionControl.executeAll()

    await XCTAssertValue(
      equal: SnackBarMessage
        .error("error.otp.configuration.invalid")
    ) {
      feature.viewState.snackBarMessage
    }
  }

  func test_processPayload_fails_withInvalidLabel() async throws {
    let feature: OTPConfigurationScanningController = try self.testedInstance()

    feature.processPayload("otpauth://totp?")
    await self.asyncExecutionControl.executeAll()

    await XCTAssertValue(
      equal: SnackBarMessage
        .error("error.otp.configuration.invalid")
    ) {
      feature.viewState.snackBarMessage
    }
  }

  func test_processPayload_fails_withWithoutParameters() async throws {
    let feature: OTPConfigurationScanningController = try self.testedInstance()

    feature.processPayload("otpauth://totp/Passbolt:edith@passbolt.com")
    await self.asyncExecutionControl.executeAll()

    await XCTAssertValue(
      equal: SnackBarMessage
        .error("error.otp.configuration.invalid")
    ) {
      feature.viewState.snackBarMessage
    }
  }

  func test_processPayload_fails_withInvalidParameters() async throws {
    let feature: OTPConfigurationScanningController = try self.testedInstance()

    feature.processPayload("otpauth://totp/Passbolt:edith@passbolt.com?invalid=invalid=invalid")
    await self.asyncExecutionControl.executeAll()

    await XCTAssertValue(
      equal: SnackBarMessage
        .error("error.otp.configuration.invalid")
    ) {
      feature.viewState.snackBarMessage
    }
  }

  func test_processPayload_fails_withMissingSecret() async throws {
    let feature: OTPConfigurationScanningController = try self.testedInstance()

    feature.processPayload("otpauth://totp/Passbolt:edith@passbolt.com?")
    await self.asyncExecutionControl.executeAll()

    await XCTAssertValue(
      equal: SnackBarMessage
        .error("error.otp.configuration.invalid")
    ) {
      feature.viewState.snackBarMessage
    }
  }

  func test_processPayload_fails_withInvalidIssuer() async throws {
    let feature: OTPConfigurationScanningController = try self.testedInstance()

    feature.processPayload("otpauth://totp/Passbolt:edith@passbolt.com?secret=SECRET_KEY&issuer=invalid")
    await self.asyncExecutionControl.executeAll()

    await XCTAssertValue(
      equal: SnackBarMessage
        .error("error.otp.configuration.invalid")
    ) {
      feature.viewState.snackBarMessage
    }
  }

  func test_processPayload_succeeds_withRequiredData() async throws {
    patch(
      \NavigationToOTPScanningSuccess.mockPerform,
       with: always(self.dynamicVariables.executed = Void())
    )

    let feature: OTPConfigurationScanningController = try self.testedInstance()

    feature.processPayload("otpauth://totp/Passbolt:edith@passbolt.com?secret=SECRET_KEY")
    await self.asyncExecutionControl.executeAll()

    XCTAssertNotNil(self.dynamicVariables.getIfPresent(\.executed, of: Void.self))
  }

  func test_processPayload_succeeds_withAllParameters() async throws {
    patch(
      \NavigationToOTPScanningSuccess.mockPerform,
       with: always(self.dynamicVariables.executed = Void())
    )

    let feature: OTPConfigurationScanningController = try self.testedInstance()

    feature.processPayload("otpauth://totp/Passbolt:edith@passbolt.com?secret=SECRET_KEY&issuer=Passbolt&digits=6&period=30&algorithm=SHA1")
    await self.asyncExecutionControl.executeAll()

    XCTAssertNotNil(self.dynamicVariables.getIfPresent(\.executed, of: Void.self))
  }

  func test_processPayload_succeeds_ignoringInvalidParameters() async throws {
    patch(
      \NavigationToOTPScanningSuccess.mockPerform,
       with: always(self.dynamicVariables.executed = Void())
    )

    let feature: OTPConfigurationScanningController = try self.testedInstance()

    feature.processPayload("otpauth://totp/Passbolt:edith@passbolt.com?secret=SECRET_KEY&badissuer=Passbolt&digits=6&period=30&algorithm=invalid&unnecessary=value")
    await self.asyncExecutionControl.executeAll()

    XCTAssertNotNil(self.dynamicVariables.getIfPresent(\.executed, of: Void.self))
  }

  func test_processPayload_navigates_withRequiredDataAndDefaults() async throws {
    patch(
      \NavigationToOTPScanningSuccess.mockPerform,
       with: { (_, context: TOTPConfiguration) async throws in
         self.dynamicVariables.configuration = context
       }
    )

    let feature: OTPConfigurationScanningController = try self.testedInstance()

    feature.processPayload("otpauth://totp/edith@passbolt.com?secret=SECRET_KEY")
    await self.asyncExecutionControl.executeAll()

    XCTAssertEqual(
      TOTPConfiguration(
        issuer: "",
        account: "edith@passbolt.com",
        secret: .init(
          sharedSecret: "SECRET_KEY",
          algorithm: .sha1,
          digits: 6,
          period: 30
        )
      ),
      self.dynamicVariables
        .getIfPresent(
          \.configuration,
           of: TOTPConfiguration.self
        )
    )
  }

  func test_processPayload_navigates_withAllParameters() async throws {
    patch(
      \NavigationToOTPScanningSuccess.mockPerform,
       with: { (_, context: TOTPConfiguration) async throws in
         self.dynamicVariables.configuration = context
       }
    )

    let feature: OTPConfigurationScanningController = try self.testedInstance()

    feature.processPayload("otpauth://totp/Passbolt:edith@passbolt.com?secret=SECRET_KEY&issuer=Passbolt&digits=8&period=90&algorithm=SHA256")
    await self.asyncExecutionControl.executeAll()

    XCTAssertEqual(
      TOTPConfiguration(
        issuer: "Passbolt",
        account: "edith@passbolt.com",
        secret: .init(
          sharedSecret: "SECRET_KEY",
          algorithm: .sha256,
          digits: 8,
          period: 90
        )
      ),
      self.dynamicVariables
        .getIfPresent(
          \.configuration,
           of: TOTPConfiguration.self
        )
    )
  }
}
