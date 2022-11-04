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
import Display
import Features
import SessionData
import TestExtensions
import UIComponents
import XCTest

@testable import Accounts
@testable import PassboltApp

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
@MainActor
final class SettingsScreenTests: MainActorTestCase {

  var preferencesUpdates: UpdatesSequenceSource!

  override func mainActorSetUp() {
    features.usePlaceholder(for: DisplayNavigation.self)
    features.usePlaceholder(for: AutoFill.self)
    features.usePlaceholder(for: Biometry.self)
    features.usePlaceholder(for: LinkOpener.self)
    features.patch(
      \SessionConfiguration.configuration,
      with: always(.none)
    )
    features.patch(
      \Session.currentAccount,
      with: always(Account.mock_ada)
    )
    features.patch(
      \AccountDetails.profile,
      context: Account.mock_ada,
      with: always(AccountWithProfile.mock_ada)
    )
    features.patch(
      \AccountDetails.avatarImage,
      context: Account.mock_ada,
      with: always(.init())
    )
    preferencesUpdates = .init()
    features.patch(
      \AccountPreferences.updates,
      context: Account.mock_ada,
      with: preferencesUpdates.updatesSequence
    )
    features.patch(
      \AccountPreferences.isPassphraseStored,
      context: Account.mock_ada,
      with: always(false)
    )
  }

  override func mainActorTearDown() {
    preferencesUpdates = .none
  }

  func test_biometricsStatePublisher_publishesStateNone_whenProfileHasBiometricsDisabled_andBiometricsIsUnconfigured()
    async throws
  {
    features.patch(
      \Biometry.biometricsStatePublisher,
      with: always(
        CurrentValueSubject(.unconfigured)
          .eraseToAnyPublisher()
      )
    )

    let controller: SettingsController = try await testController()
    var result: SettingsController.BiometricsState? =
    try? await controller
      .biometricsPublisher()
      .asAsyncValue()

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    XCTAssertEqual(result, SettingsController.BiometricsState.none)
  }

  func test_biometricsStatePublisher_publishesStateFaceIDEnabled_whenProfileHasBiometricsEnabled_andBiometricsIsFaceID()
    async throws
  {
    features.patch(
      \AccountPreferences.isPassphraseStored,
      context: Account.mock_ada,
      with: always(true)
    )
    features.patch(
      \Biometry.biometricsStatePublisher,
      with: always(
        CurrentValueSubject(.configuredFaceID)
          .eraseToAnyPublisher()
      )
    )

    let controller: SettingsController = try await testController()
    var result: SettingsController.BiometricsState? =
    try? await controller
      .biometricsPublisher()
      .asAsyncValue()

    XCTAssertEqual(result, SettingsController.BiometricsState.faceID(enabled: true))
  }

  func
    test_biometricsStatePublisher_publishesStateFaceIDDisabled_whenProfileHasBiometricsDisabled_andBiometricsIsFaceID()
    async throws
  {
    features.patch(
      \Biometry.biometricsStatePublisher,
      with: always(
        CurrentValueSubject(.configuredFaceID)
          .eraseToAnyPublisher()
      )
    )

    let controller: SettingsController = try await testController()
    var result: SettingsController.BiometricsState? =
    try? await controller
      .biometricsPublisher()
      .asAsyncValue()

    XCTAssertEqual(result, SettingsController.BiometricsState.faceID(enabled: false))
  }

  func
    test_biometricsStatePublisher_publishesStateTouchIDEnabled_whenProfileHasBiometricsEnabled_andBiometricsIsTouchID()
    async throws
  {
    features.patch(
      \AccountPreferences.isPassphraseStored,
      context: Account.mock_ada,
      with: always(true)
    )
    features.patch(
      \Biometry.biometricsStatePublisher,
      with: always(
        CurrentValueSubject(.configuredTouchID)
          .eraseToAnyPublisher()
      )
    )

    let controller: SettingsController = try await testController()

    var result: SettingsController.BiometricsState? =
    try? await controller
      .biometricsPublisher()
      .asAsyncValue()

    XCTAssertEqual(result, SettingsController.BiometricsState.touchID(enabled: true))
  }

  func
    test_biometricsStatePublisher_publishesStateTouchIDDisabled_whenProfileHasBiometricsDisabled_andBiometricsIsTouchID()
    async throws
  {
    features.patch(
      \Biometry.biometricsStatePublisher,
      with: always(
        CurrentValueSubject(.configuredTouchID)
          .eraseToAnyPublisher()
      )
    )

    let controller: SettingsController = try await testController()
    var result: SettingsController.BiometricsState? =
    try? await controller
      .biometricsPublisher()
      .asAsyncValue()

    XCTAssertEqual(result, SettingsController.BiometricsState.touchID(enabled: false))
  }

