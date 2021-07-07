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

  override func setUp() {
    super.setUp()

    features.use(AccountSession.placeholder)
  }

  override func tearDown() {
    super.tearDown()
  }

  func test_biometricsStatePublisher_publishesStateNone_whenProfileHasBiometricsDisabled_andBiometricsIsUnconfigured() {
    var accountSettings: AccountSettings = .placeholder
    accountSettings.accountProfilePublisher = always(Just(validAccountProfile).eraseToAnyPublisher())
    features.use(accountSettings)
    var biometry: Biometry = .placeholder
    biometry.biometricsStateChangesPublisher = always(Just(.unconfigured).eraseToAnyPublisher())
    features.use(biometry)
    features.use(LinkOpener.placeholder)

    let controller: SettingsController = testInstance()
    var result: SettingsController.BiometricsState!

    controller.biometricsPublisher()
      .sink { state in
        result = state
      }
      .store(in: cancellables)

    XCTAssertEqual(result, SettingsController.BiometricsState.none)
  }

  func test_biometricsStatePublisher_publishesStateFaceIDEnabled_whenProfileHasBiometricsEnabled_andBiometricsIsFaceID() {
    var currentAccountProfile: AccountProfile = validAccountProfile
    currentAccountProfile.biometricsEnabled = true
    var accountSettings: AccountSettings = .placeholder
    accountSettings.accountProfilePublisher = always(Just(currentAccountProfile).eraseToAnyPublisher())
    features.use(accountSettings)
    var biometry: Biometry = .placeholder
    biometry.biometricsStateChangesPublisher = always(Just(.configuredFaceID).eraseToAnyPublisher())
    features.use(biometry)
    features.use(LinkOpener.placeholder)

    let controller: SettingsController = testInstance()
    var result: SettingsController.BiometricsState!

    controller.biometricsPublisher()
      .sink { state in
        result = state
      }
      .store(in: cancellables)

    XCTAssertEqual(result, SettingsController.BiometricsState.faceID(enabled: true))
  }

  func test_biometricsStatePublisher_publishesStateFaceIDDisabled_whenProfileHasBiometricsDisabled_andBiometricsIsFaceID() {
    var accountSettings: AccountSettings = .placeholder
    accountSettings.accountProfilePublisher = always(Just(validAccountProfile).eraseToAnyPublisher())
    features.use(accountSettings)
    var biometry: Biometry = .placeholder
    biometry.biometricsStateChangesPublisher = always(Just(.configuredFaceID).eraseToAnyPublisher())
    features.use(biometry)
    features.use(LinkOpener.placeholder)

    let controller: SettingsController = testInstance()
    var result: SettingsController.BiometricsState!

    controller.biometricsPublisher()
      .sink { state in
        result = state
      }
      .store(in: cancellables)

    XCTAssertEqual(result, SettingsController.BiometricsState.faceID(enabled: false))
  }

  func test_biometricsStatePublisher_publishesStateTouchIDEnabled_whenProfileHasBiometricsEnabled_andBiometricsIsTouchID() {
    var currentAccountProfile: AccountProfile = validAccountProfile
    currentAccountProfile.biometricsEnabled = true
    var accountSettings: AccountSettings = .placeholder
    accountSettings.accountProfilePublisher = always(Just(currentAccountProfile).eraseToAnyPublisher())
    features.use(accountSettings)
    var biometry: Biometry = .placeholder
    biometry.biometricsStateChangesPublisher = always(Just(.configuredTouchID).eraseToAnyPublisher())
    features.use(biometry)
    features.use(LinkOpener.placeholder)

    let controller: SettingsController = testInstance()
    var result: SettingsController.BiometricsState!

    controller.biometricsPublisher()
      .sink { state in
        result = state
      }
      .store(in: cancellables)

    XCTAssertEqual(result, SettingsController.BiometricsState.touchID(enabled: true))
  }

  func test_biometricsStatePublisher_publishesStateTouchIDDisabled_whenProfileHasBiometricsDisabled_andBiometricsIsTouchID() {
    var accountSettings: AccountSettings = .placeholder
    accountSettings.accountProfilePublisher = always(Just(validAccountProfile).eraseToAnyPublisher())
    features.use(accountSettings)
    var biometry: Biometry = .placeholder
    biometry.biometricsStateChangesPublisher = always(Just(.configuredTouchID).eraseToAnyPublisher())
    features.use(biometry)
    features.use(LinkOpener.placeholder)

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
    var currentAccountProfile: AccountProfile = validAccountProfile
    var accountSettings: AccountSettings = .placeholder
    let accountProfilePublisher: PassthroughSubject<AccountProfile, Never> = .init()
    accountSettings.accountProfilePublisher = always(accountProfilePublisher.eraseToAnyPublisher())
    accountSettings.biometricsEnabledPublisher = always(
      accountProfilePublisher
        .map(\.biometricsEnabled)
        .eraseToAnyPublisher()
    )
    accountProfilePublisher.send(currentAccountProfile)
    accountSettings.setBiometricsEnabled = always(Empty().eraseToAnyPublisher())
    features.use(accountSettings)
    var biometry: Biometry = .placeholder
    biometry.biometricsStateChangesPublisher = always(Just(.configuredFaceID).eraseToAnyPublisher())
    features.use(biometry)
    features.use(LinkOpener.placeholder)

    let controller: SettingsController = testInstance()
    var result: SettingsController.BiometricsState!

    controller.biometricsPublisher()
      .sink { state in
        result = state
      }
      .store(in: cancellables)

    currentAccountProfile.biometricsEnabled = true
    accountProfilePublisher.send(currentAccountProfile)

    XCTAssertEqual(result, SettingsController.BiometricsState.faceID(enabled: true))
  }

  func test_biometricChangeBiometrics_fromEnabled_toDisabled_triggersBiometricsDisableAlertPublisher() {
    var accountSettings: AccountSettings = .placeholder
    accountSettings.setBiometricsEnabled = always(Empty().eraseToAnyPublisher())
    accountSettings.biometricsEnabledPublisher = always(Just(true).eraseToAnyPublisher())
    var biometry: Biometry = .placeholder
    biometry.biometricsStateChangesPublisher = always(Just(.configuredFaceID).eraseToAnyPublisher())
    features.use(accountSettings)
    features.use(biometry)
    features.use(LinkOpener.placeholder)

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

  func test_openLink_withValidURL_Succeeds() {
    var accountSettings: AccountSettings = .placeholder
    accountSettings.accountProfilePublisher = always(Just(validAccountProfile).eraseToAnyPublisher())
    features.use(accountSettings)
    var biometry: Biometry = .placeholder
    biometry.biometricsStateChangesPublisher = always(Just(.unconfigured).eraseToAnyPublisher())
    features.use(biometry)

    var linkOpener: LinkOpener = .placeholder
    linkOpener.openLink = always(Just(true).eraseToAnyPublisher())
    features.use(linkOpener)

    let controller: SettingsController = testInstance()
    var result: Bool!

    controller.openLink("https://passbolt.com")
      .sink { value in
        result = value
      }
      .store(in: cancellables)

    XCTAssertTrue(result)
  }

  func test_openLink_withInvalidURL_Fails() {
    var accountSettings: AccountSettings = .placeholder
    accountSettings.accountProfilePublisher = always(Just(validAccountProfile).eraseToAnyPublisher())
    features.use(accountSettings)
    var biometry: Biometry = .placeholder
    biometry.biometricsStateChangesPublisher = always(Just(.unconfigured).eraseToAnyPublisher())
    features.use(biometry)

    var linkOpener: LinkOpener = .placeholder
    linkOpener.openLink = always(Just(true).eraseToAnyPublisher())
    features.use(linkOpener)

    let controller: SettingsController = testInstance()
    var result: Bool!

    controller.openLink("")
      .sink { value in
        result = value
      }
      .store(in: cancellables)

    XCTAssertFalse(result)
  }

  func test_signOutAlertPresentationPublisherPublishes_whenPresentSignOutAlertCalled() {
    var accountSettings: AccountSettings = .placeholder
    accountSettings.accountProfilePublisher = always(Just(validAccountProfile).eraseToAnyPublisher())
    features.use(accountSettings)
    var biometry: Biometry = .placeholder
    biometry.biometricsStateChangesPublisher = always(Just(.unconfigured).eraseToAnyPublisher())
    features.use(biometry)
    features.use(LinkOpener.placeholder)

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
}

private let validAccountProfile: AccountProfile = .init(
  accountID: .init(rawValue: UUID.test.uuidString),
  label: "firstName lastName",
  username: "username",
  firstName: "firstName",
  lastName: "lastName",
  avatarImageURL: "avatarImagePath",
  biometricsEnabled: false
)
