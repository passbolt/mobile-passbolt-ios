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
import NetworkClient
import TestExtensions
import UIComponents
import XCTest

@testable import Accounts
@testable import PassboltApp

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class SettingsScreenTests: TestCase {

  var accountSettings: AccountSettings!
  var autoFill: AutoFill!
  var biometry: Biometry!
  var featureFlags: FeatureConfig!
  var linkOpener: LinkOpener!

  override func setUp() {
    super.setUp()

    accountSettings = .placeholder
    autoFill = .placeholder
    biometry = .placeholder
    featureFlags = .placeholder
    linkOpener = .placeholder
    featureFlags.config = always(nil)
    features.use(AccountSession.placeholder)
  }

  override func tearDown() {
    super.tearDown()
  }

  func test_biometricsStatePublisher_publishesStateNone_whenProfileHasBiometricsDisabled_andBiometricsIsUnconfigured() {
    accountSettings.currentAccountProfilePublisher = always(Just(validAccountWithProfile).eraseToAnyPublisher())
    biometry.biometricsStatePublisher = always(Just(.unconfigured).eraseToAnyPublisher())
    features.use(accountSettings)
    features.use(biometry)
    features.use(autoFill)
    features.use(linkOpener)
    features.use(featureFlags)

    let controller: SettingsController = testInstance()
    var result: SettingsController.BiometricsState!

    controller.biometricsPublisher()
      .sink { state in
        result = state
      }
      .store(in: cancellables)

    XCTAssertEqual(result, SettingsController.BiometricsState.none)
  }

  func test_biometricsStatePublisher_publishesStateFaceIDEnabled_whenProfileHasBiometricsEnabled_andBiometricsIsFaceID()
  {
    var currentAccountWithProfile: AccountWithProfile = validAccountWithProfile
    currentAccountWithProfile.biometricsEnabled = true
    accountSettings.currentAccountProfilePublisher = always(Just(currentAccountWithProfile).eraseToAnyPublisher())
    biometry.biometricsStatePublisher = always(Just(.configuredFaceID).eraseToAnyPublisher())
    features.use(accountSettings)
    features.use(biometry)
    features.use(autoFill)
    features.use(featureFlags)
    features.use(linkOpener)

    let controller: SettingsController = testInstance()
    var result: SettingsController.BiometricsState!

    controller.biometricsPublisher()
      .sink { state in
        result = state
      }
      .store(in: cancellables)

    XCTAssertEqual(result, SettingsController.BiometricsState.faceID(enabled: true))
  }

  func
    test_biometricsStatePublisher_publishesStateFaceIDDisabled_whenProfileHasBiometricsDisabled_andBiometricsIsFaceID()
  {
    accountSettings.currentAccountProfilePublisher = always(Just(validAccountWithProfile).eraseToAnyPublisher())
    biometry.biometricsStatePublisher = always(Just(.configuredFaceID).eraseToAnyPublisher())
    features.use(accountSettings)
    features.use(biometry)
    features.use(autoFill)
    features.use(linkOpener)
    features.use(featureFlags)

    let controller: SettingsController = testInstance()
    var result: SettingsController.BiometricsState!

    controller.biometricsPublisher()
      .sink { state in
        result = state
      }
      .store(in: cancellables)

    XCTAssertEqual(result, SettingsController.BiometricsState.faceID(enabled: false))
  }

  func
    test_biometricsStatePublisher_publishesStateTouchIDEnabled_whenProfileHasBiometricsEnabled_andBiometricsIsTouchID()
  {
    var currentAccountWithProfile: AccountWithProfile = validAccountWithProfile
    currentAccountWithProfile.biometricsEnabled = true
    accountSettings.currentAccountProfilePublisher = always(Just(currentAccountWithProfile).eraseToAnyPublisher())
    biometry.biometricsStatePublisher = always(Just(.configuredTouchID).eraseToAnyPublisher())
    features.use(accountSettings)
    features.use(biometry)
    features.use(autoFill)
    features.use(featureFlags)
    features.use(linkOpener)

    let controller: SettingsController = testInstance()
    var result: SettingsController.BiometricsState!

    controller.biometricsPublisher()
      .sink { state in
        result = state
      }
      .store(in: cancellables)

    XCTAssertEqual(result, SettingsController.BiometricsState.touchID(enabled: true))
  }

  func
    test_biometricsStatePublisher_publishesStateTouchIDDisabled_whenProfileHasBiometricsDisabled_andBiometricsIsTouchID()
  {
    accountSettings.currentAccountProfilePublisher = always(Just(validAccountWithProfile).eraseToAnyPublisher())
    biometry.biometricsStatePublisher = always(Just(.configuredTouchID).eraseToAnyPublisher())
    features.use(accountSettings)
    features.use(biometry)
    features.use(autoFill)
    features.use(linkOpener)
    features.use(featureFlags)

    let controller: SettingsController = testInstance()
    var result: SettingsController.BiometricsState!

    controller.biometricsPublisher()
      .sink { state in
        result = state
      }
      .store(in: cancellables)

    XCTAssertEqual(result, SettingsController.BiometricsState.touchID(enabled: false))
  }

  func test_biometricChangeBiometrics_fromDisabled_toEnabled_Succeeds() {
    var currentAccountWithProfile: AccountWithProfile = validAccountWithProfile
    let accountProfilePublisher: PassthroughSubject<AccountWithProfile, Never> = .init()
    accountSettings.currentAccountProfilePublisher = always(accountProfilePublisher.eraseToAnyPublisher())
    accountSettings.biometricsEnabledPublisher = always(
      accountProfilePublisher
        .map(\.biometricsEnabled)
        .eraseToAnyPublisher()
    )
    accountProfilePublisher.send(currentAccountWithProfile)
    accountSettings.setBiometricsEnabled = always(Empty().eraseToAnyPublisher())
    biometry.biometricsStatePublisher = always(Just(.configuredFaceID).eraseToAnyPublisher())
    features.use(accountSettings)
    features.use(biometry)
    features.use(autoFill)
    features.use(linkOpener)
    features.use(featureFlags)

    let controller: SettingsController = testInstance()
    var result: SettingsController.BiometricsState!

    controller.biometricsPublisher()
      .sink { state in
        result = state
      }
      .store(in: cancellables)

    currentAccountWithProfile.biometricsEnabled = true
    accountProfilePublisher.send(currentAccountWithProfile)

    XCTAssertEqual(result, SettingsController.BiometricsState.faceID(enabled: true))
  }

  func test_biometricChangeBiometrics_fromEnabled_toDisabled_triggersBiometricsDisableAlertPublisher() {
    accountSettings.setBiometricsEnabled = always(Empty().eraseToAnyPublisher())
    accountSettings.biometricsEnabledPublisher = always(Just(true).eraseToAnyPublisher())
    biometry.biometricsStatePublisher = always(Just(.configuredFaceID).eraseToAnyPublisher())
    features.use(accountSettings)
    features.use(biometry)
    features.use(linkOpener)
    features.use(autoFill)
    features.use(featureFlags)

    let controller: SettingsController = testInstance()
    var result: Void!

    controller.biometricsDisableAlertPresentationPublisher()
      .sink { value in
        result = value
      }
      .store(in: cancellables)

    controller.toggleBiometrics()
      .sink { _ in }
      .store(in: cancellables)

    XCTAssertNotNil(result)
  }

  func test_openTerms_withValidURL_Succeeds() {
    accountSettings.currentAccountProfilePublisher = always(Just(validAccountWithProfile).eraseToAnyPublisher())
    biometry.biometricsStatePublisher = always(Just(.unconfigured).eraseToAnyPublisher())
    linkOpener.openLink = always(Just(true).eraseToAnyPublisher())
    featureFlags.config = always(
      FeatureConfig.Legal.both(
        termsURL: .init(string: "https://passbolt.com/terms")!,
        privacyPolicyURL: .init(string: "https://passbolt.com/privacy")!
      )
    )

    features.use(accountSettings)
    features.use(biometry)
    features.use(linkOpener)
    features.use(autoFill)
    features.use(featureFlags)

    let controller: SettingsController = testInstance()
    var result: Bool!

    controller.openTerms()
      .sink { value in
        result = value
      }
      .store(in: cancellables)

    XCTAssertTrue(result)
  }

  func test_openTerms_withInvalidURL_Fails() {
    accountSettings.currentAccountProfilePublisher = always(Just(validAccountWithProfile).eraseToAnyPublisher())
    biometry.biometricsStatePublisher = always(Just(.unconfigured).eraseToAnyPublisher())
    linkOpener.openLink = always(Just(true).eraseToAnyPublisher())
    featureFlags.config = always(FeatureConfig.Legal.none)

    features.use(accountSettings)
    features.use(biometry)
    features.use(linkOpener)
    features.use(autoFill)
    features.use(featureFlags)

    let controller: SettingsController = testInstance()
    var result: Bool!

    controller.openTerms()
      .sink { value in
        result = value
      }
      .store(in: cancellables)

    XCTAssertFalse(result)
  }

  func test_openPrivacyPolicy_withValidURL_Succeeds() {
    accountSettings.currentAccountProfilePublisher = always(Just(validAccountWithProfile).eraseToAnyPublisher())
    biometry.biometricsStatePublisher = always(Just(.unconfigured).eraseToAnyPublisher())
    linkOpener.openLink = always(Just(true).eraseToAnyPublisher())
    featureFlags.config = always(
      FeatureConfig.Legal.privacyPolicy(
        .init(string: "https://passbolt.com/privacy")!
      )
    )

    features.use(accountSettings)
    features.use(biometry)
    features.use(linkOpener)
    features.use(autoFill)
    features.use(featureFlags)

    let controller: SettingsController = testInstance()
    var result: Bool!

    controller.openPrivacyPolicy()
      .sink { value in
        result = value
      }
      .store(in: cancellables)

    XCTAssertTrue(result)
  }

  func test_openPrivacyPolicy_withInvalidURL_Fails() {
    accountSettings.currentAccountProfilePublisher = always(Just(validAccountWithProfile).eraseToAnyPublisher())
    biometry.biometricsStatePublisher = always(Just(.unconfigured).eraseToAnyPublisher())
    linkOpener.openLink = always(Just(true).eraseToAnyPublisher())
    featureFlags.config = always(FeatureConfig.Legal.none)
    features.use(accountSettings)
    features.use(biometry)
    features.use(linkOpener)
    features.use(autoFill)
    features.use(featureFlags)

    let controller: SettingsController = testInstance()
    var result: Bool!

    controller.openPrivacyPolicy()
      .sink { value in
        result = value
      }
      .store(in: cancellables)

    XCTAssertFalse(result)
  }

  func test_signOutAlertPresentationPublisherPublishes_whenPresentSignOutAlertCalled() {
    accountSettings.currentAccountProfilePublisher = always(Just(validAccountWithProfile).eraseToAnyPublisher())
    biometry.biometricsStatePublisher = always(Just(.unconfigured).eraseToAnyPublisher())
    features.use(accountSettings)
    features.use(biometry)
    features.use(linkOpener)
    features.use(autoFill)
    features.use(featureFlags)

    let controller: SettingsController = testInstance()
    var result: Void!

    controller.signOutAlertPresentationPublisher()
      .sink { value in
        result = value
      }
      .store(in: cancellables)

    controller.presentSignOutAlert()

    XCTAssertNotNil(result)
  }

  func test_autoFillPublisher_publishesTrue_whenAutoFill_isEnabled() {
    autoFill.extensionEnabledStatePublisher = always(Just(true).eraseToAnyPublisher())
    features.use(accountSettings)
    features.use(biometry)
    features.use(linkOpener)
    features.use(autoFill)
    features.use(featureFlags)

    let controller: SettingsController = testInstance()
    var result: Bool!

    controller.autoFillEnabledPublisher()
      .sink { enabled in
        result = enabled
      }
      .store(in: cancellables)

    XCTAssertEqual(result, true)
  }

  func test_autoFillPublisher_publishesFalse_whenAutoFill_isDisabled() {
    autoFill.extensionEnabledStatePublisher = always(Just(false).eraseToAnyPublisher())
    features.use(accountSettings)
    features.use(biometry)
    features.use(linkOpener)
    features.use(autoFill)
    features.use(featureFlags)

    let controller: SettingsController = testInstance()
    var result: Bool!

    controller.autoFillEnabledPublisher()
      .sink { enabled in
        result = enabled
      }
      .store(in: cancellables)

    XCTAssertEqual(result, false)
  }

  func test_termsEnabled_whenLegalPresent_andContainsValidUrl() {
    featureFlags.config = always(
      FeatureConfig.Legal.terms(.init(string: "https://passbolt.com/terms")!)
    )
    features.use(accountSettings)
    features.use(biometry)
    features.use(linkOpener)
    features.use(autoFill)
    features.use(featureFlags)

    let controller: SettingsController = testInstance()
    let result: Bool = controller.termsEnabled()

    XCTAssertEqual(result, true)
  }

  func test_privacyPolicyEnabled_whenLegalPresent_andContainsValidUrl() {
    featureFlags.config = always(
      FeatureConfig.Legal.privacyPolicy(.init(string: "https://passbolt.com/privacy")!)
    )
    features.use(accountSettings)
    features.use(biometry)
    features.use(linkOpener)
    features.use(autoFill)
    features.use(featureFlags)

    let controller: SettingsController = testInstance()
    let result: Bool = controller.privacyPolicyEnabled()

    XCTAssertEqual(result, true)
  }

  func test_termsDisabled_whenLegalPresent_andContainsInValidUrl() {
    featureFlags.config = always(FeatureConfig.Legal.none)
    features.use(accountSettings)
    features.use(biometry)
    features.use(linkOpener)
    features.use(autoFill)
    features.use(featureFlags)

    let controller: SettingsController = testInstance()
    let result: Bool = controller.termsEnabled()

    XCTAssertEqual(result, false)
  }

  func test_privacyPolicyDisabled_whenLegalPresent_andContainsInValidUrl() {
    featureFlags.config = always(FeatureConfig.Legal.none)
    features.use(accountSettings)
    features.use(biometry)
    features.use(linkOpener)
    features.use(autoFill)
    features.use(featureFlags)

    let controller: SettingsController = testInstance()
    let result: Bool = controller.privacyPolicyEnabled()

    XCTAssertEqual(result, false)
  }

  func test_logsViewerPresentationPublisher_doesNotPublishInitially() {
    features.use(accountSettings)
    features.use(biometry)
    features.use(linkOpener)
    features.use(autoFill)
    features.use(featureFlags)

    let controller: SettingsController = testInstance()
    var result: Bool?

    controller
      .logsViewerPresentationPublisher()
      .sink { presented in
        result = presented
      }
      .store(in: cancellables)

    XCTAssertNil(result)
  }

  func test_logsViewerPresentationPublisher_publishesTrue_whenCallingOpenLogsViewer() {
    features.use(accountSettings)
    features.use(biometry)
    features.use(linkOpener)
    features.use(autoFill)
    features.use(featureFlags)

    let controller: SettingsController = testInstance()
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

private let validAccount: Account = .init(
  localID: .init(rawValue: UUID.test.uuidString),
  domain: "passbolt.com",
  userID: .init(rawValue: UUID.test.uuidString),
  fingerprint: "fingerprint"
)

private let validAccountProfile: AccountProfile = .init(
  accountID: .init(rawValue: UUID.test.uuidString),
  label: "firstName lastName",
  username: "username",
  firstName: "firstName",
  lastName: "lastName",
  avatarImageURL: "avatarImagePath",
  biometricsEnabled: false
)

private let validAccountWithProfile: AccountWithProfile = .init(
  account: validAccount,
  profile: validAccountProfile
)
