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
final class TOTPViewControllerTests: FeaturesTestCase {

  var loadingCallbackValue: Bool = false

  override func commonPrepare() {
    super.commonPrepare()
    loadingCallbackValue = false
    patch(
      \Session.currentAccount,
      with: { .mock_ada }
    )
    patch(
      \Session.authorizeMFA,
      with: always(Void())
    )
  }

  func test_viewState_rememberDevice_isTrue_initially() async throws {
    let tested: TOTPViewController = try self.testedInstance(
      context: .init(loadingCallback: { _ in })
    )

    XCTAssertTrue(tested.viewState.value.rememberDevice)
  }

  func test_viewState_otp_isEmpty_initially() async throws {
    let tested: TOTPViewController = try self.testedInstance(
      context: .init(loadingCallback: { _ in })
    )

    XCTAssertEqual("", tested.viewState.value.otp)
  }

  func test_otpEntered_updatesViewState() async throws {
    let tested: TOTPViewController = try self.testedInstance(
      context: .init(loadingCallback: { _ in })
    )

    tested.otpEntered("123456")

    XCTAssertEqual("123456", tested.viewState.value.otp)
  }

  func test_pasteOTP_updatesOTP_whenValidOTPInPasteboard() async throws {
    patch(
      \OSPasteboard.get,
      with: always("123456")
    )

    let tested: TOTPViewController = try self.testedInstance(
      context: .init(loadingCallback: { _ in })
    )

    tested.pasteOTP()

    // Wait briefly for the async verifyCode() task to start
    try await Task.sleep(nanoseconds: 10_000_000)
    XCTAssertEqual("123456", tested.viewState.value.otp)
  }

  func test_pasteOTP_sendsError_whenInvalidOTPInPasteboard() async throws {
    patch(
      \OSPasteboard.get,
      with: always("invalid")
    )

    let messagesSubscription = SnackBarMessageEvent.subscribe()

    let tested: TOTPViewController = try self.testedInstance(
      context: .init(loadingCallback: { _ in })
    )

    tested.pasteOTP()

    let payload: SnackBarMessageEvent.Payload? = try await messagesSubscription.nextEvent()
    XCTAssertNotNil(payload)
  }

  func test_pasteOTP_sendsError_whenOTPTooShort() async throws {
    patch(
      \OSPasteboard.get,
      with: always("12345")
    )

    let messagesSubscription = SnackBarMessageEvent.subscribe()

    let tested: TOTPViewController = try self.testedInstance(
      context: .init(loadingCallback: { _ in })
    )

    tested.pasteOTP()

    let payload: SnackBarMessageEvent.Payload? = try await messagesSubscription.nextEvent()
    XCTAssertNotNil(payload)
  }

  func test_pasteOTP_sendsError_whenPasteboardEmpty() async throws {
    patch(
      \OSPasteboard.get,
      with: always(nil)
    )

    let messagesSubscription = SnackBarMessageEvent.subscribe()

    let tested: TOTPViewController = try self.testedInstance(
      context: .init(loadingCallback: { _ in })
    )

    tested.pasteOTP()

    let payload: SnackBarMessageEvent.Payload? = try await messagesSubscription.nextEvent()
    XCTAssertNotNil(payload)
  }

  func test_verifyCode_callsSessionAuthorizeMFA() async throws {
    let authorizeCalled: CriticalState<Bool> = .init(false)
    patch(
      \Session.authorizeMFA,
      with: { _ in
        authorizeCalled.set(true)
      }
    )

    let tested: TOTPViewController = try self.testedInstance(
      context: .init(loadingCallback: { _ in })
    )

    tested.otpEntered("123456")
    await tested.verifyCode()

    XCTAssertTrue(authorizeCalled.get())
  }

  func test_verifyCode_callsLoadingCallback_withTrue_beforeAuthorization() async throws {
    let expectation = XCTestExpectation(description: "Loading callback called with true")
    patch(
      \Session.authorizeMFA,
      with: { _ in
        try await Task.sleep(nanoseconds: 1_000_000_00)
      }
    )

    let tested: TOTPViewController = try self.testedInstance(
      context: .init(loadingCallback: { isLoading in
        if isLoading {
          expectation.fulfill()
        }
      })
    )

    Task {
      tested.otpEntered("123456")
      await tested.verifyCode()
    }

    await fulfillment(of: [expectation], timeout: 1.0)
  }

  func test_verifyCode_callsLoadingCallback_withFalse_afterAuthorization() async throws {
    let expectation = XCTestExpectation(description: "Loading callback called with false")
    patch(
      \Session.authorizeMFA,
      with: always(Void())
    )

    let tested: TOTPViewController = try self.testedInstance(
      context: .init(loadingCallback: { isLoading in
        if !isLoading {
          expectation.fulfill()
        }
      })
    )

    tested.otpEntered("123456")
    await tested.verifyCode()

    await fulfillment(of: [expectation], timeout: 1.0)
  }

  func test_verifyCode_sendsError_onNetworkValidationFailure() async throws {
    patch(
      \Session.authorizeMFA,
      with: alwaysThrow(
        NetworkRequestValidationFailure.error(
          validationViolations: .init()
        )
      )
    )

    let messagesSubscription = SnackBarMessageEvent.subscribe()

    let tested: TOTPViewController = try self.testedInstance(
      context: .init(loadingCallback: { _ in })
    )

    tested.otpEntered("123456")
    await tested.verifyCode()

    let payload: SnackBarMessageEvent.Payload? = try await messagesSubscription.nextEvent()
    XCTAssertEqual(
      SnackBarMessageEvent.Payload.show(.error("totp.wrong.code.error")),
      payload
    )
  }

  func test_verifyCode_sendsError_onGenericError() async throws {
    patch(
      \Session.authorizeMFA,
      with: alwaysThrow(MockIssue.error())
    )

    let messagesSubscription = SnackBarMessageEvent.subscribe()

    let tested: TOTPViewController = try self.testedInstance(
      context: .init(loadingCallback: { _ in })
    )

    tested.otpEntered("123456")
    await tested.verifyCode()

    let payload: SnackBarMessageEvent.Payload? = try await messagesSubscription.nextEvent()
    XCTAssertNotNil(payload)
  }
}
