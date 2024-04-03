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

import CommonModels
import Features
import TestExtensions
import UIComponents
import XCTest

@testable import Accounts
@testable import PassboltApp

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
@MainActor
final class TOTPControllerTests: MainActorTestCase {

  override func mainActorSetUp() {
    features.patch(
      \Session.currentAccount,
      with: always(Account.mock_ada)
    )
    features.usePlaceholder(for: OSPasteboard.self)
  }

  func test_statusChangePublisher_doesNotPublish_initially() async throws {
    let controller: TOTPController = try await testController()

    var result: Void?
    controller
      .statusChangePublisher()
      .sink { _ in
        result = Void()
      }
      .store(in: cancellables)

    XCTAssertNil(result)
  }

  func test_statusChangePublisher_doesNotPublish_whenOTPIsShorterThanRequired() async throws {

    let controller: TOTPController = try await testController()

    var result: TOTPController.StatusChange?
    controller
      .statusChangePublisher()
      .sink { change in
        result = change
      }
      .store(in: cancellables)

    controller.setOTP("12345")

    XCTAssertNil(result)
  }

  func test_statusChangePublisher_publishLoading_whenOTPProcessingStarts() async throws {
    features.patch(
      \Session.authorizeMFA,
      with: always(Void())
    )

    let controller: TOTPController = try await testController()

    var result: TOTPController.StatusChange?
    controller
      .statusChangePublisher()
      .first()
      .sink { change in
        result = change
      }
      .store(in: cancellables)

    controller.setOTP("123456")

    if case .processing = result {
    }
    else {
      XCTFail()
    }
  }

  func test_statusChangePublisher_publishIdle_whenOTPProcessingFinishes() async throws {
    features.patch(
      \Session.authorizeMFA,
      with: always(Void())
    )

    let controller: TOTPController = try await testController()

    var result: TOTPController.StatusChange?
    controller
      .statusChangePublisher()
      .sink { change in
        result = change
      }
      .store(in: cancellables)

    controller.setOTP("123456")

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    if case .idle = result {
    }
    else {
      XCTFail()
    }
  }

  func test_statusChangePublisher_publishError_whenOTPProcessingFails() async throws {
    features.patch(
      \Session.authorizeMFA,
      with: alwaysThrow(MockIssue.error())
    )

    let controller: TOTPController = try await testController()

    var result: TOTPController.StatusChange?
    controller
      .statusChangePublisher()
      .sink { change in
        result = change
      }
      .store(in: cancellables)

    controller.setOTP("123456")

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    guard case let .error(error) = result
    else { return XCTFail() }
    XCTAssertError(error, matches: MockIssue.self)
  }

  func test_statusChangePublisher_publishError_whenPastingOTPWithInvalidCharacters() async throws {
    features.patch(
      \OSPasteboard.get,
      with: always("123abc")
    )

    features.patch(
      \Session.authorizeMFA,
      with: always(Void())
    )

    let controller: TOTPController = try await testController()

    var result: TOTPController.StatusChange?
    controller
      .statusChangePublisher()
      .sink { change in
        result = change
      }
      .store(in: cancellables)

    controller.pasteOTP()

    guard case let .error(error) = result
    else { return XCTFail() }
    XCTAssertError(error, matches: InvalidPasteValue.self)
  }

  func test_statusChangePublisher_publishError_whenPastingTooLongOTP() async throws {
    features.patch(
      \OSPasteboard.get,
      with: always("123456789")
    )

    features.patch(
      \Session.authorizeMFA,
      with: always(Void())
    )

    let controller: TOTPController = try await testController()

    var result: TOTPController.StatusChange?
    controller
      .statusChangePublisher()
      .sink { change in
        result = change
      }
      .store(in: cancellables)

    controller.pasteOTP()

    guard case let .error(error) = result
    else { return XCTFail() }
    XCTAssertError(error, matches: InvalidPasteValue.self)
  }

  func test_setOTP_doesNotStartProcessing_whenOTPIsShorterThanRequired() async throws {
    let result: UnsafeSendable<Void> = .init()
    features.patch(
      \Session.authorizeMFA,
      with: { (_) async throws in
        result.value = Void()
      }
    )

    let controller: TOTPController = try await testController()

    controller.setOTP("12345")

    XCTAssertNil(result.value)
  }

  func test_setOTP_startsProcessing_whenOTPMeetsRequirements() async throws {
    let result: UnsafeSendable<Void> = .init()
    features.patch(
      \Session.authorizeMFA,
      with: { (_) async throws in
        result.value = Void()
      }
    )

    let controller: TOTPController = try await testController()

    controller.setOTP("123456")

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    XCTAssertNotNil(result.value)
  }

  func test_pasteOTP_doesNotStartProcessing_whenPastedOTPIsShorterThanRequired() async throws {
    features.patch(
      \OSPasteboard.get,
      with: always("12345")
    )

    let result: UnsafeSendable<Void> = .init()
    features.patch(
      \Session.authorizeMFA,
      with: { (_) async throws in
        result.value = Void()
      }
    )

    let controller: TOTPController = try await testController()

    controller.pasteOTP()

    XCTAssertNil(result.value)
  }

  func test_pasteOTP_startsProcessing_whenPastedOTPMeetsRequirements() async throws {
    features.patch(
      \OSPasteboard.get,
      with: always("123456")
    )

    let result: UnsafeSendable<Void> = .init()
    features.patch(
      \Session.authorizeMFA,
      with: { (_) async throws in
        result.value = Void()
      }
    )

    let controller: TOTPController = try await testController()

    controller.pasteOTP()

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    XCTAssertNotNil(result.value)
  }

  func test_pasteOTP_doesNotChangeOTP_whenPastedOTPHasInvalidCharacters() async throws {
    features.patch(
      \OSPasteboard.get,
      with: always("123abc")
    )
    features.patch(
      \Session.authorizeMFA,
      with: always(Void())
    )

    let controller: TOTPController = try await testController()

    var result: String?
    controller
      .otpPublisher()
      .sink { otp in
        result = otp
      }
      .store(in: cancellables)

    controller.pasteOTP()

    XCTAssertEqual(result, "")
  }

  func test_pasteOTP_doesNotChangeOTP_whenPastedOTPIsTooLong() async throws {
    features.patch(
      \OSPasteboard.get,
      with: always("123456789")
    )

    features.patch(
      \Session.authorizeMFA,
      with: always(Void())
    )

    let controller: TOTPController = try await testController()

    var result: String?
    controller
      .otpPublisher()
      .sink { otp in
        result = otp
      }
      .store(in: cancellables)

    controller.pasteOTP()

    XCTAssertEqual(result, "")
  }

  func test_rememberDevicePublisher_publishesTrue_initially() async throws {

    let controller: TOTPController = try await testController()

    var result: Bool?
    controller
      .rememberDevicePublisher()
      .sink { remember in
        result = remember
      }
      .store(in: cancellables)

    XCTAssertEqual(result, true)
  }

  func test_toggleRememberDevice_togglesRememberDevice() async throws {

    let controller: TOTPController = try await testController()

    var result: Bool?
    controller
      .rememberDevicePublisher()
      .sink { remember in
        result = remember
      }
      .store(in: cancellables)

    controller.toggleRememberDevice()

    XCTAssertEqual(result, false)
  }

  func test_otpPublisher_publishesEmptyString_initially() async throws {

    let controller: TOTPController = try await testController()

    var result: String?
    controller
      .otpPublisher()
      .sink { otp in
        result = otp
      }
      .store(in: cancellables)

    XCTAssertEqual(result, "")
  }
}
