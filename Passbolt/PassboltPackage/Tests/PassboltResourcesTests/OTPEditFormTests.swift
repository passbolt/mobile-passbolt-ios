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

import Accounts
import SessionData
import TestExtensions
import XCTest

@testable import PassboltResources

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class OTPEditFormTests: LoadableFeatureTestCase<OTPEditForm> {

  override class var testedImplementationScope: any FeaturesScope.Type { OTPEditScope.self }

  override class func testedImplementationRegister(
    _ registry: inout FeaturesRegistry
  ) {
    registry.usePassboltOTPEditForm()
  }

  override func prepare() throws {
    self.set(
      SessionScope.self,
      context: .init(
        account: .mock_ada,
        configuration: .mock_1
      )
    )
    self.set(OTPEditScope.self)
  }

  func test_fillFromURI_throws_withInvalidScheme() {
    withTestedInstanceThrows(
      InvalidOTPConfiguration.self
    ) { feature in
      try feature.fillFromURI("invalid://")
    }
  }

  func test_fillFromURI_throws_withInvalidType() {
    withTestedInstanceThrows(
      InvalidOTPConfiguration.self
    ) { feature in
      try feature.fillFromURI("otpauth://invalid")
    }
  }

  func test_fillFromURI_throws_withInvalidLabel() {
    withTestedInstanceThrows(
      InvalidOTPConfiguration.self
    ) { feature in
      try feature.fillFromURI("otpauth://totp?")
    }
  }

  func test_fillFromURI_throws_withWithoutParameters() {
    withTestedInstanceThrows(
      InvalidOTPConfiguration.self
    ) { feature in
      try feature.fillFromURI("otpauth://totp/Passbolt:edith@passbolt.com")
    }
  }

  func test_fillFromURI_throws_withInvalidParameters() {
    withTestedInstanceThrows(
      InvalidOTPConfiguration.self
    ) { feature in
      try feature.fillFromURI("otpauth://totp/Passbolt:edith@passbolt.com?invalid=invalid=invalid")
    }
  }

  func test_fillFromURI_throws_withMissingSecret() {
    withTestedInstanceThrows(
      InvalidOTPConfiguration.self
    ) { feature in
      try feature.fillFromURI("otpauth://totp/Passbolt:edith@passbolt.com?")
    }
  }

  func test_fillFromURI_throws_withInvalidIssuer() {
    withTestedInstanceThrows(
      InvalidOTPConfiguration.self
    ) { feature in
      try feature.fillFromURI("otpauth://totp/Passbolt:edith@passbolt.com?secret=SECRET_KEY&issuer=invalid")
    }
  }

  func test_fillFromURI_succeeds_withRequiredData() {
    withTestedInstanceNotThrows { feature in
      try feature.fillFromURI("otpauth://totp/Passbolt:edith@passbolt.com?secret=SECRET_KEY")
    }
  }

  func test_fillFromURI_succeeds_withAllParameters() {
    withTestedInstanceNotThrows { feature in
      try feature.fillFromURI(
        "otpauth://totp/Passbolt:edith@passbolt.com?secret=SECRET_KEY&issuer=Passbolt&digits=6&period=30&algorithm=SHA1"
      )
    }
  }

  func test_fillFromURI_succeeds_ignoringInvalidParameters() {
    withTestedInstanceNotThrows { feature in
      try feature.fillFromURI(
        "otpauth://totp/Passbolt:edith@passbolt.com?secret=SECRET_KEY&badissuer=Passbolt&digits=6&period=30&algorithm=invalid&unnecessary=value"
      )
    }
  }

  func test_fillFromURI_updatesState_withRequiredDataAndDefaults() {
    withTestedInstanceReturnsEqual(
      OTPEditForm.State(
        name: .valid("edith@passbolt.com"),
        uri: .valid(""),
        secret: .valid("SECRET_KEY"),
        algorithm: .valid(.sha1),
        digits: .valid(6),
        type: .totp(period: .valid(30))
      )
    ) { feature in
      try feature.fillFromURI("otpauth://totp/edith@passbolt.com?secret=SECRET_KEY")
      return feature.state()
    }
  }

  func test_fillFromURI_updatesState_withAllParameters() {
    withTestedInstanceReturnsEqual(
      OTPEditForm.State(
        name: .valid("edith@passbolt.com"),
        uri: .valid("Passbolt"),
        secret: .valid("SECRET_KEY"),
        algorithm: .valid(.sha256),
        digits: .valid(8),
        type: .totp(period: .valid(90))
      )
    ) { feature in
      try feature.fillFromURI(
        "otpauth://totp/Passbolt:edith@passbolt.com?secret=SECRET_KEY&issuer=Passbolt&digits=8&period=90&algorithm=SHA256"
      )

      return feature.state()
    }
  }

  func test_sendForm_updatesResourceEditForm_whenCreatingStandaloneOTP() {
    patch(
      \LegacyResourceEditForm.resource,
      with: always(.mock_totp)
    )
    var result: Dictionary<ResourceField, ResourceFieldValue> = .init()
    let uncheckedSendableResult: UncheckedSendable<Dictionary<ResourceField, ResourceFieldValue>> = .init(
      get: { result },
      set: { result = $0 }
    )
    patch(
      \LegacyResourceEditForm.setFieldValue,
      with: { (value, field) async throws in
        uncheckedSendableResult.variable[field] = value
      }
    )
    patch(
      \LegacyResourceEditForm.sendForm,
      with: always(.mock_1)
    )
    withTestedInstanceReturnsEqual(
      [
        .name: .string("edith@passbolt.com"),
        .uri: .string("Passbolt"),
        .totp: .otp(
          .totp(
            sharedSecret: "SECRET_KEY",
            algorithm: .sha256,
            digits: 8,
            period: 90
          )
        ),
      ] as Dictionary<ResourceField, ResourceFieldValue>
    ) { feature in
      try feature.fillFromURI(
        "otpauth://totp/Passbolt:edith@passbolt.com?secret=SECRET_KEY&issuer=Passbolt&digits=8&period=90&algorithm=SHA256"
      )
      try await feature.sendForm(.createStandalone)
      return uncheckedSendableResult.variable
    }
  }

  func test_sendForm_succeeds_whenSendingResourceFormSucceeds() {
    patch(
      \LegacyResourceEditForm.resource,
      with: always(.mock_totp)
    )

    patch(
      \LegacyResourceEditForm.setFieldValue,
      with: always(Void())
    )
    patch(
      \LegacyResourceEditForm.sendForm,
      with: always(.mock_1)
    )
    withTestedInstanceNotThrows { feature in
      try feature.fillFromURI(
        "otpauth://totp/Passbolt:edith@passbolt.com?secret=SECRET_KEY&issuer=Passbolt&digits=8&period=90&algorithm=SHA256"
      )
      try await feature.sendForm(.createStandalone)
    }
  }
}
