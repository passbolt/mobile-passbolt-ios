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
import Features
import TestExtensions
import UIComponents

@testable import PassboltApp

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class BiometricsSetupScreenTests: TestCase {

  var accountSettings: AccountSettings!
  var biometry: Biometry!

  override func setUp() {
    super.setUp()
    accountSettings = .placeholder
    biometry = .placeholder
  }

  override func tearDown() {
    accountSettings = nil
    biometry = nil
    super.tearDown()
  }

  func test_destinationPresentationPublisher_doesNotPublishInitially() {
    features.use(accountSettings)
    features.use(biometry)
    var autoFill: AutoFill = .placeholder
    autoFill.isExtensionEnabled = always(Just(false).eraseToAnyPublisher())
    features.use(autoFill)
    let controller: BiometricsSetupController = testInstance()

    var result: BiometricsSetupController.Destination!
    controller.destinationPresentationPublisher()
      .sink { result = $0 }
      .store(in: cancellables)

    XCTAssertNil(result)
  }

  func test_destinationPresentationPublisher_publishesFinish_WhenSkipping_andExtensionIsEnabled() {
    features.use(accountSettings)
    features.use(biometry)
    var autoFill: AutoFill = .placeholder
    autoFill.isExtensionEnabled = always(Just(true).eraseToAnyPublisher())
    features.use(autoFill)
    let controller: BiometricsSetupController = testInstance()

    var result: BiometricsSetupController.Destination!
    controller.destinationPresentationPublisher()
      .sink { result = $0 }
      .store(in: cancellables)

    controller.skipSetup()

    XCTAssertEqual(result, .finish)
  }

  func test_destinationPresentationPublisher_publishesExtensionSetup_WhenSkipping_andExtensionIsDisabled() {
    features.use(accountSettings)
    features.use(biometry)
    var autoFill: AutoFill = .placeholder
    autoFill.isExtensionEnabled = always(Just(false).eraseToAnyPublisher())
    features.use(autoFill)
    let controller: BiometricsSetupController = testInstance()

    var result: BiometricsSetupController.Destination!
    controller.destinationPresentationPublisher()
      .sink { result = $0 }
      .store(in: cancellables)

    controller.skipSetup()

    XCTAssertEqual(result, .extensionSetup)
  }

  func test_destinationPresentationPublisher_publishesFinish_WhenSetupSucceed_andExtensionIsEnabled() {
    accountSettings.setBiometricsEnabled = always(
      Just(Void()).setFailureType(to: TheError.self).eraseToAnyPublisher()
    )
    features.use(accountSettings)
    features.use(biometry)
    var autoFill: AutoFill = .placeholder
    autoFill.isExtensionEnabled = always(Just(true).eraseToAnyPublisher())
    features.use(autoFill)
    let controller: BiometricsSetupController = testInstance()

    var result: BiometricsSetupController.Destination!
    controller.destinationPresentationPublisher()
      .sink { result = $0 }
      .store(in: cancellables)

    controller.setupBiometrics()
      .sink(receiveCompletion: { _ in })
      .store(in: cancellables)

    XCTAssertEqual(result, .finish)
  }

  func test_destinationPresentationPublisher_publishesExtensionSetup_WhenSetupSucceed_andExtensionIsDisabled() {
    accountSettings.setBiometricsEnabled = always(
      Just(Void()).setFailureType(to: TheError.self).eraseToAnyPublisher()
    )
    features.use(accountSettings)
    features.use(biometry)
    var autoFill: AutoFill = .placeholder
    autoFill.isExtensionEnabled = always(Just(false).eraseToAnyPublisher())
    features.use(autoFill)
    let controller: BiometricsSetupController = testInstance()

    var result: BiometricsSetupController.Destination!
    controller.destinationPresentationPublisher()
      .sink { result = $0 }
      .store(in: cancellables)

    controller.setupBiometrics()
      .sink(receiveCompletion: { _ in })
      .store(in: cancellables)

    XCTAssertEqual(result, .extensionSetup)
  }

  func test_setupBiometrics_setsBiometricsAsEnabled() {
    var result: Bool!
    accountSettings.setBiometricsEnabled = { enabled in
      result = enabled
      return Just(Void()).setFailureType(to: TheError.self)
        .eraseToAnyPublisher()
    }
    features.use(accountSettings)
    features.use(biometry)
    var autoFill: AutoFill = .placeholder
    autoFill.isExtensionEnabled = always(Just(true).eraseToAnyPublisher())
    features.use(autoFill)
    let controller: BiometricsSetupController = testInstance()

    controller.setupBiometrics()
      .sink(receiveCompletion: { _ in })
      .store(in: cancellables)

    XCTAssertTrue(result)
  }

  func test_setupBiometrics_fails_whenBiometricsEnableFails() {
    accountSettings.setBiometricsEnabled = { _ in
      Fail<Void, TheError>(error: .testError())
        .eraseToAnyPublisher()
    }
    features.use(accountSettings)
    features.use(biometry)
    var autoFill: AutoFill = .placeholder
    autoFill.isExtensionEnabled = always(Just(false).eraseToAnyPublisher())
    features.use(autoFill)
    let controller: BiometricsSetupController = testInstance()

    var result: TheError!
    controller.setupBiometrics()
      .sink(receiveCompletion: { completion in
        guard case let .failure(error) = completion else { return }
        result = error
      })
      .store(in: cancellables)

    XCTAssertEqual(result.identifier, .testError)
  }
}