  func test_biometricChangeBiometrics_fromDisabled_toEnabled_Succeeds() async throws {
    var enabled: Bool = false
    features.patch(
      \AccountPreferences.isPassphraseStored,
      context: Account.mock_ada,
      with: always(enabled)
    )
    features.patch(
      \Biometry.biometricsStatePublisher,
      with: always(
        CurrentValueSubject(.configuredFaceID)
          .eraseToAnyPublisher()
      )
    )

    let controller: SettingsController = try await testController()
    var result: SettingsController.BiometricsState!

    controller.biometricsPublisher()
      .sink { state in
        result = state
      }
      .store(in: cancellables)

    enabled = true
    preferencesUpdates.sendUpdate()

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    XCTAssertEqual(result, SettingsController.BiometricsState.faceID(enabled: true))
  }

  func test_biometricChangeBiometrics_fromEnabled_toDisabled_triggersBiometricsDisableAlertPublisher() async throws {
    var enabled: Bool = true
    features.patch(
      \AccountPreferences.isPassphraseStored,
      context: Account.mock_ada,
      with: always(enabled)
    )
    features.patch(
      \Biometry.biometricsStatePublisher,
      with: always(
        CurrentValueSubject(.configuredFaceID)
          .eraseToAnyPublisher()
      )
    )

    let controller: SettingsController = try await testController()
    var result: Void?

    controller.biometricsDisableAlertPresentationPublisher()
      .sink { value in
        result = value
      }
      .store(in: cancellables)

    controller.toggleBiometrics()
      .sink { _ in }
      .store(in: cancellables)

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    XCTAssertNotNil(result)
  }

  func test_openTerms_withValidURL_Succeeds() async throws {
    features.patch(
      \Biometry.biometricsStatePublisher,
      with: always(
        CurrentValueSubject(.unconfigured)
          .eraseToAnyPublisher()
      )
    )
    features.patch(
      \LinkOpener.openLink,
      with: always(
        Just(true)
          .eraseToAnyPublisher()
      )
    )
    features.patch(
      \SessionConfiguration.configuration,
      with: always(
        FeatureFlags.Legal.both(
          termsURL: .init(string: "https://passbolt.com/terms")!,
          privacyPolicyURL: .init(string: "https://passbolt.com/privacy")!
        )
      )
    )

    let controller: SettingsController = try await testController()
    var result: Bool?

    controller.openTerms()
      .sink { value in
        result = value
      }
      .store(in: cancellables)

    XCTAssertTrue(result)
  }

  func test_openTerms_withInvalidURL_Fails() async throws {
    features.patch(
      \Biometry.biometricsStatePublisher,
      with: always(
        CurrentValueSubject(.unconfigured)
          .eraseToAnyPublisher()
      )
    )
    features.patch(
      \LinkOpener.openLink,
      with: always(
        Just(true)
          .eraseToAnyPublisher()
      )
    )
    features.patch(
      \SessionConfiguration.configuration,
      with: always(
        FeatureFlags.Legal.none
      )
    )

    let controller: SettingsController = try await testController()
    var result: Bool?

    controller.openTerms()
      .sink { value in
        result = value
      }
      .store(in: cancellables)

    XCTAssertFalse(result)
  }

  func test_openPrivacyPolicy_withValidURL_Succeeds() async throws {
    features.patch(
      \Biometry.biometricsStatePublisher,
      with: always(
        CurrentValueSubject(.unconfigured)
          .eraseToAnyPublisher()
      )
    )
    features.patch(
      \LinkOpener.openLink,
      with: always(
        Just(true)
          .eraseToAnyPublisher()
      )
    )
    features.patch(
      \SessionConfiguration.configuration,
      with: always(
        FeatureFlags.Legal.privacyPolicy(
          .init(string: "https://passbolt.com/privacy")!
        )
      )
    )

    let controller: SettingsController = try await testController()
    var result: Bool?

    controller.openPrivacyPolicy()
      .sink { value in
        result = value
      }
      .store(in: cancellables)

    XCTAssertTrue(result)
  }

