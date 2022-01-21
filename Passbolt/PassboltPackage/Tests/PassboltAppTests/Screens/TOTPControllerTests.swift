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

import Commons
import Features
import NetworkClient
import TestExtensions
import UIComponents
import XCTest

@testable import Accounts
@testable import PassboltApp

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class TOTPControllerTests: TestCase {

  var networkClient: NetworkClient!
  var accounts: Accounts!
  var mfa: MFA!
  var pasteboard: Pasteboard!

  override func setUp() {
    super.setUp()
    networkClient = .placeholder
    accounts = .placeholder
    mfa = .placeholder
    pasteboard = .placeholder
  }

  override func tearDown() {
    networkClient = nil
    accounts = nil
    mfa = nil
    pasteboard = nil
    super.tearDown()
  }

  func test_statusChangePublisher_doesNotPublish_initially() {
    features.use(mfa)
    features.use(pasteboard)

    let controller: TOTPController = testInstance()

    var result: Void?
    controller
      .statusChangePublisher()
      .sink { _ in
        result = Void()
      }
      .store(in: cancellables)

    XCTAssertNil(result)
  }

  func test_statusChangePublisher_doesNotPublish_whenOTPIsShorterThanRequired() {
    features.use(mfa)
    features.use(pasteboard)

    let controller: TOTPController = testInstance()

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

  func test_statusChangePublisher_publishLoading_whenOTPProcessingStarts() {
    mfa.authorizeUsingTOTP = always(
      PassthroughSubject<Void, TheErrorLegacy>()
        .eraseToAnyPublisher()
    )
    features.use(mfa)
    features.use(pasteboard)

    let controller: TOTPController = testInstance()

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

  func test_statusChangePublisher_publishIdle_whenOTPProcessingFinishes() {
    mfa.authorizeUsingTOTP = always(
      Just(Void())
        .setFailureType(to: TheErrorLegacy.self)
        .eraseToAnyPublisher()
    )
    features.use(mfa)
    features.use(pasteboard)

    let controller: TOTPController = testInstance()

    var result: TOTPController.StatusChange?
    controller
      .statusChangePublisher()
      .sink { change in
        result = change
      }
      .store(in: cancellables)

    controller.setOTP("123456")

    if case .idle = result {
    }
    else {
      XCTFail()
    }
  }

  func test_statusChangePublisher_publishError_whenOTPProcessingFails() {
    mfa.authorizeUsingTOTP = always(
      Fail(error: .testError())
        .eraseToAnyPublisher()
    )
    features.use(mfa)
    features.use(pasteboard)

    let controller: TOTPController = testInstance()

    var result: TOTPController.StatusChange?
    controller
      .statusChangePublisher()
      .sink { change in
        result = change
      }
      .store(in: cancellables)

    controller.setOTP("123456")

    guard case let .error(error) = result
    else { return XCTFail() }
    XCTAssertEqual(error.identifier, .testError)
  }

  func test_statusChangePublisher_publishError_whenPastingOTPWithInvalidCharacters() {
    pasteboard.get = always("123abc")
    features.use(pasteboard)

    mfa.authorizeUsingTOTP = always(
      PassthroughSubject<Void, TheErrorLegacy>()
        .eraseToAnyPublisher()
    )
    features.use(mfa)

    let controller: TOTPController = testInstance()

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
    XCTAssertEqual(error.identifier, .invalidPasteValue)
  }

  func test_statusChangePublisher_publishError_whenPastingTooLongOTP() {
    pasteboard.get = always("123456789")
    features.use(pasteboard)

    mfa.authorizeUsingTOTP = always(
      PassthroughSubject<Void, TheErrorLegacy>()
        .eraseToAnyPublisher()
    )
    features.use(mfa)

    let controller: TOTPController = testInstance()

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
    XCTAssertEqual(error.identifier, .invalidPasteValue)
  }

  func test_setOTP_doesNotStartProcessing_whenOTPIsShorterThanRequired() {
    var result: Void?
    mfa.authorizeUsingTOTP = { _, _ in
      result = Void()
      return PassthroughSubject<Void, TheErrorLegacy>()
        .eraseToAnyPublisher()
    }
    features.use(mfa)
    features.use(pasteboard)

    let controller: TOTPController = testInstance()

    controller.setOTP("12345")

    XCTAssertNil(result)
  }

  func test_setOTP_startsProcessing_whenOTPMeetsRequirements() {
    var result: Void?
    mfa.authorizeUsingTOTP = { _, _ in
      result = Void()
      return PassthroughSubject<Void, TheErrorLegacy>()
        .eraseToAnyPublisher()
    }
    features.use(mfa)
    features.use(pasteboard)

    let controller: TOTPController = testInstance()

    controller.setOTP("123456")

    XCTAssertNotNil(result)
  }

  func test_pasteOTP_doesNotStartProcessing_whenPastedOTPIsShorterThanRequired() {
    pasteboard.get = always("12345")
    features.use(pasteboard)

    var result: Void?
    mfa.authorizeUsingTOTP = { _, _ in
      result = Void()
      return PassthroughSubject<Void, TheErrorLegacy>()
        .eraseToAnyPublisher()
    }
    features.use(mfa)

    let controller: TOTPController = testInstance()

    controller.pasteOTP()

    XCTAssertNil(result)
  }

  func test_pasteOTP_startsProcessing_whenPastedOTPMeetsRequirements() {
    pasteboard.get = always("123456")
    features.use(pasteboard)

    var result: Void?
    mfa.authorizeUsingTOTP = { _, _ in
      result = Void()
      return PassthroughSubject<Void, TheErrorLegacy>()
        .eraseToAnyPublisher()
    }
    features.use(mfa)

    let controller: TOTPController = testInstance()

    controller.pasteOTP()

    XCTAssertNotNil(result)
  }

  func test_pasteOTP_doesNotChangeOTP_whenPastedOTPHasInvalidCharacters() {
    pasteboard.get = always("123abc")
    features.use(pasteboard)

    mfa.authorizeUsingTOTP = always(
      PassthroughSubject<Void, TheErrorLegacy>()
        .eraseToAnyPublisher()
    )
    features.use(mfa)

    let controller: TOTPController = testInstance()

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

  func test_pasteOTP_doesNotChangeOTP_whenPastedOTPIsTooLong() {
    pasteboard.get = always("123456789")
    features.use(pasteboard)

    mfa.authorizeUsingTOTP = always(
      PassthroughSubject<Void, TheErrorLegacy>()
        .eraseToAnyPublisher()
    )
    features.use(mfa)

    let controller: TOTPController = testInstance()

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

  func test_rememberDevicePublisher_publishesTrue_initially() {
    features.use(mfa)
    features.use(pasteboard)

    let controller: TOTPController = testInstance()

    var result: Bool?
    controller
      .rememberDevicePublisher()
      .sink { remember in
        result = remember
      }
      .store(in: cancellables)

    XCTAssertEqual(result, true)
  }

  func test_toggleRememberDevice_togglesRememberDevice() {
    features.use(mfa)
    features.use(pasteboard)

    let controller: TOTPController = testInstance()

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

  func test_otpPublisher_publishesEmptyString_initially() {
    features.use(mfa)
    features.use(pasteboard)

    let controller: TOTPController = testInstance()

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
