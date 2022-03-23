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
final class ExtensionSetupScreenTests: MainActorTestCase {

  var autoFill: AutoFill!
  var linkOpener: LinkOpener!

  override func mainActorSetUp() {
    autoFill = .placeholder
    linkOpener = .placeholder
  }

  override func mainActorTearDown() {
    autoFill = nil
    linkOpener = nil
  }

  func test_continueSetupPresentationPublisher_doesNotPublishInitially() async throws {
    await features.use(autoFill)
    await features.use(linkOpener)
    let controller: ExtensionSetupController = try await testController()

    var result: Void!
    controller.continueSetupPresentationPublisher()
      .sink { result = $0 }
      .store(in: cancellables)

    XCTAssertNil(result)
  }

  func test_continueSetupPresentationPublisher_publish_afterSkip() async throws {
    await features.use(autoFill)
    await features.use(linkOpener)

    let controller: ExtensionSetupController = try await testController()

    var result: Void!
    controller.continueSetupPresentationPublisher()
      .sink { result = $0 }
      .store(in: cancellables)

    controller.skipSetup()

    XCTAssertNotNil(result)
  }

  func test_continueSetupPresentationPublisher_publishes_afterEnablingExtensionInSettings() async throws {
    autoFill.extensionEnabledStatePublisher = always(Just(true).eraseToAnyPublisher())
    await features.use(autoFill)
    linkOpener.openSystemSettings = always(Just(true).eraseToAnyPublisher())
    await features.use(linkOpener)

    let controller: ExtensionSetupController = try await testController()

    var result: Void!
    controller.continueSetupPresentationPublisher()
      .sink { result = $0 }
      .store(in: cancellables)

    controller
      .setupExtension()
      .sink { _ in }
      .store(in: cancellables)

    XCTAssertNotNil(result)
  }

  func test_continueSetupPresentationPublisher_doesNotPublish_afterExtensionIsNotEnabledInSettings() async throws {
    autoFill.extensionEnabledStatePublisher = always(Just(false).eraseToAnyPublisher())
    await features.use(autoFill)
    linkOpener.openSystemSettings = always(Just(true).eraseToAnyPublisher())
    await features.use(linkOpener)

    let controller: ExtensionSetupController = try await testController()

    var result: Void!
    controller.continueSetupPresentationPublisher()
      .sink { result = $0 }
      .store(in: cancellables)

    controller
      .setupExtension()
      .sink { _ in }
      .store(in: cancellables)

    XCTAssertNil(result)
  }

  func test_setupExtension_opensSystemSettings() async throws {
    autoFill.extensionEnabledStatePublisher = always(Just(false).eraseToAnyPublisher())
    await features.use(autoFill)
    var result: Void!
    linkOpener.openSystemSettings = {
      result = Void()
      return Just(true).eraseToAnyPublisher()
    }
    await features.use(linkOpener)

    let controller: ExtensionSetupController = try await testController()

    controller
      .setupExtension()
      .sink { _ in }
      .store(in: cancellables)

    XCTAssertNotNil(result)
  }
}
