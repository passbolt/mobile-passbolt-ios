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

import Combine
import Features
import TestExtensions
import UIComponents
import XCTest

@testable import Accounts
@testable import SharedUIComponents

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
@MainActor
final class AuthorizationScreenTests: MainActorTestCase {

  var detailsUpdates: UpdatesSequenceSource!
  var preferencesUpdates: UpdatesSequenceSource!

  override func mainActorSetUp() {
    features.usePlaceholder(for: Accounts.self)
    features.usePlaceholder(for: OSBiometry.self)
    features.patch(
      \AccountDetails.profile,
      context: .mock_ada,
      with: always(.mock_ada)
    )
    features.patch(
      \AccountDetails.updateProfile,
      context: .mock_ada,
      with: always(Void())
    )
    detailsUpdates = .init()
    features.patch(
      \AccountDetails.updates,
      context: .mock_ada,
      with: detailsUpdates.updatesSequence
    )
    preferencesUpdates = .init()
    features.patch(
      \AccountPreferences.updates,
      context: .mock_ada,
      with: preferencesUpdates.updatesSequence
    )
    features.patch(
      \AccountPreferences.isPassphraseStored,
      context: .mock_ada,
      with: always(true)
    )
  }

  override func mainActorTearDown() {
    detailsUpdates = .none
    preferencesUpdates = .none
  }

  func test_presentForgotPassphraseAlertPublisher_publishesTrue_whenPresentForgotPassphraseAlertCalled() async throws {
    features.patch(
      \Accounts.storedAccounts,
      with: always([.mock_ada])
    )

    let controller: AuthorizationController = try testController(
      context: .mock_ada
    )
    var result: Bool!

    controller
      .presentForgotPassphraseAlertPublisher()
      .sink { presented in
        result = presented
      }
      .store(in: cancellables)

    controller.presentForgotPassphraseAlert()

    XCTAssertTrue(result)
  }

  func test_validatedPassphrasePublisher_publishesValidatedPassphrase_whenUpdatePassphraseCalled() async throws {
    features.patch(
      \Accounts.storedAccounts,
      with: always([.mock_ada])
    )

    let controller: AuthorizationController = try testController(
      context: .mock_ada
    )
    var result: Validated<String>!

    controller
      .validatedPassphrasePublisher()
      .sink { validated in
        result = validated
      }
      .store(in: cancellables)

    controller.updatePassphrase("SomeSecretPassphrase")

    XCTAssertEqual(result.value, "SomeSecretPassphrase")
  }

  func test_signIn_succeeds_whenAuthorizationSucceeds() async throws {
    features.patch(
      \Accounts.storedAccounts,
      with: always([.mock_ada])
    )
    features.patch(
      \Session.authorize,
      with: always(Void())
    )

    let controller: AuthorizationController = try testController(
      context: .mock_ada
    )
    let result: Bool? =
      try? await controller
      .signIn()
      .asAsyncValue()

    XCTAssertNotNil(result)
  }

  func test_signIn_fails_whenAuthorizationFails() async throws {
    features.patch(
      \Accounts.storedAccounts,
      with: always([.mock_ada])
    )
    features.patch(
      \Session.authorize,
      with: alwaysThrow(MockIssue.error())
    )

    let controller: AuthorizationController = try testController(
      context: .mock_ada
    )
    var result: Error?
    do {
      _ =
        try await controller
        .signIn()
        .asAsyncValue()
      XCTFail()
    }
    catch {
      result = error
    }

    XCTAssertError(result, matches: MockIssue.self)
  }

  func test_biometricSignIn_succeeds_whenAuthorizationSucceeds() async throws {
    features.patch(
      \Accounts.storedAccounts,
      with: always([.mock_ada])
    )
    features.patch(
      \Session.authorize,
      with: always(Void())
    )

    let controller: AuthorizationController = try testController(
      context: .mock_ada
    )
    let result: Bool? =
      try? await controller
      .biometricSignIn()
      .asAsyncValue()

    XCTAssertNotNil(result)
  }

  func test_biometricSignIn_fails_whenAuthorizationFails() async throws {
    features.patch(
      \Accounts.storedAccounts,
      with: always([.mock_ada])
    )
    features.patch(
      \Session.authorize,
      with: alwaysThrow(MockIssue.error())
    )

    let controller: AuthorizationController = try testController(
      context: .mock_ada
    )
    var result: Error?
    do {
      _ =
        try await controller
        .biometricSignIn()
        .asAsyncValue()
      XCTFail()
    }
    catch {
      result = error
    }

    XCTAssertError(result, matches: MockIssue.self)
  }

