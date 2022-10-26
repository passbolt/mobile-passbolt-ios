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

  override func mainActorSetUp() {
    features.usePlaceholder(for: Biometry.self)
    features.usePlaceholder(for: LinkOpener.self)
    features.patch(
      \AutoFill.extensionEnabledStatePublisher,
      with: always(Just(false).eraseToAnyPublisher())
    )
    features.patch(
      \Session.currentAccount,
      with: always(.mock_ada)
    )
    features.patch(
      \AccountInitialSetup.completeSetup,
      context: Account.mock_ada,
      with: always(Void())
    )
  }

  func test_presentationDestinationPublisher_doesNotPublishInitially() async throws {
    features.patch(
      \AutoFill.extensionEnabledStatePublisher,
      with: always(Just(false).eraseToAnyPublisher())
    )

    let controller: BiometricsInfoController = try await testController()

    var result: BiometricsInfoController.Destination!
    controller.presentationDestinationPublisher()
      .sink { result = $0 }
      .store(in: cancellables)

    XCTAssertNil(result)
  }

  func test_setupBiometrics_opensSystemSettings() async throws {
    var result: Void?
    let uncheckedSendableResult: UncheckedSendable<Void?> = .init(
      get: { result },
      set: { result = $0 }
    )
    features.patch(
      \LinkOpener.openSystemSettings,
      with: {
        uncheckedSendableResult.variable = Void()
        return Just(true)
          .eraseToAnyPublisher()
      }
    )
    features.patch(
      \AutoFill.extensionEnabledStatePublisher,
      with: always(
        Just(false)
          .eraseToAnyPublisher()
      )
    )
    features.patch(
      \Biometry.biometricsStatePublisher,
      with: always(
        Just(.configuredTouchID)
          .eraseToAnyPublisher()
      )
    )

    let controller: BiometricsInfoController = try await testController()

    controller.presentationDestinationPublisher()
      .sink { _ in }
      .store(in: cancellables)

    controller.setupBiometrics()

    XCTAssertNotNil(result)
  }

  func test_presentationDestinationPublisher_publishExtensionSetup_whenSkipped_andExtensionIsEnabled() async throws {
    features.patch(
      \AutoFill.extensionEnabledStatePublisher,
      with: always(
        Just(true)
          .eraseToAnyPublisher()
      )
    )

    let controller: BiometricsInfoController = try await testController()

    var result: BiometricsInfoController.Destination!
    controller.presentationDestinationPublisher()
      .sink { result = $0 }
      .store(in: cancellables)

    controller.skipSetup()

    XCTAssertEqual(result, .finish)
  }

  func test_presentationDestinationPublisher_publishExtensionSetup_whenSkipped_andExtensionIsDisabled() async throws {
    features.patch(
      \AutoFill.extensionEnabledStatePublisher,
      with: always(
        Just(false)
          .eraseToAnyPublisher()
      )
    )

    let controller: BiometricsInfoController = try await testController()

    var result: BiometricsInfoController.Destination!
    controller.presentationDestinationPublisher()
      .sink { result = $0 }
      .store(in: cancellables)

    controller.skipSetup()

    XCTAssertEqual(result, .extensionSetup)
  }

  func test_presentationDestinationPublisher_publishBiometrySetup_afterSetup_withBiometricsAvailable() async throws {
    features.patch(
      \LinkOpener.openSystemSettings,
      with: always(
        Just(true)
          .eraseToAnyPublisher()
      )
    )
    features.patch(
      \Biometry.biometricsStatePublisher,
      with: always(
        // by default it publishes current state, it is ignored so it has to publish again
        [.unconfigured, .configuredTouchID]
          .publisher
          .eraseToAnyPublisher()
      )
    )
    features.patch(
      \AutoFill.extensionEnabledStatePublisher,
      with: always(
        Just(false)
          .eraseToAnyPublisher()
      )
    )

    let controller: BiometricsInfoController = try await testController()

    var result: BiometricsInfoController.Destination!
    controller.presentationDestinationPublisher()
      .sink { result = $0 }
      .store(in: cancellables)

    controller.setupBiometrics()

    XCTAssertEqual(result, .biometricsSetup)
  }

  func test_presentationDestinationPublisher_doesNotPublish_afterSetup_withBiometricsUnavailable() async throws {
    features.patch(
      \LinkOpener.openSystemSettings,
      with: always(
        Just(true)
          .eraseToAnyPublisher()
      )
    )
    features.patch(
      \Biometry.biometricsStatePublisher,
      with: always(
        Just(.unavailable)
          .eraseToAnyPublisher()
      )
    )
    features.patch(
      \AutoFill.extensionEnabledStatePublisher,
      with: always(
        Just(false)
          .eraseToAnyPublisher()
      )
    )

    let controller: BiometricsInfoController = try await testController()

    var result: BiometricsInfoController.Destination!
    controller.presentationDestinationPublisher()
      .sink { result = $0 }
      .store(in: cancellables)

    controller.setupBiometrics()

    XCTAssertNil(result)
  }
}
