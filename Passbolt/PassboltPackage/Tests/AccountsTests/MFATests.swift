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
import Crypto
import Features
import NetworkClient
import TestExtensions
import XCTest

@testable import Accounts

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class MFATests: TestCase {

  var accountSession: AccountSession!

  override func featuresActorSetUp() async throws {
    try await super.featuresActorSetUp()
    accountSession = .placeholder
  }

  override func featuresActorTearDown() async throws {
    accountSession = nil
    try await super.featuresActorTearDown()
  }

  func test_authorizeUsingYubikey_succeeds_whenMFAAuthorizeSucceeds() async throws {
    accountSession.mfaAuthorize = always(
      Void()
    )
    await features.use(accountSession)

    try await FeaturesActor.execute {
      self.environment.yubikey.readNFC = {
        Just("cccccccccccggvetntitdeguhrledeeeeeeivbfeehe")
          .eraseErrorType()
          .eraseToAnyPublisher()
      }
    }

    let feature: MFA = try await testInstance()
    let result: Void? =
      try? await feature
      .authorizeUsingYubikey(false)
      .asAsyncValue()

    XCTAssertNotNil(result)
  }

  func test_authorizeUsingYubikey_fails_whenReadNFCFails() async throws {
    await features.use(accountSession)

    try await FeaturesActor.execute {
      self.environment.yubikey.readNFC = always(
        Fail(error: MockIssue.error())
          .eraseToAnyPublisher()
      )
    }

    let feature: MFA = try await testInstance()
    var result: Error?

    await feature.authorizeUsingYubikey(false)
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

    XCTAssertError(result, matches: MockIssue.self)
  }

  func test_authorizeUsingTOTP_succeeds_whenMFAAuthorizeSucceeds() async throws {
    accountSession.mfaAuthorize = always(
      Void()
    )
    await features.use(accountSession)

    let feature: MFA = try await testInstance()
    var result: Void? =
      try? await feature.authorizeUsingTOTP("totp", false)
      .asAsyncValue()

    XCTAssertNotNil(result)
  }
}

private let account: Account = .init(
  localID: "localID",
  domain: "passbolt.com",
  userID: "userID",
  fingerprint: "FINGERPRINT"
)