  func test_avatarPublisher_publishesData_whenNetworkRequestSucceeds() async throws {
    let testData: Data = .init([0x01, 0x02])
    features.patch(
      \Accounts.storedAccounts,
      with: always([.mock_ada])
    )
    features.patch(
      \Session.authorize,
      with: always(Void())
    )
    features.patch(
      \AccountDetails.avatarImage,
      context: .mock_ada,
      with: always(testData)
    )

    let controller: AuthorizationController = try testController(
      context: .mock_ada
    )
    let result: Data? =
      try? await controller
      .accountAvatarPublisher()
      .asAsyncValue()

    XCTAssertEqual(result, testData)
  }

  func test_avatarPublisher_publishesNil_whenNetworkRequestFails() async throws {
    features.patch(
      \Accounts.storedAccounts,
      with: always([.mock_ada])
    )
    features.patch(
      \Session.authorize,
      with: always(Void())
    )
    features.patch(
      \AccountDetails.avatarImage,
      context: .mock_ada,
      with: alwaysThrow(MockIssue.error())
    )

    let controller: AuthorizationController = try testController(
      context: .mock_ada
    )
    let result: Data? =
      try? await controller
      .accountAvatarPublisher()
      .asAsyncValue()

    XCTAssertNil(result)
  }

  func test_biometricStatePublisher_publishesUnavailable_whenBiometricsIsUnavailable() async throws {
    features.patch(
      \Accounts.storedAccounts,
      with: always([.mock_ada])
    )
    features.patch(
      \Session.authorize,
      with: always(Void())
    )
    features.patch(
      \OSBiometry.availability,
      with: always(.unavailable)
    )

    let controller: AuthorizationController = try testController(
      context: .mock_ada
    )
    let result: AuthorizationController.BiometricsState? =
      try? await controller
      .biometricStatePublisher()
      .asAsyncValue()

    XCTAssertEqual(result, .unavailable)
  }

  func test_biometricStatePublisher_publishesUnavailable_whenBiometricsIsAvailableAndAccountDoesNotUseIt() async throws
  {
    features.patch(
      \Accounts.storedAccounts,
      with: always([.mock_ada])
    )
    features.patch(
      \Session.authorize,
      with: always(Void())
    )
    features.patch(
      \AccountPreferences.isPassphraseStored,
      context: .mock_ada,
      with: always(false)
    )
    features.patch(
      \OSBiometry.availability,
      with: always(.faceID)
    )

    let controller: AuthorizationController = try testController(
      context: .mock_ada
    )
    let result: AuthorizationController.BiometricsState? =
      try? await controller
      .biometricStatePublisher()
      .asAsyncValue()

    XCTAssertEqual(result, .unavailable)
  }

  func test_biometricStatePublisher_publishesFaceID_whenAvailableBiometricsIsFaceIDAndAccountUsesIt() async throws {
    features.patch(
      \Accounts.storedAccounts,
      with: always([.mock_ada])
    )
    features.patch(
      \Session.authorize,
      with: always(Void())
    )
    features.patch(
      \OSBiometry.availability,
      with: always(.faceID)
    )

    let controller: AuthorizationController = try testController(
      context: .mock_ada
    )
    let result: AuthorizationController.BiometricsState? =
      try? await controller
      .biometricStatePublisher()
      .asAsyncValue()

    XCTAssertEqual(result, .faceID)
  }

  func test_biometricStatePublisher_publishesTouchID_whenAvailableBiometricsIsTouchIDAndAccountUsesIt() async throws {
    features.patch(
      \Accounts.storedAccounts,
      with: always([.mock_ada])
    )
    features.patch(
      \Session.authorize,
      with: always(Void())
    )
    features.patch(
      \OSBiometry.availability,
      with: always(.touchID)
    )
    features.patch(
      \AccountPreferences.isPassphraseStored,
      context: .mock_ada,
      with: always(true)
    )

    let controller: AuthorizationController = try testController(
      context: .mock_ada
    )
    let result: AuthorizationController.BiometricsState? =
      try? await controller
      .biometricStatePublisher()
      .asAsyncValue()

    XCTAssertEqual(result, .touchID)
  }
}
