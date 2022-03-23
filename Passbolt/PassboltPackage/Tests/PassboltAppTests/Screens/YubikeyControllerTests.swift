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
@MainActor
final class YubikeyControllerTests: MainActorTestCase {

  var mfa: MFA!

  override func mainActorSetUp() {
    mfa = .placeholder
  }

  override func mainActorTearDown() {
    mfa = nil
  }

  func test_rememberDevicePublisher_initiallyPublishesTrue() async throws {
    await features.use(mfa)

    let controller: YubikeyController = try await testController()
    var result: Bool!

    controller.rememberDevicePublisher()
      .sink { value in
        result = value
      }
      .store(in: cancellables)

    XCTAssertTrue(result)
  }

  func test_rememberDevicePublisher_publishesFalse_whenToggleRememberDeviceIsCalled() async throws {
    await features.use(mfa)

    let controller: YubikeyController = try await testController()
    var result: Bool!

    controller.rememberDevicePublisher()
      .sink { value in
        result = value
      }
      .store(in: cancellables)

    controller.toggleRememberDevice()

    XCTAssertFalse(result)
  }

  func test_authorizeUsingOTP_succeeds() async throws {
    mfa.authorizeUsingYubikey = always(
      Just(())
        .eraseErrorType()
        .eraseToAnyPublisher()
    )
    await features.use(mfa)

    let controller: YubikeyController = try await testController()
    let result: Void? =
      try? await controller.authorizeUsingOTP()
      .asAsyncValue()

    XCTAssertNotNil(result)
  }

  func test_authorizeUsingOTP_fails() async throws {
    mfa.authorizeUsingYubikey = always(
      Fail(error: MockIssue.error()).eraseToAnyPublisher()
    )
    await features.use(mfa)

    let controller: YubikeyController = try await testController()
    var result: Error?
    do {
      try await controller.authorizeUsingOTP()
        .asAsyncValue()
      XCTFail()
    }
    catch {
      result = error
    }

    XCTAssertError(result, matches: MockIssue.self)
  }
}
