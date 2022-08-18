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
import TestExtensions
import UIComponents
import XCTest

@testable import PassboltApp

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
@MainActor
final class MFARootControllerTests: MainActorTestCase {

  override func mainActorSetUp() {
    features.patch(
      \Session.close,
      with: always(Void())
    )
  }

  func test_mfaProviderPublisher_initiallyPublishesFirstProvider_fromAvailableProviders() async throws {
    let providers: Array<SessionMFAProvider> = [
      .totp, .yubiKey,
    ]

    let controller: MFARootController = try await testController(context: providers)

    var result: SessionMFAProvider?
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

  func test_mfaProviderPublisher_publishesOtherProvider_whenNavigateToOtherMFACalled() async throws {
    let providers: Array<SessionMFAProvider> = [
      .totp, .yubiKey,
    ]

    let controller: MFARootController = try await testController(context: providers)

    var result: SessionMFAProvider?

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

    XCTAssertEqual(result, .yubiKey)
  }

  func test_mfaProviderPublisher_cyclesThroughProviders_whenNavigateToOtherMFACalledMultipleTimes() async throws {
    let providers: Array<SessionMFAProvider> = [
      .totp, .yubiKey,
    ]

    let controller: MFARootController = try await testController(context: providers)
    var result: Array<SessionMFAProvider> = []

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

    XCTAssertEqual(result, [.totp, .yubiKey, .totp])
  }

  func test_closeSession_succeeds() async throws {
    var result: Void?
    let unchecedSendableResult: UncheckedSendable<Void?> = .init(
      get: { result },
      set: { result = $0 }
    )
    features.patch(
      \Session.close,
      with: { _ in
        unchecedSendableResult.variable = Void()
      }
    )

    let providers: Array<SessionMFAProvider> = [
      .totp, .yubiKey,
    ]

    let controller: MFARootController = try await testController(context: providers)

    controller.closeSession()
    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)
    XCTAssertNotNil(result)
  }

  func test_isProviderSwitchingAvailable_returnsFalse_whenNoProvidersArePresent() async throws {

    let providers: Array<SessionMFAProvider> = []

    let controller: MFARootController = try await testController(context: providers)
    let result: Bool = controller.isProviderSwitchingAvailable()

    XCTAssertFalse(result)
  }

  func test_isProviderSwitchingAvailable_returnsFalse_whenSingleProviderIsPresent() async throws {
    let providers: Array<SessionMFAProvider> = [
      .totp
    ]

    let controller: MFARootController = try await testController(context: providers)
    let result: Bool = controller.isProviderSwitchingAvailable()

    XCTAssertFalse(result)
  }

  func test_isProviderSwitchingAvailable_returnsTrue_whenMoreThanOneProviderIsPresent() async throws {
    let providers: Array<SessionMFAProvider> = [
      .totp, .yubiKey,
    ]

    let controller: MFARootController = try await testController(context: providers)
    let result: Bool = controller.isProviderSwitchingAvailable()

    XCTAssertTrue(result)
  }
}
