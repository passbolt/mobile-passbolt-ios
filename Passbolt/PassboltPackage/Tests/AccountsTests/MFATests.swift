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
import Crypto
import Features
import NetworkClient
import TestExtensions
import XCTest

@testable import Accounts

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class MFATests: TestCase {

  var accountSession: AccountSession!

  override func setUp() {
    super.setUp()
    accountSession = .placeholder
  }

  override func tearDown() {
    accountSession = nil
    super.tearDown()
  }

  func test_authorizeUsingYubikey_succeeds_whenMFAAuthorizeSucceeds() {
    accountSession.mfaAuthorize = always(
      Just(())
        .setFailureType(to: TheErrorLegacy.self)
        .eraseToAnyPublisher()
    )
    features.use(accountSession)

    environment.yubikey.readNFC = {
      Just("cccccccccccggvetntitdeguhrledeeeeeeivbfeehe")
        .setFailureType(to: TheErrorLegacy.self)
        .eraseToAnyPublisher()
    }

    let feature: MFA = testInstance()
    var result: Void?

    feature.authorizeUsingYubikey(false)
      .sink(
        receiveCompletion: { _ in
        },
        receiveValue: { value in
          result = value
        }
      )
      .store(in: cancellables)

    XCTAssertNotNil(result)
  }

  func test_authorizeUsingYubikey_fails_whenReadNFCFails() {
    features.use(accountSession)

    environment.yubikey.readNFC = always(
      Fail(error: TheErrorLegacy.yubikeyError())
        .eraseToAnyPublisher()
    )

    let feature: MFA = testInstance()
    var result: TheErrorLegacy?

    feature.authorizeUsingYubikey(false)
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

    XCTAssertEqual(result?.identifier, .yubikey)
  }

  func test_authorizeUsingTOTP_succeeds_whenMFAAuthorizeSucceeds() {
    accountSession.mfaAuthorize = always(
      Just(())
        .setFailureType(to: TheErrorLegacy.self)
        .eraseToAnyPublisher()
    )
    features.use(accountSession)

    let feature: MFA = testInstance()
    var result: Void?

    feature.authorizeUsingTOTP("totp", false)
      .sink(
        receiveCompletion: { _ in
        },
        receiveValue: { value in
          result = value
        }
      )
      .store(in: cancellables)

    XCTAssertNotNil(result)
  }
}

private let account: Account = .init(
  localID: "localID",
  domain: "passbolt.com",
  userID: "userID",
  fingerprint: "FINGERPRINT"
)
