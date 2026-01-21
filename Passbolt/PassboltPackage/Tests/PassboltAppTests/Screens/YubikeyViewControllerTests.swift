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
import FeatureScopes
import TestExtensions

@testable import Display
@testable import PassboltApp

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class YubikeyViewControllerTests: FeaturesTestCase {

  override func commonPrepare() {
    super.commonPrepare()
    patch(
      \Session.currentAccount,
      with: { .mock_ada }
    )
    patch(
      \Session.authorizeMFA,
      with: always(Void())
    )
  }

  func test_viewState_rememberDevice_isFalse_initially() async throws {
    let tested: YubiKeyViewController = try self.testedInstance(
      context: ()
    )

    XCTAssertFalse(tested.viewState.value.rememberDevice)
  }

  func test_viewState_alert_isNil_initially() async throws {
    let tested: YubiKeyViewController = try self.testedInstance(
      context: ()
    )

    XCTAssertNil(tested.viewState.value.alert)
  }

  func test_startScanning_callsSessionAuthorizeMFA() async throws {
    var authorizeCalled: Bool = false
    patch(
      \Session.authorizeMFA,
      with: { _ in
        authorizeCalled = true
      }
    )

    let tested: YubiKeyViewController = try self.testedInstance(
      context: ()
    )

    await tested.startScanning()

    XCTAssertTrue(authorizeCalled)
  }

  func test_startScanning_sendsError_onGenericFailure() async throws {
    patch(
      \Session.authorizeMFA,
      with: alwaysThrow(MockIssue.error())
    )

    let messagesSubscription = SnackBarMessageEvent.subscribe()

    let tested: YubiKeyViewController = try self.testedInstance(
      context: ()
    )

    await tested.startScanning()

    let payload: SnackBarMessageEvent.Payload? = try await messagesSubscription.nextEvent()
    XCTAssertNotNil(payload)
  }

  func test_startScanning_showsAlert_whenYubikeyNotRecognized() async throws {
    let validationError = NetworkRequestValidationFailure.error(
      validationViolations: [
        "body": [
          "hotp": [
            "isSameYubikeyId": "error"
          ]
        ]
      ]
    )
    patch(
      \Session.authorizeMFA,
      with: alwaysThrow(validationError)
    )

    let tested: YubiKeyViewController = try self.testedInstance(
      context: ()
    )

    await tested.startScanning()

    XCTAssertNotNil(tested.viewState.value.alert)
    XCTAssertEqual(
      "yubiKey.scan.notRecognized.title",
      tested.viewState.value.alert?.title
    )
  }

  func test_startScanning_passesRememberDeviceFlag() async throws {
    let rememberDeviceValue: CriticalState<Bool?> = .init(.none)
    patch(
      \Session.authorizeMFA,
      with: { method in
        if case .yubiKey(_, let rememberDevice) = method {
          rememberDeviceValue.set(rememberDevice)
        }
      }
    )

    let tested: YubiKeyViewController = try self.testedInstance(
      context: ()
    )

    tested.viewState.update(\.rememberDevice, to: true)
    await tested.startScanning()

    XCTAssertEqual(true, rememberDeviceValue.get())
  }
}
