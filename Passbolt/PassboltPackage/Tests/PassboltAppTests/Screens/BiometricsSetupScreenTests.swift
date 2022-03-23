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
@MainActor
final class BiometricsSetupScreenTests: MainActorTestCase {

  var accountSettings: AccountSettings!
  var biometry: Biometry!

  override func mainActorSetUp() {
    accountSettings = .placeholder
    biometry = .placeholder
  }

  override func mainActorTearDown() {
    accountSettings = nil
    biometry = nil
  }

  func test_destinationPresentationPublisher_doesNotPublishInitially() async throws {
    await features.use(accountSettings)
    await features.use(biometry)
    var autoFill: AutoFill = .placeholder
    autoFill.extensionEnabledStatePublisher = always(Just(false).eraseToAnyPublisher())
    await features.use(autoFill)
    let controller: BiometricsSetupController = try await testController()

    var result: BiometricsSetupController.Destination!
    controller.destinationPresentationPublisher()
      .sink { result = $0 }
      .store(in: cancellables)

    XCTAssertNil(result)
  }

  func test_destinationPresentationPublisher_publishesFinish_WhenSkipping_andExtensionIsEnabled() async throws {
    await features.use(accountSettings)
    await features.use(biometry)
    var autoFill: AutoFill = .placeholder
    autoFill.extensionEnabledStatePublisher = always(Just(true).eraseToAnyPublisher())
    await features.use(autoFill)
    let controller: BiometricsSetupController = try await testController()

    var result: BiometricsSetupController.Destination!
    controller.destinationPresentationPublisher()
      .sink { result = $0 }
      .store(in: cancellables)

    controller.skipSetup()

    XCTAssertEqual(result, .finish)
  }

  func test_destinationPresentationPublisher_publishesExtensionSetup_WhenSkipping_andExtensionIsDisabled() async throws
  {
    await features.use(accountSettings)
    await features.use(biometry)
    var autoFill: AutoFill = .placeholder
    autoFill.extensionEnabledStatePublisher = always(Just(false).eraseToAnyPublisher())
    await features.use(autoFill)
    let controller: BiometricsSetupController = try await testController()

    var result: BiometricsSetupController.Destination!
    controller.destinationPresentationPublisher()
      .sink { result = $0 }
      .store(in: cancellables)

    controller.skipSetup()

    XCTAssertEqual(result, .extensionSetup)
  }

  func test_destinationPresentationPublisher_publishesFinish_WhenSetupSucceed_andExtensionIsEnabled() async throws {
    accountSettings.setBiometricsEnabled = always(
      Just(Void()).eraseErrorType().eraseToAnyPublisher()
    )
    await features.use(accountSettings)
    await features.use(biometry)
    var autoFill: AutoFill = .placeholder
    autoFill.extensionEnabledStatePublisher = always(Just(true).eraseToAnyPublisher())
    await features.use(autoFill)
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
    accountSettings.setBiometricsEnabled = always(
      Just(Void()).eraseErrorType().eraseToAnyPublisher()
    )
    await features.use(accountSettings)
    await features.use(biometry)
    var autoFill: AutoFill = .placeholder
    autoFill.extensionEnabledStatePublisher = always(Just(false).eraseToAnyPublisher())
    await features.use(autoFill)
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
    var result: Bool!
    accountSettings.setBiometricsEnabled = { enabled in
      result = enabled
      return Just(Void()).eraseErrorType()
        .eraseToAnyPublisher()
    }
    await features.use(accountSettings)
    await features.use(biometry)
    var autoFill: AutoFill = .placeholder
    autoFill.extensionEnabledStatePublisher = always(Just(true).eraseToAnyPublisher())
    await features.use(autoFill)
    let controller: BiometricsSetupController = try await testController()

    try? await controller
      .setupBiometrics()
      .asAsyncValue()

    XCTAssertTrue(result)
  }

  func test_setupBiometrics_fails_whenBiometricsEnableFails() async throws {
    accountSettings.setBiometricsEnabled = { _ in
      Fail<Void, Error>(error: MockIssue.error())
        .eraseToAnyPublisher()
    }
    await features.use(accountSettings)
    await features.use(biometry)
    var autoFill: AutoFill = .placeholder
    autoFill.extensionEnabledStatePublisher = always(Just(false).eraseToAnyPublisher())
    await features.use(autoFill)
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
