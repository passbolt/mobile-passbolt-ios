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
import FeatureScopes
import Features
import TestExtensions
import UIComponents

@testable import PassboltApp

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
@MainActor
final class BiometricsSetupScreenTests: MainActorTestCase {

  var preferencesUpdates: UpdatesSource!

  override func mainActorSetUp() {
    features
      .set(
        SessionScope.self,
        context: .init(
          account: .mock_ada,
          configuration: .mock_1
        )
      )
    features.usePlaceholder(for: OSBiometry.self)
    features.usePlaceholder(for: ApplicationLifecycle.self)
    preferencesUpdates = .init()
    features.patch(
      \Session.currentAccount,
      with: always(Account.mock_ada)
    )
    features.patch(
      \AccountPreferences.updates,
      context: Account.mock_ada,
      with: preferencesUpdates.updates
    )
    features.patch(
      \AccountInitialSetup.completeSetup,
      context: Account.mock_ada,
      with: always(Void())
    )
  }

  override func mainActorTearDown() {
    preferencesUpdates = .none
  }

  func test_destinationPresentationPublisher_doesNotPublishInitially() async throws {
    features.patch(
      \OSExtensions.autofillExtensionEnabled,
      with: always(false)
    )

    let controller: BiometricsSetupController = try await testController()

    var result: BiometricsSetupController.Destination!
    controller.destinationPresentationPublisher()
      .sink { result = $0 }
      .store(in: cancellables)

    XCTAssertNil(result)
  }

  func test_destinationPresentationPublisher_publishesFinish_WhenSkipping_andExtensionIsEnabled() async throws {
    features.patch(
      \OSExtensions.autofillExtensionEnabled,
      with: always(true)
    )

    let controller: BiometricsSetupController = try await testController()

    var result: BiometricsSetupController.Destination!
    controller
      .destinationPresentationPublisher()
      .sink { result = $0 }
      .store(in: cancellables)

    controller.skipSetup()

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    XCTAssertEqual(result, .finish)
  }

  func test_destinationPresentationPublisher_publishesExtensionSetup_WhenSkipping_andExtensionIsDisabled() async throws
  {
    features.patch(
      \OSExtensions.autofillExtensionEnabled,
      with: always(false)
    )

    let controller: BiometricsSetupController = try await testController()

    var result: BiometricsSetupController.Destination!
    controller
      .destinationPresentationPublisher()
      .sink { result = $0 }
      .store(in: cancellables)

    controller.skipSetup()

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    XCTAssertEqual(result, .extensionSetup)
  }

  func test_destinationPresentationPublisher_publishesFinish_WhenSetupSucceed_andExtensionIsEnabled() async throws {
    features.patch(
      \AccountPreferences.storePassphrase,
      context: Account.mock_ada,
      with: always(Void())
    )
    features.patch(
      \OSExtensions.autofillExtensionEnabled,
      with: always(true)
    )

    let controller: BiometricsSetupController = try await testController()

    var result: BiometricsSetupController.Destination!
    controller.destinationPresentationPublisher()
      .sink { result = $0 }
      .store(in: cancellables)

    try? await controller.setupBiometrics()
      .asAsyncValue()

    XCTAssertEqual(result, .finish)
  }

  func test_destinationPresentationPublisher_publishesExtensionSetup_WhenSetupSucceed_andExtensionIsDisabled()
    async throws
  {
    features.patch(
      \AccountPreferences.storePassphrase,
      context: Account.mock_ada,
      with: always(Void())
    )
    features.patch(
      \OSExtensions.autofillExtensionEnabled,
      with: always(false)
    )

    let controller: BiometricsSetupController = try await testController()

    var result: BiometricsSetupController.Destination!
    controller.destinationPresentationPublisher()
      .sink { result = $0 }
      .store(in: cancellables)

    _ = try? await controller.setupBiometrics()
      .asAsyncValue()

    XCTAssertEqual(result, .extensionSetup)
  }

  func test_setupBiometrics_setsBiometricsAsEnabled() async throws {
    var result: Bool?
    let uncheckedSendableResult: UncheckedSendable<Bool?> = .init(
      get: { result },
      set: { result = $0 }
    )
    features.patch(
      \AccountPreferences.storePassphrase,
      context: Account.mock_ada,
      with: { (store) async throws in
        uncheckedSendableResult.variable = store
      }
    )
    features.patch(
      \OSExtensions.autofillExtensionEnabled,
      with: always(true)
    )

    let controller: BiometricsSetupController = try await testController()

    try? await controller
      .setupBiometrics()
      .asAsyncValue()

    XCTAssertTrue(result)
  }

  func test_setupBiometrics_fails_whenBiometricsEnableFails() async throws {
    features.patch(
      \AccountPreferences.storePassphrase,
      context: Account.mock_ada,
      with: alwaysThrow(MockIssue.error())
    )
    features.patch(
      \OSExtensions.autofillExtensionEnabled,
      with: always(false)
    )

    let controller: BiometricsSetupController = try await testController()

    var result: Error?
    do {
      try await controller.setupBiometrics()
        .asAsyncValue()
      XCTFail()
    }
    catch {
      result = error
    }

    XCTAssertError(result, matches: MockIssue.self)
  }
}
