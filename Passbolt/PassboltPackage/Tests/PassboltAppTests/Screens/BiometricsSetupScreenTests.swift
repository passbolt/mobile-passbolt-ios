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

  func test_continueSetupPresentationPublisher_doesNotPublishInitially() {
    features.use(accountSettings)
    features.use(biometry)
    let controller: BiometricsSetupController = testInstance()

    var result: Void!
    controller.continueSetupPresentationPublisher()
      .sink { result = $0 }
      .store(in: cancellables)

    XCTAssertNil(result)
  }

  func test_continueSetupPresentationPublisher_publishWhenSkipping() {
    features.use(accountSettings)
    features.use(biometry)
    let controller: BiometricsSetupController = testInstance()

    var result: Void!
    controller.continueSetupPresentationPublisher()
      .sink { result = $0 }
      .store(in: cancellables)

    controller.skipSetup()

    XCTAssertNotNil(result)
  }

  func test_continueSetupPresentationPublisher_publishWhenSetupSucceed() {
    accountSettings.setBiometricsEnabled = always(Empty<Never, TheError>().eraseToAnyPublisher())
    features.use(accountSettings)
    features.use(biometry)
    let controller: BiometricsSetupController = testInstance()

    var result: Void!
    controller.continueSetupPresentationPublisher()
      .sink { result = $0 }
      .store(in: cancellables)

    controller.setupBiometrics()
      .sink(receiveCompletion: { _ in })
      .store(in: cancellables)

    XCTAssertNotNil(result)
  }

  func test_setupBiometrics_setsBiometricsAsEnabled() {
    var result: Bool!
    accountSettings.setBiometricsEnabled = { enabled in
      result = enabled
      return Empty<Never, TheError>()
        .eraseToAnyPublisher()
    }
    features.use(accountSettings)
    features.use(biometry)
    let controller: BiometricsSetupController = testInstance()

    controller.setupBiometrics()
      .sink(receiveCompletion: { _ in })
      .store(in: cancellables)

    XCTAssertTrue(result)
  }

  func test_setupBiometrics_fails_whenBiometricsEnableFails() {
    accountSettings.setBiometricsEnabled = { _ in
      Fail<Never, TheError>(error: .testError())
        .eraseToAnyPublisher()
    }
    features.use(accountSettings)
    features.use(biometry)
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
