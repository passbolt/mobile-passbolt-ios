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
import FeatureScopes
import Features
import TestExtensions
import UIComponents

@testable import PassboltApp

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
@MainActor
final class ExtensionSetupScreenTests: MainActorTestCase {

  var extensions: OSExtensions!
  var linkOpener: OSLinkOpener!

  override func mainActorSetUp() {
    features
      .set(
        SessionScope.self,
        context: .init(
          account: .mock_ada,
          configuration: .mock_1
        )
      )
    features.usePlaceholder(for: OSExtensions.self)
    features.usePlaceholder(for: OSLinkOpener.self)
    features.patch(
      \Session.currentAccount,
      with: always(.mock_ada)
    )
    features.usePlaceholder(
      for: AccountInitialSetup.self,
      context: Account.mock_ada
    )
    features.usePlaceholder(for: ApplicationLifecycle.self)
  }

  override func mainActorTearDown() {
    extensions = nil
    linkOpener = nil
  }

  func test_continueSetupPresentationPublisher_doesNotPublishInitially() async throws {
    let controller: ExtensionSetupController = try await testController()

    var result: Void!
    controller.continueSetupPresentationPublisher()
      .sink { result = $0 }
      .store(in: cancellables)

    XCTAssertNil(result)
  }

  func test_continueSetupPresentationPublisher_publish_afterSkip() async throws {
    features.patch(
      \AccountInitialSetup.completeSetup,
      context: Account.mock_ada,
      with: always(Void())
    )

    let controller: ExtensionSetupController = try await testController()

    var result: Void!
    controller.continueSetupPresentationPublisher()
      .sink { result = $0 }
      .store(in: cancellables)

    controller.skipSetup()

    XCTAssertNotNil(result)
  }

  func test_continueSetupPresentationPublisher_publishes_afterEnablingExtensionInSettings() async throws {
    features
      .patch(
        \OSExtensions.autofillExtensionEnabled,
        with: always(true)
      )
    features
      .patch(
        \OSLinkOpener.openSystemSettings,
        with: { () async throws -> Void in }
      )
    features.patch(
      \ApplicationLifecycle.lifecyclePublisher,
      with: always(
        Just(.didBecomeActive)
          .eraseToAnyPublisher()
      )
    )

    let controller: ExtensionSetupController = try await testController()

    var result: Void?
    controller
      .continueSetupPresentationPublisher()
      .sink { result = $0 }
      .store(in: cancellables)

    controller
      .setupExtension()
      .sink { _ in }
      .store(in: cancellables)

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    XCTAssertNotNil(result)
  }

  func test_continueSetupPresentationPublisher_doesNotPublish_afterExtensionIsNotEnabledInSettings() async throws {
    features
      .patch(
        \OSExtensions.autofillExtensionEnabled,
        with: always(false)
      )
    features
      .patch(
        \OSLinkOpener.openSystemSettings,
        with: { () async throws -> Void in }
      )
    features.patch(
      \ApplicationLifecycle.lifecyclePublisher,
      with: always(
        Just(.didBecomeActive)
          .eraseToAnyPublisher()
      )
    )

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
    features
      .patch(
        \OSExtensions.autofillExtensionEnabled,
        with: always(false)
      )
    var result: Void!
    features
      .patch(
        \OSLinkOpener.openSystemSettings,
        with: { () async throws -> Void in
          result = Void()
        }
      )
    features.patch(
      \ApplicationLifecycle.lifecyclePublisher,
      with: always(
        Just(.didBecomeActive)
          .eraseToAnyPublisher()
      )
    )

    let controller: ExtensionSetupController = try await testController()

    controller
      .setupExtension()
      .sink { _ in }
      .store(in: cancellables)

    // temporary wait for detached tasks
    try await Task.sleep(nanoseconds: 300 * NSEC_PER_MSEC)

    XCTAssertNotNil(result)
  }
}
