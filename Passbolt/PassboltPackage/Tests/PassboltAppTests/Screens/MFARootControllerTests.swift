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
import CommonModels
import Features
import NetworkClient
import TestExtensions
import UIComponents
import XCTest

@testable import PassboltApp

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
@MainActor
final class MFARootControllerTests: MainActorTestCase {

  var accountSession: AccountSession!
  var mfa: MFA!

  override func mainActorSetUp() {
    accountSession = .placeholder
    mfa = .placeholder
  }

  override func mainActorTearDown() {
    accountSession = nil
    mfa = nil
  }

  func test_mfaProviderPublisher_initiallyPublishesFirstProvider_fromAvailableProviders() {
    accountSession.close = {}
    features.use(accountSession)
    features.use(mfa)

    let providers: Array<MFAProvider> = [
      .totp, .yubikey,
    ]

    let controller: MFARootController = testController(context: providers)
    var result: MFAProvider!

    controller.mfaProviderPublisher()
      .sink(
        receiveCompletion: { _ in
        },
        receiveValue: { provider in
          result = provider
        }
      )
      .store(in: cancellables)

    XCTAssertEqual(result, providers.first!)
  }

  func test_mfaProviderPublisher_publishesOtherProvider_whenNavigateToOtherMFACalled() {
    accountSession.close = {}
    features.use(accountSession)
    features.use(mfa)

    let providers: Array<MFAProvider> = [
      .totp, .yubikey,
    ]

    let controller: MFARootController = testController(context: providers)
    var result: MFAProvider!

    controller.mfaProviderPublisher()
      .sink(
        receiveCompletion: { _ in
        },
        receiveValue: { provider in
          result = provider
        }
      )
      .store(in: cancellables)

    controller.navigateToOtherMFA()

    XCTAssertEqual(result, .yubikey)
  }

  func test_mfaProviderPublisher_cyclesThroughProviders_whenNavigateToOtherMFACalledMultipleTimes() {
    accountSession.close = {}
    features.use(accountSession)
    features.use(mfa)

    let providers: Array<MFAProvider> = [
      .totp, .yubikey,
    ]

    let controller: MFARootController = testController(context: providers)
    var result: Array<MFAProvider> = []

    controller.mfaProviderPublisher()
      .sink(
        receiveCompletion: { _ in
        },
        receiveValue: { provider in
          result.append(provider)
        }
      )
      .store(in: cancellables)

    controller.navigateToOtherMFA()
    controller.navigateToOtherMFA()

    XCTAssertEqual(result, [.totp, .yubikey, .totp])
  }

  func test_closeSession_succeeds() {
    var result: Void!
    accountSession.close = {
      result = Void()
    }
    features.use(accountSession)
    features.use(mfa)

    let providers: Array<MFAProvider> = [
      .totp, .yubikey,
    ]

    let controller: MFARootController = testController(context: providers)

    controller.closeSession()

    XCTAssertNotNil(result)
  }

  func test_isProviderSwitchingAvailable_returnsFalse_whenNoProvidersArePresent() {
    accountSession.close = {}
    features.use(accountSession)
    features.use(mfa)

    let providers: Array<MFAProvider> = []

    let controller: MFARootController = testController(context: providers)
    let result: Bool = controller.isProviderSwitchingAvailable()

    XCTAssertFalse(result)
  }

  func test_isProviderSwitchingAvailable_returnsFalse_whenSingleProviderIsPresent() {
    accountSession.close = {}
    features.use(accountSession)
    features.use(mfa)

    let providers: Array<MFAProvider> = [
      .totp
    ]

    let controller: MFARootController = testController(context: providers)
    let result: Bool = controller.isProviderSwitchingAvailable()

    XCTAssertFalse(result)
  }

  func test_isProviderSwitchingAvailable_returnsTrue_whenMoreThanOneProviderIsPresent() {
    accountSession.close = {}
    features.use(accountSession)
    features.use(mfa)

    let providers: Array<MFAProvider> = [
      .totp, .yubikey,
    ]

    let controller: MFARootController = testController(context: providers)
    let result: Bool = controller.isProviderSwitchingAvailable()

    XCTAssertTrue(result)
  }
}
