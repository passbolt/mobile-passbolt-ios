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
import Combine
import Features
import NetworkClient
import TestExtensions
import UIComponents
import XCTest

@testable import PassboltApp

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class YubikeyControllerTests: TestCase {

  var mfa: MFA!

  override func setUp() {
    super.setUp()

    mfa = .placeholder
  }

  override func tearDown() {
    super.tearDown()

    mfa = nil
  }

  func test_rememberDevicePublisher_initiallyPublishesTrue() {
    features.use(mfa)

    let controller: YubikeyController = testInstance()
    var result: Bool!

    controller.rememberDevicePublisher()
      .sink { value in
        result = value
      }
      .store(in: cancellables)

    XCTAssertTrue(result)
  }

  func test_rememberDevicePublisher_publishesFalse_whenToggleRememberDeviceIsCalled() {
    features.use(mfa)

    let controller: YubikeyController = testInstance()
    var result: Bool!

    controller.rememberDevicePublisher()
      .sink { value in
        result = value
      }
      .store(in: cancellables)

    controller.toggleRememberDevice()

    XCTAssertFalse(result)
  }

  func test_authorizeUsingOTP_succeeds() {
    mfa.authorizeUsingYubikey = always(
      Just(())
        .setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    )
    features.use(mfa)

    let controller: YubikeyController = testInstance()
    var result: Void!

    controller.authorizeUsingOTP()
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { value in
          result = value
        }
      )
      .store(in: cancellables)

    XCTAssertNotNil(result)
  }

  func test_authorizeUsingOTP_fails() {
    mfa.authorizeUsingYubikey = always(
      Fail(error: .testError()).eraseToAnyPublisher()
    )
    features.use(mfa)

    let controller: YubikeyController = testInstance()
    var result: TheError!

    controller.authorizeUsingOTP()
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }

          result = error
        },
        receiveValue: { _ in
        }
      )
      .store(in: cancellables)

    XCTAssertEqual(result.identifier, .testError)
  }
}
