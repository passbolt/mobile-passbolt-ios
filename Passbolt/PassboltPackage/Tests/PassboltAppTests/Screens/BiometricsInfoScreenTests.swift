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

@testable import PassboltApp

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
@MainActor
final class BiometricsInfoScreenTests: MainActorTestCase {

  var linkOpener: LinkOpener!
  var biometry: Biometry!

  override func mainActorSetUp() {
    linkOpener = .placeholder
    biometry = .placeholder
  }

  override func mainActorTearDown() {
    linkOpener = nil
    biometry = nil
  }

  func test_presentationDestinationPublisher_doesNotPublishInitially() {
    features.use(linkOpener)
    features.use(biometry)
    var autoFill: AutoFill = .placeholder
    autoFill.extensionEnabledStatePublisher = always(Just(false).eraseToAnyPublisher())
    features.use(autoFill)

    let controller: BiometricsInfoController = testController()

    var result: BiometricsInfoController.Destination!
    controller.presentationDestinationPublisher()
      .sink { result = $0 }
      .store(in: cancellables)

    XCTAssertNil(result)
  }

  func test_setupBiometrics_opensSystemSettings() {
    var result: Void!
    linkOpener.openSystemSettings = {
      result = Void()
      return Just(true).eraseToAnyPublisher()
    }
    features.use(linkOpener)
    biometry.biometricsStatePublisher = always(Just(.configuredTouchID).eraseToAnyPublisher())
    features.use(biometry)
    var autoFill: AutoFill = .placeholder
    autoFill.extensionEnabledStatePublisher = always(Just(false).eraseToAnyPublisher())
    features.use(autoFill)
    let controller: BiometricsInfoController = testController()

    controller.presentationDestinationPublisher()
      .sink { _ in }
      .store(in: cancellables)

    controller.setupBiometrics()

    XCTAssertNotNil(result)
  }

  func test_presentationDestinationPublisher_publishExtensionSetup_whenSkipped_andExtensionIsEnabled() {
    features.use(linkOpener)
    features.use(biometry)
    var autoFill: AutoFill = .placeholder
    autoFill.extensionEnabledStatePublisher = always(Just(true).eraseToAnyPublisher())
    features.use(autoFill)

    let controller: BiometricsInfoController = testController()

    var result: BiometricsInfoController.Destination!
    controller.presentationDestinationPublisher()
      .sink { result = $0 }
      .store(in: cancellables)

    controller.skipSetup()

    XCTAssertEqual(result, .finish)
  }

  func test_presentationDestinationPublisher_publishExtensionSetup_whenSkipped_andExtensionIsDisabled() {
    features.use(linkOpener)
    features.use(biometry)
    var autoFill: AutoFill = .placeholder
    autoFill.extensionEnabledStatePublisher = always(Just(false).eraseToAnyPublisher())
    features.use(autoFill)

    let controller: BiometricsInfoController = testController()

    var result: BiometricsInfoController.Destination!
    controller.presentationDestinationPublisher()
      .sink { result = $0 }
      .store(in: cancellables)

    controller.skipSetup()

    XCTAssertEqual(result, .extensionSetup)
  }

  func test_presentationDestinationPublisher_publishBiometrySetup_afterSetup_withBiometricsAvailable() {
    linkOpener.openSystemSettings = always(Just(true).eraseToAnyPublisher())
    features.use(linkOpener)
    // by default it publishes current state, it is ignored so it has to publish again
    biometry.biometricsStatePublisher = always(
      [.unconfigured, .configuredTouchID].publisher.eraseToAnyPublisher()
    )
    features.use(biometry)
    var autoFill: AutoFill = .placeholder
    autoFill.extensionEnabledStatePublisher = always(Just(false).eraseToAnyPublisher())
    features.use(autoFill)

    let controller: BiometricsInfoController = testController()

    var result: BiometricsInfoController.Destination!
    controller.presentationDestinationPublisher()
      .sink { result = $0 }
      .store(in: cancellables)

    controller.setupBiometrics()

    XCTAssertEqual(result, .biometricsSetup)
  }

  func test_presentationDestinationPublisher_doesNotPublish_afterSetup_withBiometricsUnavailable() {
    linkOpener.openSystemSettings = always(Just(true).eraseToAnyPublisher())
    features.use(linkOpener)
    biometry.biometricsStatePublisher = always(Just(.unavailable).eraseToAnyPublisher())
    features.use(biometry)
    var autoFill: AutoFill = .placeholder
    autoFill.extensionEnabledStatePublisher = always(Just(false).eraseToAnyPublisher())
    features.use(autoFill)

    let controller: BiometricsInfoController = testController()

    var result: BiometricsInfoController.Destination!
    controller.presentationDestinationPublisher()
      .sink { result = $0 }
      .store(in: cancellables)

    controller.setupBiometrics()

    XCTAssertNil(result)
  }
}