  func test_openPrivacyPolicy_withInvalidURL_Fails() async throws {
    features.patch(
      \Biometry.biometricsStatePublisher,
      with: always(
        CurrentValueSubject(.unconfigured)
          .eraseToAnyPublisher()
      )
    )
    features.patch(
      \LinkOpener.openLink,
      with: always(
        Just(true)
          .eraseToAnyPublisher()
      )
    )
    features.patch(
      \SessionConfiguration.configuration,
      with: always(FeatureFlags.Legal.none)
    )

    let controller: SettingsController = try await testController()
    var result: Bool?

    controller.openPrivacyPolicy()
      .sink { value in
        result = value
      }
      .store(in: cancellables)

    XCTAssertFalse(result)
  }

  func test_signOutAlertPresentationPublisherPublishes_whenPresentSignOutAlertCalled() async throws {
    features.patch(
      \Biometry.biometricsStatePublisher,
      with: always(
        CurrentValueSubject(.unconfigured)
          .eraseToAnyPublisher()
      )
    )

    let controller: SettingsController = try await testController()
    var result: Void?

    controller.signOutAlertPresentationPublisher()
      .sink { value in
        result = value
      }
      .store(in: cancellables)

    controller.presentSignOutAlert()

    XCTAssertNotNil(result)
  }

  func test_autoFillPublisher_publishesTrue_whenAutoFill_isEnabled() async throws {
    features.patch(
      \AutoFill.extensionEnabledStatePublisher,
      with: always(
        Just(true)
          .eraseToAnyPublisher()
      )
    )

    let controller: SettingsController = try await testController()
    var result: Bool?

    controller.autoFillEnabledPublisher()
      .sink { enabled in
        result = enabled
      }
      .store(in: cancellables)

    XCTAssertEqual(result, true)
  }

  func test_autoFillPublisher_publishesFalse_whenAutoFill_isDisabled() async throws {
    features.patch(
      \AutoFill.extensionEnabledStatePublisher,
      with: always(
        Just(false)
          .eraseToAnyPublisher()
      )
    )

    let controller: SettingsController = try await testController()
    var result: Bool?

    controller.autoFillEnabledPublisher()
      .sink { enabled in
        result = enabled
      }
      .store(in: cancellables)

    XCTAssertEqual(result, false)
  }

  func test_termsEnabled_whenLegalPresent_andContainsValidUrl() async throws {
    features.patch(
      \SessionConfiguration.configuration,
      with: always(
        FeatureFlags.Legal.terms(.init(string: "https://passbolt.com/terms")!)
      )
    )

    let controller: SettingsController = try await testController()
    let result: Bool = controller.termsEnabled()

    XCTAssertEqual(result, true)
  }

  func test_privacyPolicyEnabled_whenLegalPresent_andContainsValidUrl() async throws {
    features.patch(
      \SessionConfiguration.configuration,
      with: always(
        FeatureFlags.Legal.privacyPolicy(.init(string: "https://passbolt.com/privacy")!)
      )
    )

    let controller: SettingsController = try await testController()
    let result: Bool = controller.privacyPolicyEnabled()

    XCTAssertEqual(result, true)
  }

  func test_termsDisabled_whenLegalPresent_andContainsInValidUrl() async throws {
    features.patch(
      \SessionConfiguration.configuration,
      with: always(FeatureFlags.Legal.none)
    )

    let controller: SettingsController = try await testController()
    let result: Bool = controller.termsEnabled()

    XCTAssertEqual(result, false)
  }

  func test_privacyPolicyDisabled_whenLegalPresent_andContainsInValidUrl() async throws {
    features.patch(
      \SessionConfiguration.configuration,
      with: always(FeatureFlags.Legal.none)
    )

    let controller: SettingsController = try await testController()
    let result: Bool = controller.privacyPolicyEnabled()

    XCTAssertEqual(result, false)
  }

  func test_logsViewerPresentationPublisher_doesNotPublishInitially() async throws {

    let controller: SettingsController = try await testController()
    var result: Bool?

    controller
      .logsViewerPresentationPublisher()
      .sink { presented in
        result = presented
      }
      .store(in: cancellables)

    XCTAssertNil(result)
  }

  func test_logsViewerPresentationPublisher_publishesTrue_whenCallingOpenLogsViewer() async throws {

    let controller: SettingsController = try await testController()
    var result: Bool?

    controller
      .logsViewerPresentationPublisher()
      .sink { presented in
        result = presented
      }
      .store(in: cancellables)

    controller.openLogsViewer()

    XCTAssertTrue(result ?? false)
  }
}
